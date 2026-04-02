// Parse LLVM IR (.ll) and write program structure to output.json (llvm::json).
// Per function: CFG (nodes/edges with instruction mix), natural loops
// (SCEV trip/IV, memory patterns, dependence analysis).

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/Analysis/AssumptionCache.h"
#include "llvm/Analysis/AliasAnalysis.h"
#include "llvm/Analysis/BasicAliasAnalysis.h"
#include "llvm/Analysis/DependenceAnalysis.h"
#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/Analysis/TargetLibraryInfo.h"
#include "llvm/IR/BasicBlock.h"
#include "llvm/IR/CFG.h"
#include "llvm/IR/Dominators.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Instruction.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Operator.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/JSON.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Host.h"
#include "llvm/TargetParser/Triple.h"

#include <cstring>
#include <string>

using namespace llvm;

static cl::opt<std::string> InputFilename(cl::Positional, cl::desc("<input.ll>"),
                                          cl::Required);

static cl::opt<std::string>
    OutputFilename("o", cl::desc("Output JSON file"), cl::init("output.json"),
                   cl::value_desc("path"));

static std::string basicBlockDisplayName(const BasicBlock &BB) {
  if (BB.hasName())
    return std::string(BB.getName());
  std::string S;
  raw_string_ostream ROS(S);
  BB.printAsOperand(ROS, false);
  return ROS.str();
}

static std::string valueDisplayName(const Value *V) {
  if (!V)
    return "(null)";
  if (V->hasName())
    return std::string(V->getName());
  std::string S;
  raw_string_ostream ROS(S);
  V->printAsOperand(ROS, false);
  return ROS.str();
}

static std::string scevToString(const SCEV *S) {
  if (!S || isa<SCEVCouldNotCompute>(S))
    return "unknown";
  std::string R;
  raw_string_ostream OS(R);
  S->print(OS);
  return OS.str();
}

/// Peel pointer casts and GEPs; indices outer-to-inner.
static void peelGEPChain(Value *Ptr, Value *&Base,
                         SmallVectorImpl<Value *> &Indices) {
  Indices.clear();
  Ptr = Ptr->stripPointerCasts();
  while (auto *GEP = dyn_cast<GEPOperator>(Ptr)) {
    SmallVector<Value *, 4> Level;
    for (Use &U : GEP->indices())
      Level.push_back(U.get());
    Indices.insert(Indices.begin(), Level.begin(), Level.end());
    Ptr = GEP->getPointerOperand()->stripPointerCasts();
  }
  Base = Ptr;
}

[[nodiscard]] static const char *classifyIndexForLoop(const SCEV *S,
                                                      const Loop *L,
                                                      ScalarEvolution &SE) {
  if (isa<SCEVCouldNotCompute>(S))
    return "Unknown";
  if (SE.isLoopInvariant(S, L))
    return "Invariant";
  const auto *AR = dyn_cast<SCEVAddRecExpr>(S);
  if (!AR || AR->getLoop() != L)
    return "Unknown";
  if (!AR->isAffine())
    return "Unknown";
  const SCEV *Step = AR->getOperand(1);
  if (const auto *SC = dyn_cast<SCEVConstant>(Step)) {
    if (SC->getAPInt().abs().isOne())
      return "Sequential (stride-1)";
    if (SC->getAPInt().isZero())
      return "Invariant";
    return "Strided";
  }
  return "Strided";
}

[[nodiscard]] static std::string patternToJsonString(const char *P) {
  if (!strcmp(P, "Sequential (stride-1)"))
    return "stride-1";
  if (!strcmp(P, "Strided"))
    return "strided";
  return "unknown";
}

/// Fast IR-level check: does the loop have a simple constant-bound comparison?
/// Avoids calling SCEV entirely to prevent hangs on complex trip count expressions.
static bool hasSimpleBound(Loop *L) {
  BasicBlock *Exiting = L->getExitingBlock();
  if (!Exiting) return false;
  auto *BI = dyn_cast<BranchInst>(Exiting->getTerminator());
  if (!BI || !BI->isConditional()) return false;
  auto *Cmp = dyn_cast<ICmpInst>(cast<CondBrInst>(BI)->getCondition());
  if (!Cmp) return false;
  return isa<ConstantInt>(Cmp->getOperand(0)) ||
         isa<ConstantInt>(Cmp->getOperand(1));
}

static std::string tripCountString(ScalarEvolution &SE, Loop *L) {
  unsigned TC = SE.getSmallConstantTripCount(L);
  if (TC > 0)
    return std::to_string(TC);
  unsigned MaxTC = SE.getSmallConstantMaxTripCount(L);
  if (MaxTC > 0)
    return "at most " + std::to_string(MaxTC);
  return "unknown";
}

static std::string inductionVariableString(ScalarEvolution &SE, Loop *L) {
  Value *IV = nullptr;
  for (PHINode &PN : L->getHeader()->phis()) {
    const SCEV *S = SE.getSCEV(&PN);
    const auto *AR = dyn_cast<SCEVAddRecExpr>(S);
    if (AR && AR->getLoop() == L && AR->isAffine()) {
      IV = &PN;
      break;
    }
  }
  if (!IV)
    return "";
  return valueDisplayName(IV);
}

static void appendMemoryAccessesJson(LoopInfo &LI, ScalarEvolution &SE, Loop *L,
                                     json::Array &Out) {
  for (BasicBlock *BB : L->blocks()) {
    for (Instruction &I : *BB) {
      if (LI.getLoopFor(I.getParent()) != L)
        continue;

      Value *PtrOp = nullptr;
      if (auto *Ld = dyn_cast<LoadInst>(&I))
        PtrOp = Ld->getPointerOperand();
      else if (auto *St = dyn_cast<StoreInst>(&I))
        PtrOp = St->getPointerOperand();
      else
        continue;

      Value *Base = nullptr;
      SmallVector<Value *, 8> GepIndices;
      peelGEPChain(PtrOp, Base, GepIndices);

      Value *VaryIdx = nullptr;
      for (int i = static_cast<int>(GepIndices.size()) - 1; i >= 0; --i) {
        const SCEV *IS = SE.getSCEV(GepIndices[i]);
        const auto *AR = dyn_cast<SCEVAddRecExpr>(IS);
        if (AR && AR->getLoop() == L) {
          VaryIdx = GepIndices[i];
          break;
        }
      }

      const char *Pattern = "Unknown";
      if (VaryIdx)
        Pattern = classifyIndexForLoop(SE.getSCEV(VaryIdx), L, SE);
      else if (!GepIndices.empty())
        Pattern = "Invariant";
      else {
        const SCEV *PS = SE.getSCEV(PtrOp->stripPointerCasts());
        if (!isa<SCEVCouldNotCompute>(PS) && SE.isLoopInvariant(PS, L))
          Pattern = "Invariant";
      }

      json::Object M;
      M.try_emplace("type", std::string(isa<LoadInst>(&I) ? "load" : "store"));
      M.try_emplace("array", valueDisplayName(Base));
      M.try_emplace("pattern", patternToJsonString(Pattern));
      Out.push_back(std::move(M));
    }
  }
}

static void appendDependenciesJson(Loop *L, LoopInfo &LI,
                                   DependenceInfo &DI,
                                   json::Array &Out) {
  SmallVector<Instruction *, 16> MemInsts;
  for (BasicBlock *BB : L->blocks()) {
    if (LI.getLoopFor(BB) != L)
      continue;
    for (Instruction &I : *BB)
      if (isa<LoadInst>(I) || isa<StoreInst>(I))
        MemInsts.push_back(&I);
  }

  if (MemInsts.size() > 64)
    return;

  DenseSet<std::pair<Instruction *, Instruction *>> Seen;
  for (unsigned i = 0, e = MemInsts.size(); i < e; ++i) {
    for (unsigned j = i; j < e; ++j) {
      Instruction *Src = MemInsts[i], *Dst = MemInsts[j];
      if (Seen.count({Src, Dst}))
        continue;
      auto Dep = DI.depends(Src, Dst, true);
      if (!Dep)
        continue;

      Seen.insert({Src, Dst});

      std::string Type;
      if (Dep->isFlow())
        Type = "flow";
      else if (Dep->isAnti())
        Type = "anti";
      else if (Dep->isOutput())
        Type = "output";
      else
        Type = "loop-carried";

      bool IsLoopCarried = false;
      unsigned Levels = Dep->getLevels();
      int64_t Distance = 0;
      for (unsigned Lev = 1; Lev <= Levels; ++Lev) {
        if (const SCEV *D = Dep->getDistance(Lev)) {
          if (const auto *SC = dyn_cast<SCEVConstant>(D)) {
            Distance = SC->getAPInt().getSExtValue();
            if (Distance != 0) IsLoopCarried = true;
          }
        }
        if (Dep->isScalar(Lev))
          IsLoopCarried = true;
      }
      if (IsLoopCarried)
        Type = "loop-carried";

      auto memOpName = [](Instruction *I) -> std::string {
        if (auto *Ld = dyn_cast<LoadInst>(I))
          return I->hasName() ? valueDisplayName(I)
                              : valueDisplayName(Ld->getPointerOperand());
        if (auto *St = dyn_cast<StoreInst>(I))
          return valueDisplayName(St->getPointerOperand());
        return valueDisplayName(I);
      };
      std::string FromVar = memOpName(Src);
      std::string ToVar = memOpName(Dst);
      std::string Desc;
      if (Type == "loop-carried")
        Desc = "Loop-carried dependence (distance " + std::to_string(Distance) + ")";
      else if (Type == "flow")
        Desc = "Read-after-write (flow) dependence";
      else if (Type == "anti")
        Desc = "Write-after-read (anti) dependence";
      else if (Type == "output")
        Desc = "Write-after-write (output) dependence";

      json::Object DepObj;
      DepObj.try_emplace("type", Type);
      DepObj.try_emplace("from_var", FromVar);
      DepObj.try_emplace("to_var", ToVar);
      DepObj.try_emplace("distance", Distance);
      DepObj.try_emplace("description", Desc);
      Out.push_back(std::move(DepObj));
    }
  }
}

/// Weighted cost for a basic block: memory ops × 10, arith × 1, branch × 2.
static int64_t blockCost(const BasicBlock &BB) {
  int64_t Cost = 0;
  for (const Instruction &I : BB) {
    if (isa<LoadInst>(I) || isa<StoreInst>(I) || isa<AtomicRMWInst>(I) ||
        isa<AtomicCmpXchgInst>(I))
      Cost += 10;
    else if (isa<GetElementPtrInst>(I) || isa<AllocaInst>(I))
      Cost += 2;
    else if (isa<BinaryOperator>(I) || isa<ICmpInst>(I) || isa<FCmpInst>(I) ||
             isa<UnaryOperator>(I) || isa<SelectInst>(I))
      Cost += 1;
    else if (I.isTerminator() || isa<InvokeInst>(I))
      Cost += 2;
    else
      Cost += 1;
  }
  return Cost;
}

/// Estimate trip count as a number (returns 0 if unknown).
/// Uses only lightweight queries to avoid expensive SCEV computations.
static int64_t numericTripCount(Loop *L) {
  if (!L->getLoopLatch() || !L->getExitingBlock())
    return 0;
  BasicBlock *Exiting = L->getExitingBlock();
  if (!Exiting)
    return 0;
  auto *BI = dyn_cast<BranchInst>(Exiting->getTerminator());
  if (!BI || !BI->isConditional())
    return 0;
  auto *Cmp = dyn_cast<ICmpInst>(cast<CondBrInst>(BI)->getCondition());
  if (!Cmp)
    return 0;
  for (unsigned I = 0; I < 2; ++I) {
    if (auto *CI = dyn_cast<ConstantInt>(Cmp->getOperand(I))) {
      int64_t V = CI->getSExtValue();
      if (V > 0 && V < 100000)
        return V;
    }
  }
  return 0;
}

/// Compute impact = blockCost × product of enclosing trip counts.
static int64_t computeImpact(const BasicBlock &BB, LoopInfo &LI) {
  int64_t Cost = blockCost(BB);
  int64_t TripProduct = 1;
  Loop *L = LI.getLoopFor(&BB);
  while (L) {
    int64_t TC = numericTripCount(L);
    if (TC > 0)
      TripProduct *= TC;
    else
      TripProduct *= 100;
    L = L->getParentLoop();
  }
  return Cost * TripProduct;
}

/// Find the critical path within a loop: longest-cost chain of basic blocks
/// following forward CFG edges. Returns ordered list of block labels.
static json::Array computeCriticalPath(Loop *L, LoopInfo &LI) {
  SmallVector<BasicBlock *, 16> Blocks(L->blocks().begin(), L->blocks().end());
  DenseMap<BasicBlock *, int64_t> LongestTo;
  DenseMap<BasicBlock *, BasicBlock *> PredOnPath;

  for (BasicBlock *BB : Blocks) {
    LongestTo[BB] = blockCost(*BB);
    PredOnPath[BB] = nullptr;
  }

  bool Changed = true;
  for (int Iter = 0; Iter < (int)Blocks.size() && Changed; ++Iter) {
    Changed = false;
    for (BasicBlock *BB : Blocks) {
      for (BasicBlock *Succ : successors(BB)) {
        if (!L->contains(Succ)) continue;
        if (LI.isLoopHeader(Succ)) continue;
        int64_t NewDist = LongestTo[BB] + blockCost(*Succ);
        if (NewDist > LongestTo[Succ]) {
          LongestTo[Succ] = NewDist;
          PredOnPath[Succ] = BB;
          Changed = true;
        }
      }
    }
  }

  BasicBlock *EndBlock = Blocks[0];
  for (BasicBlock *BB : Blocks)
    if (LongestTo[BB] > LongestTo[EndBlock])
      EndBlock = BB;

  SmallVector<std::string, 8> PathLabels;
  DenseSet<BasicBlock *> Visited;
  BasicBlock *Cur = EndBlock;
  while (Cur && !Visited.count(Cur)) {
    Visited.insert(Cur);
    PathLabels.push_back(basicBlockDisplayName(*Cur));
    Cur = PredOnPath[Cur];
  }
  std::reverse(PathLabels.begin(), PathLabels.end());

  json::Array Path;
  for (const auto &Lbl : PathLabels)
    Path.push_back(Lbl);
  return Path;
}

static void addLoopTreeToJson(Loop *L, LoopInfo &LI, ScalarEvolution &SE,
                              DependenceInfo &DI,
                              Function &F, unsigned &Seq, json::Array &Loops) {
  std::string Id = (Twine(F.getName()) + "::" +
                    basicBlockDisplayName(*L->getHeader()) + "::" + Twine(Seq++))
                       .str();

  json::Array Blocks;
  for (BasicBlock *BB : L->getBlocks())
    Blocks.push_back(basicBlockDisplayName(*BB));

  bool simpleBound = hasSimpleBound(L);

  json::Array Mem;
  if (simpleBound)
    appendMemoryAccessesJson(LI, SE, L, Mem);

  json::Array Deps;
  if (simpleBound)
    appendDependenciesJson(L, LI, DI, Deps);

  json::Object LObj;
  LObj.try_emplace("id", std::move(Id));
  LObj.try_emplace("header", basicBlockDisplayName(*L->getHeader()));
  LObj.try_emplace("depth", static_cast<int64_t>(L->getLoopDepth()));
  LObj.try_emplace("trip_count", simpleBound ? tripCountString(SE, L) : "unknown");
  LObj.try_emplace("induction_variable", simpleBound ? inductionVariableString(SE, L) : "");
  LObj.try_emplace("blocks", std::move(Blocks));
  LObj.try_emplace("memory_accesses", std::move(Mem));
  LObj.try_emplace("dependencies", std::move(Deps));
  LObj.try_emplace("critical_path", computeCriticalPath(L, LI));
  Loops.push_back(std::move(LObj));

  for (Loop *Sub : L->getSubLoops())
    addLoopTreeToJson(Sub, LI, SE, DI, F, Seq, Loops);
}

static json::Object classifyInstructions(const BasicBlock &BB) {
  int64_t Total = 0, Arith = 0, Mem = 0, Branch = 0, Other = 0;
  for (const Instruction &I : BB) {
    ++Total;
    if (isa<BinaryOperator>(I) || isa<ICmpInst>(I) || isa<FCmpInst>(I) ||
        isa<UnaryOperator>(I) || isa<SelectInst>(I))
      ++Arith;
    else if (isa<LoadInst>(I) || isa<StoreInst>(I) || isa<AllocaInst>(I) ||
             isa<GetElementPtrInst>(I) || isa<AtomicRMWInst>(I) ||
             isa<AtomicCmpXchgInst>(I))
      ++Mem;
    else if (I.isTerminator() || isa<InvokeInst>(I))
      ++Branch;
    else
      ++Other;
  }
  json::Object Obj;
  Obj.try_emplace("total", Total);
  Obj.try_emplace("arith", Arith);
  Obj.try_emplace("memory", Mem);
  Obj.try_emplace("branch", Branch);
  Obj.try_emplace("other", Other);
  return Obj;
}

static json::Object functionCfgJson(Function &F, LoopInfo &LI) {
  DenseMap<const BasicBlock *, std::string> BId;
  unsigned N = 0;
  for (BasicBlock &BB : F)
    BId[&BB] = ("b" + Twine(N++)).str();

  json::Array Nodes;
  for (BasicBlock &BB : F) {
    json::Object Node;
    Node.try_emplace("id", BId[&BB]);
    Node.try_emplace("label", basicBlockDisplayName(BB));
    Node.try_emplace("instructions", classifyInstructions(BB));
    Node.try_emplace("cost", blockCost(BB));
    Node.try_emplace("impact", computeImpact(BB, LI));
    Nodes.push_back(std::move(Node));
  }

  json::Array Edges;
  for (BasicBlock &BB : F) {
    for (succ_iterator SI = succ_begin(&BB), E = succ_end(&BB); SI != E; ++SI) {
      json::Object Edge;
      Edge.try_emplace("from", BId[&BB]);
      Edge.try_emplace("to", BId[*SI]);
      Edges.push_back(std::move(Edge));
    }
  }

  json::Object Cfg;
  Cfg.try_emplace("nodes", std::move(Nodes));
  Cfg.try_emplace("edges", std::move(Edges));
  return Cfg;
}

static uint64_t countInstructions(const Function &F) {
  uint64_t N = 0;
  for (const BasicBlock &BB : F)
    N += BB.size();
  return N;
}

static json::Object functionToJson(Function &F, LoopInfo &LI,
                                   ScalarEvolution &SE,
                                   DependenceInfo &DI) {
  json::Array Loops;
  unsigned Seq = 0;
  for (Loop *R : LI)
    addLoopTreeToJson(R, LI, SE, DI, F, Seq, Loops);

  json::Object Fo;
  Fo.try_emplace("name", std::string(F.getName()));
  Fo.try_emplace("loops", std::move(Loops));
  Fo.try_emplace("cfg", functionCfgJson(F, LI));
  Fo.try_emplace("instruction_count", static_cast<int64_t>(countInstructions(F)));
  return Fo;
}

static json::Object emptyFunctionJson(Function &F) {
  json::Object Fo;
  Fo.try_emplace("name", std::string(F.getName()));
  Fo.try_emplace("loops", json::Array{});
  json::Object Cfg;
  Cfg.try_emplace("nodes", json::Array{});
  Cfg.try_emplace("edges", json::Array{});
  Fo.try_emplace("cfg", std::move(Cfg));
  Fo.try_emplace("instruction_count", static_cast<int64_t>(0));
  return Fo;
}

int main(int argc, char **argv) {
  cl::ParseCommandLineOptions(argc, argv, "LLVM IR → JSON structure dump\n");

  LLVMContext Context;
  SMDiagnostic Err;
  std::unique_ptr<Module> Mod = parseIRFile(InputFilename, Err, Context);
  if (!Mod) {
    Err.print(argv[0], errs());
    return 1;
  }

  json::Array Functions;
  for (Function &F : *Mod) {
    if (F.isDeclaration()) {
      Functions.push_back(emptyFunctionJson(F));
      continue;
    }

    DominatorTree DT(F);
    LoopInfo LI(DT);

    const Triple &ModTriple = F.getParent()->getTargetTriple();
    Triple TT = ModTriple.getTriple().empty()
                    ? Triple(llvm::sys::getDefaultTargetTriple())
                    : ModTriple;
    TargetLibraryInfoImpl TLII(TT);
    TargetLibraryInfo TLI(TLII);
    AssumptionCache AC(F);
    ScalarEvolution SE(F, TLI, AC, DT, LI);
    AAResults AA(TLI);
    DependenceInfo DI(&F, &AA, &SE, &LI);

    Functions.push_back(functionToJson(F, LI, SE, DI));
  }

  json::Object Root;
  Root.try_emplace("functions", std::move(Functions));
  json::Value Doc(std::move(Root));

  std::error_code EC;
  raw_fd_ostream Out(OutputFilename, EC, sys::fs::OF_Text);
  if (EC) {
    errs() << "Error opening " << OutputFilename << ": " << EC.message() << "\n";
    return 1;
  }
  Out << formatv("{0:2}", Doc) << "\n";
  Out.flush();

  outs() << "Wrote " << OutputFilename << "\n";
  return 0;
}
