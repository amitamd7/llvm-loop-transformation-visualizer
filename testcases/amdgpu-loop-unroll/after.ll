; ModuleID = '/work/amtiwari/llvm-loop-transform-visualiser/testcases/amdgpu-loop-unroll/before.ll'
source_filename = "/work/amtiwari/llvm-loop-transform-visualiser/testcases/amdgpu-loop-unroll/kernel.c"
target datalayout = "e-m:e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9"
target triple = "amdgcn-amd-amdhsa"

; Function Attrs: nofree norecurse nosync nounwind memory(argmem: readwrite)
define protected amdgpu_kernel void @kernel(ptr noundef captures(none) %0, i32 noundef %1) local_unnamed_addr #0 {
  %3 = addrspacecast ptr %0 to ptr addrspace(1)
  %4 = icmp sgt i32 %1, 0
  br i1 %4, label %.preheader, label %5

.preheader:                                       ; preds = %2
  br label %6

.loopexit:                                        ; preds = %6
  br label %5

5:                                                ; preds = %.loopexit, %2
  ret void

6:                                                ; preds = %.preheader, %6
  %7 = phi i32 [ %12, %6 ], [ 0, %.preheader ]
  %8 = zext nneg i32 %7 to i64
  %9 = getelementptr inbounds nuw [4 x i8], ptr addrspace(1) %3, i64 %8
  %10 = load float, ptr addrspace(1) %9, align 4, !tbaa !7
  %11 = fmul float %10, 2.000000e+00
  store float %11, ptr addrspace(1) %9, align 4, !tbaa !7
  %12 = add nuw nsw i32 %7, 1
  %13 = icmp eq i32 %12, %1
  br i1 %13, label %.loopexit, label %6, !llvm.loop !9
}

attributes #0 = { nofree norecurse nosync nounwind memory(argmem: readwrite) "amdgpu-agpr-alloc"="0" "amdgpu-no-cluster-id-x" "amdgpu-no-cluster-id-y" "amdgpu-no-cluster-id-z" "amdgpu-no-completion-action" "amdgpu-no-default-queue" "amdgpu-no-dispatch-id" "amdgpu-no-dispatch-ptr" "amdgpu-no-flat-scratch-init" "amdgpu-no-heap-ptr" "amdgpu-no-hostcall-ptr" "amdgpu-no-implicitarg-ptr" "amdgpu-no-lds-kernel-id" "amdgpu-no-multigrid-sync-arg" "amdgpu-no-queue-ptr" "amdgpu-no-workgroup-id-x" "amdgpu-no-workgroup-id-y" "amdgpu-no-workgroup-id-z" "amdgpu-no-workitem-id-x" "amdgpu-no-workitem-id-y" "amdgpu-no-workitem-id-z" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" }

!llvm.module.flags = !{!0, !1}
!llvm.ident = !{!2}
!llvm.errno.tbaa = !{!3}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 22b330eb09b9e4ab3d64a1f6ad0fe42e23569d77)"}
!3 = !{!4, !4, i64 0}
!4 = !{!"int", !5, i64 0}
!5 = !{!"omnipotent char", !6, i64 0}
!6 = !{!"Simple C/C++ TBAA"}
!7 = !{!8, !8, i64 0}
!8 = !{!"float", !5, i64 0}
!9 = distinct !{!9, !10, !11}
!10 = !{!"llvm.loop.mustprogress"}
!11 = !{!"llvm.loop.unroll.disable"}
