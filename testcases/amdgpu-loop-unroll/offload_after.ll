; ModuleID = '/tmp/bench_offload-80cabd.bc'
source_filename = "/work/amtiwari/llvm-loop-transform-visualiser/testcases/amdgpu-loop-unroll/bench_offload.c"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"

%struct.ident_t = type { i32, i32, i32, i32, ptr }
%struct.__tgt_offload_entry = type { i64, i16, i16, i32, ptr, ptr, i64, i64, ptr }
%struct.__tgt_kernel_arguments = type { i32, i32, ptr, ptr, ptr, ptr, ptr, ptr, i64, i64, [3 x i32], [3 x i32], i32 }

@0 = private unnamed_addr constant [23 x i8] c";unknown;unknown;0;0;;\00", align 1
@1 = private unnamed_addr constant %struct.ident_t { i32 0, i32 2050, i32 0, i32 22, ptr @0 }, align 8
@2 = private unnamed_addr constant %struct.ident_t { i32 0, i32 514, i32 0, i32 22, ptr @0 }, align 8
@3 = private unnamed_addr constant %struct.ident_t { i32 0, i32 2, i32 0, i32 22, ptr @0 }, align 8
@.__omp_offloading_811_507524_main_l15.region_id = weak constant i8 0
@.offload_sizes = private unnamed_addr constant [3 x i64] [i64 4, i64 0, i64 0]
@.offload_maptypes = private unnamed_addr constant [3 x i64] [i64 800, i64 544, i64 288]
@.offloading.entry_name = internal unnamed_addr constant [37 x i8] c"__omp_offloading_811_507524_main_l15\00", section ".llvm.rodata.offloading", align 1
@.offloading.entry.__omp_offloading_811_507524_main_l15 = weak local_unnamed_addr constant %struct.__tgt_offload_entry { i64 0, i16 1, i16 1, i32 0, ptr @.__omp_offloading_811_507524_main_l15.region_id, ptr @.offloading.entry_name, i64 0, i64 0, ptr null }, section "llvm_offload_entries", align 8
@llvm.embedded.object = private constant [14376 x i8] c"\10\FF\10\AD\02\00\00\00(8\00\00\00\00\00\00 \00\00\00\00\00\00\00\01\00\00\00\00\00\00\00\02\00\01\00\00\00\00\00H\00\00\00\00\00\00\00\02\00\00\00\00\00\00\00\A0\00\00\00\00\00\00\00\887\00\00\00\00\00\00y\00\00\00\00\00\00\00\97\00\00\00\00\00\00\00\06\00\00\00\00\00\00\00~\00\00\00\00\00\00\00\85\00\00\00\00\00\00\00\11\00\00\00\00\00\00\00\00arch\00triple\00amdgcn-amd-amdhsa\00gfx90a\00\00\00; ModuleID = '/work/amtiwari/llvm-loop-transform-visualiser/testcases/amdgpu-loop-unroll/bench_offload.c'\0Asource_filename = \22/work/amtiwari/llvm-loop-transform-visualiser/testcases/amdgpu-loop-unroll/bench_offload.c\22\0Atarget datalayout = \22e-m:e-p:64:64-p1:64:64-p2:32:32-p3:32:32-p4:64:64-p5:32:32-p6:32:32-p7:160:256:256:32-p8:128:128:128:48-p9:192:256:256:32-i64:64-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024-v2048:2048-n32:64-S32-A5-G1-ni:7:8:9\22\0Atarget triple = \22amdgcn-amd-amdhsa\22\0A\0A%struct.ident_t = type { i32, i32, i32, i32, ptr }\0A%struct.DynamicEnvironmentTy = type { i16 }\0A%struct.KernelEnvironmentTy = type { %struct.ConfigurationEnvironmentTy, ptr, ptr }\0A%struct.ConfigurationEnvironmentTy = type { i8, i8, i8, i32, i32, i32, i32, i32, i32 }\0A\0A@__omp_rtl_debug_kind = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0\0A@__omp_rtl_assume_teams_oversubscription = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0\0A@__omp_rtl_assume_threads_oversubscription = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0\0A@__omp_rtl_assume_no_thread_state = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0\0A@__omp_rtl_assume_no_nested_parallelism = weak_odr hidden local_unnamed_addr addrspace(1) constant i32 0\0A@0 = private unnamed_addr addrspace(1) constant [23 x i8] c\22;unknown;unknown;0;0;;\\00\22, align 1\0A@1 = private unnamed_addr addrspace(1) constant %struct.ident_t { i32 0, i32 2, i32 0, i32 22, ptr addrspacecast (ptr addrspace(1) @0 to ptr) }, align 8\0A@__omp_offloading_811_507524_main_l15_dynamic_environment = weak_odr protected addrspace(1) global %struct.DynamicEnvironmentTy zeroinitializer\0A@__omp_offloading_811_507524_main_l15_kernel_environment = weak_odr protected addrspace(1) constant %struct.KernelEnvironmentTy { %struct.ConfigurationEnvironmentTy { i8 0, i8 0, i8 2, i32 1, i32 256, i32 0, i32 0, i32 0, i32 0 }, ptr addrspacecast (ptr addrspace(1) @1 to ptr), ptr addrspacecast (ptr addrspace(1) @__omp_offloading_811_507524_main_l15_dynamic_environment to ptr) }\0A@2 = private unnamed_addr addrspace(1) constant %struct.ident_t { i32 0, i32 2050, i32 0, i32 22, ptr addrspacecast (ptr addrspace(1) @0 to ptr) }, align 8\0A@3 = private unnamed_addr addrspace(1) constant %struct.ident_t { i32 0, i32 514, i32 0, i32 22, ptr addrspacecast (ptr addrspace(1) @0 to ptr) }, align 8\0A\0A; Function Attrs: alwaysinline norecurse nounwind\0Adefine weak_odr protected amdgpu_kernel void @__omp_offloading_811_507524_main_l15(i64 noundef %0, ptr noundef %1, ptr noalias noundef %2) local_unnamed_addr #0 {\0A  %4 = alloca i32, align 4, addrspace(5)\0A  %5 = alloca i32, align 4, addrspace(5)\0A  %6 = alloca i32, align 4, addrspace(5)\0A  %7 = alloca i32, align 4, addrspace(5)\0A  %8 = alloca [4 x ptr], align 8, addrspace(5)\0A  %9 = tail call i32 @__kmpc_target_init(ptr addrspacecast (ptr addrspace(1) @__omp_offloading_811_507524_main_l15_kernel_environment to ptr), ptr %2) #2\0A  %10 = icmp eq i32 %9, -1\0A  br i1 %10, label %12, label %11\0A\0A11:                                               ; preds = %3, %43\0A  ret void\0A\0A12:                                               ; preds = %3\0A  %13 = tail call i32 @__kmpc_global_thread_num(ptr addrspacecast (ptr addrspace(1) @1 to ptr)) #2\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %8)\0A  %14 = addrspacecast ptr addrspace(5) %4 to ptr\0A  %15 = addrspacecast ptr addrspace(5) %5 to ptr\0A  %16 = addrspacecast ptr addrspace(5) %6 to ptr\0A  %17 = addrspacecast ptr addrspace(5) %7 to ptr\0A  %18 = addrspacecast ptr addrspace(5) %8 to ptr\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %4) #6, !noalias !13\0A  store i32 0, ptr addrspace(5) %4, align 4, !tbaa !8, !noalias !13\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %5) #6, !noalias !13\0A  store i32 1048575, ptr addrspace(5) %5, align 4, !tbaa !8, !noalias !13\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %6) #6, !noalias !13\0A  store i32 1, ptr addrspace(5) %6, align 4, !tbaa !8, !noalias !13\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %7) #6, !noalias !13\0A  store i32 0, ptr addrspace(5) %7, align 4, !tbaa !8, !noalias !13\0A  call void @__kmpc_distribute_static_init_4(ptr addrspacecast (ptr addrspace(1) @2 to ptr), i32 %13, i32 91, ptr %17, ptr %14, ptr %15, ptr %16, i32 1, i32 256) #2, !noalias !13\0A  %19 = load i32, ptr addrspace(5) %5, align 4, !tbaa !8, !noalias !13\0A  %20 = call i32 @llvm.smin.i32(i32 %19, i32 1048575)\0A  store i32 %20, ptr addrspace(5) %5, align 4, !tbaa !8, !noalias !13\0A  %21 = load i32, ptr addrspace(5) %4, align 4, !tbaa !8, !noalias !13\0A  %22 = icmp slt i32 %21, 1048576\0A  br i1 %22, label %23, label %43\0A\0A23:                                               ; preds = %12\0A  %24 = and i64 %0, 4294967295\0A  %25 = getelementptr inbounds nuw i8, ptr addrspace(5) %8, i32 8\0A  %26 = getelementptr inbounds nuw i8, ptr addrspace(5) %8, i32 16\0A  %27 = inttoptr i64 %24 to ptr\0A  %28 = getelementptr inbounds nuw i8, ptr addrspace(5) %8, i32 24\0A  br label %29\0A\0A29:                                               ; preds = %23, %29\0A  %30 = phi i32 [ %21, %23 ], [ %38, %29 ]\0A  %31 = phi i32 [ %20, %23 ], [ %41, %29 ]\0A  %32 = zext i32 %30 to i64\0A  %33 = zext i32 %31 to i64\0A  %34 = inttoptr i64 %32 to ptr\0A  store ptr %34, ptr addrspace(5) %8, align 8, !tbaa !16, !noalias !13, !llvm.access.group !19\0A  %35 = inttoptr i64 %33 to ptr\0A  store ptr %35, ptr addrspace(5) %25, align 8, !tbaa !16, !noalias !13, !llvm.access.group !19\0A  store ptr %27, ptr addrspace(5) %26, align 8, !tbaa !16, !noalias !13, !llvm.access.group !19\0A  store ptr %1, ptr addrspace(5) %28, align 8, !tbaa !16, !noalias !13, !llvm.access.group !19\0A  call void @__kmpc_parallel_60(ptr addrspacecast (ptr addrspace(1) @1 to ptr), i32 %13, i32 1, i32 -1, i32 -1, ptr nonnull @__omp_offloading_811_507524_main_l15_omp_outlined_omp_outlined, ptr null, ptr %18, i64 4, i32 0) #2, !noalias !13, !llvm.access.group !19\0A  %36 = load i32, ptr addrspace(5) %6, align 4, !tbaa !8, !noalias !13, !llvm.access.group !19\0A  %37 = load i32, ptr addrspace(5) %4, align 4, !tbaa !8, !noalias !13, !llvm.access.group !19\0A  %38 = add nsw i32 %37, %36\0A  store i32 %38, ptr addrspace(5) %4, align 4, !tbaa !8, !noalias !13, !llvm.access.group !19\0A  %39 = load i32, ptr addrspace(5) %5, align 4, !tbaa !8, !noalias !13, !llvm.access.group !19\0A  %40 = add nsw i32 %39, %36\0A  %41 = call i32 @llvm.smin.i32(i32 %40, i32 1048575)\0A  store i32 %41, ptr addrspace(5) %5, align 4, !tbaa !8, !noalias !13\0A  %42 = icmp slt i32 %38, 1048576\0A  br i1 %42, label %29, label %43, !llvm.loop !20\0A\0A43:                                               ; preds = %29, %12\0A  call void @__kmpc_distribute_static_fini(ptr addrspacecast (ptr addrspace(1) @2 to ptr), i32 %13) #2, !noalias !13\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %7) #2, !noalias !13\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %6) #2, !noalias !13\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %5) #2, !noalias !13\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %4) #2, !noalias !13\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %8)\0A  call void @__kmpc_target_deinit() #2\0A  br label %11\0A\0A; uselistorder directives\0A  uselistorder ptr addrspace(5) %4, { 3, 1, 2, 0, 4, 5, 6 }\0A  uselistorder ptr addrspace(5) %5, { 2, 3, 1, 0, 4, 5, 6, 7 }\0A  uselistorder ptr addrspace(5) %6, { 1, 0, 2, 3, 4 }\0A  uselistorder ptr addrspace(5) %8, { 3, 5, 2, 1, 0, 6, 4 }\0A  uselistorder label %11, { 1, 0 }\0A  uselistorder i32 %13, { 1, 2, 0 }\0A  uselistorder label %29, { 1, 0 }\0A  uselistorder i32 %38, { 0, 2, 1 }\0A}\0A\0Adeclare i32 @__kmpc_target_init(ptr, ptr) local_unnamed_addr\0A\0A; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)\0Adeclare void @llvm.lifetime.start.p5(ptr addrspace(5) captures(none)) #1\0A\0A; Function Attrs: nounwind\0Adeclare void @__kmpc_distribute_static_init_4(ptr, i32, i32, ptr, ptr, ptr, ptr, i32, i32) local_unnamed_addr #2\0A\0A; Function Attrs: alwaysinline norecurse nounwind\0Adefine internal void @__omp_offloading_811_507524_main_l15_omp_outlined_omp_outlined(ptr noalias noundef readonly captures(none) %0, ptr noalias readnone captures(none) %1, i64 noundef %2, i64 noundef %3, i64 %4, ptr noundef captures(none) %5) #3 {\0A  %7 = alloca i32, align 4, addrspace(5)\0A  %8 = alloca i32, align 4, addrspace(5)\0A  %9 = alloca i32, align 4, addrspace(5)\0A  %10 = alloca i32, align 4, addrspace(5)\0A  %11 = addrspacecast ptr addrspace(5) %7 to ptr\0A  %12 = addrspacecast ptr addrspace(5) %8 to ptr\0A  %13 = addrspacecast ptr addrspace(5) %9 to ptr\0A  %14 = addrspacecast ptr addrspace(5) %10 to ptr\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %7) #2\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %8) #2\0A  %15 = trunc i64 %2 to i32\0A  %16 = trunc i64 %3 to i32\0A  store i32 %15, ptr addrspace(5) %7, align 4, !tbaa !8\0A  store i32 %16, ptr addrspace(5) %8, align 4, !tbaa !8\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %9) #2\0A  store i32 1, ptr addrspace(5) %9, align 4, !tbaa !8\0A  call void @llvm.lifetime.start.p5(ptr addrspace(5) %10) #2\0A  store i32 0, ptr addrspace(5) %10, align 4, !tbaa !8\0A  %17 = load i32, ptr %0, align 4, !tbaa !8\0A  call void @__kmpc_for_static_init_4(ptr addrspacecast (ptr addrspace(1) @3 to ptr), i32 %17, i32 33, ptr %14, ptr %11, ptr %12, ptr %13, i32 1, i32 1) #2\0A  %18 = load i32, ptr addrspace(5) %7, align 4, !tbaa !8\0A  %19 = sext i32 %18 to i64\0A  %20 = icmp ult i64 %3, %19\0A  br i1 %20, label %32, label %21\0A\0A21:                                               ; preds = %6\0A  %22 = load i32, ptr addrspace(5) %9, align 4, !tbaa !8, !llvm.access.group !23\0A  br label %23\0A\0A23:                                               ; preds = %21, %23\0A  %24 = phi i64 [ %19, %21 ], [ %30, %23 ]\0A  %25 = trunc nsw i64 %24 to i32\0A  %26 = getelementptr inbounds [4 x i8], ptr %5, i64 %24\0A  %27 = load float, ptr %26, align 4, !tbaa !24, !llvm.access.group !23\0A  %28 = fmul float %27, 2.000000e+00\0A  store float %28, ptr %26, align 4, !tbaa !24, !llvm.access.group !23\0A  %29 = add nsw i32 %22, %25\0A  %30 = sext i32 %29 to i64\0A  %31 = icmp ult i64 %3, %30\0A  br i1 %31, label %32, label %23, !llvm.loop !26\0A\0A32:                                               ; preds = %23, %6\0A  call void @__kmpc_for_static_fini(ptr addrspacecast (ptr addrspace(1) @3 to ptr), i32 %17) #2\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %10) #2\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %9) #2\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %8) #2\0A  call void @llvm.lifetime.end.p5(ptr addrspace(5) %7) #2\0A  ret void\0A\0A; uselistorder directives\0A  uselistorder ptr addrspace(5) %7, { 2, 0, 1, 3, 4 }\0A  uselistorder ptr addrspace(5) %8, { 1, 0, 2, 3 }\0A  uselistorder ptr addrspace(5) %9, { 2, 0, 1, 3, 4 }\0A  uselistorder ptr addrspace(5) %10, { 1, 0, 2, 3 }\0A  uselistorder label %23, { 1, 0 }\0A  uselistorder i64 %24, { 1, 0 }\0A  uselistorder i64 %30, { 1, 0 }\0A}\0A\0A; Function Attrs: nounwind\0Adeclare void @__kmpc_for_static_init_4(ptr, i32, i32, ptr, ptr, ptr, ptr, i32, i32) local_unnamed_addr #2\0A\0A; Function Attrs: nounwind\0Adeclare void @__kmpc_for_static_fini(ptr, i32) local_unnamed_addr #2\0A\0A; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)\0Adeclare void @llvm.lifetime.end.p5(ptr addrspace(5) captures(none)) #1\0A\0A; Function Attrs: alwaysinline\0Adeclare void @__kmpc_parallel_60(ptr, i32, i32, i32, i32, ptr, ptr, ptr, i64, i32) local_unnamed_addr #4\0A\0A; Function Attrs: nounwind\0Adeclare void @__kmpc_distribute_static_fini(ptr, i32) local_unnamed_addr #2\0A\0A; Function Attrs: nounwind\0Adeclare i32 @__kmpc_global_thread_num(ptr) local_unnamed_addr #2\0A\0Adeclare void @__kmpc_target_deinit() local_unnamed_addr\0A\0A; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)\0Adeclare i32 @llvm.smin.i32(i32, i32) #5\0A\0A; uselistorder directives\0Auselistorder ptr addrspacecast (ptr addrspace(1) @1 to ptr), { 0, 2, 1 }\0Auselistorder ptr @llvm.lifetime.start.p5, { 5, 6, 7, 8, 0, 4, 3, 2, 1 }\0Auselistorder ptr @llvm.lifetime.end.p5, { 4, 3, 2, 1, 0, 8, 7, 6, 5 }\0Auselistorder ptr @llvm.smin.i32, { 1, 0 }\0A\0Aattributes #0 = { alwaysinline norecurse nounwind \22amdgpu-flat-work-group-size\22=\221,256\22 \22kernel\22 \22no-trapping-math\22=\22true\22 \22omp_target_thread_limit\22=\22256\22 \22stack-protector-buffer-size\22=\228\22 \22target-cpu\22=\22gfx90a\22 \22uniform-work-group-size\22 }\0Aattributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }\0Aattributes #2 = { nounwind }\0Aattributes #3 = { alwaysinline norecurse nounwind \22no-trapping-math\22=\22true\22 \22stack-protector-buffer-size\22=\228\22 \22target-cpu\22=\22gfx90a\22 }\0Aattributes #4 = { alwaysinline }\0Aattributes #5 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }\0Aattributes #6 = { nounwind memory(readwrite) }\0A\0A!omp_offload.info = !{!0}\0A!llvm.module.flags = !{!1, !2, !3, !4, !5}\0A!llvm.ident = !{!6, !7}\0A!llvm.errno.tbaa = !{!8}\0A!opencl.ocl.version = !{!12}\0A\0A!0 = !{i32 0, i32 2065, i32 5272868, !\22main\22, i32 15, i32 0, i32 0}\0A!1 = !{i32 1, !\22amdhsa_code_object_version\22, i32 600}\0A!2 = !{i32 7, !\22openmp\22, i32 51}\0A!3 = !{i32 7, !\22openmp-device\22, i32 51}\0A!4 = !{i32 8, !\22PIC Level\22, i32 2}\0A!5 = !{i32 1, !\22wchar_size\22, i32 4}\0A!6 = !{!\22clang version 23.0.0git (https://github.com/llvm/llvm-project.git 22b330eb09b9e4ab3d64a1f6ad0fe42e23569d77)\22}\0A!7 = !{!\22AMD clang version 18.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-6.3.1 24491 1e0fda770a2079fbd71e4b70974d74f62fd3af10)\22}\0A!8 = !{!9, !9, i64 0}\0A!9 = !{!\22int\22, !10, i64 0}\0A!10 = !{!\22omnipotent char\22, !11, i64 0}\0A!11 = !{!\22Simple C/C++ TBAA\22}\0A!12 = !{i32 2, i32 0}\0A!13 = !{!14}\0A!14 = distinct !{!14, !15, !\22__omp_offloading_811_507524_main_l15_omp_outlined: argument 0\22}\0A!15 = distinct !{!15, !\22__omp_offloading_811_507524_main_l15_omp_outlined\22}\0A!16 = !{!17, !17, i64 0}\0A!17 = !{!\22any p2 pointer\22, !18, i64 0}\0A!18 = !{!\22any pointer\22, !10, i64 0}\0A!19 = distinct !{}\0A!20 = distinct !{!20, !21, !22}\0A!21 = !{!\22llvm.loop.parallel_accesses\22, !19}\0A!22 = !{!\22llvm.loop.vectorize.enable\22, i1 true}\0A!23 = distinct !{}\0A!24 = !{!25, !25, i64 0}\0A!25 = !{!\22float\22, !10, i64 0}\0A!26 = distinct !{!26, !27, !22}\0A!27 = !{!\22llvm.loop.parallel_accesses\22, !23}\0A", section ".llvm.offloading", align 8, !exclude !0
@llvm.compiler.used = appending global [1 x ptr] [ptr @llvm.embedded.object], section "llvm.metadata"

; Function Attrs: nounwind uwtable
define dso_local range(i32 0, 2) i32 @main() local_unnamed_addr #0 {
  %1 = alloca [3 x ptr], align 8
  %2 = alloca [3 x ptr], align 8
  %3 = alloca %struct.__tgt_kernel_arguments, align 8
  %4 = tail call noalias dereferenceable_or_null(4194304) ptr @malloc(i64 noundef 4194304) #8
  %.not = icmp eq ptr %4, null
  br i1 %.not, label %33, label %vector.body

vector.body:                                      ; preds = %0, %vector.body
  %index = phi i64 [ %index.next.1, %vector.body ], [ 0, %0 ]
  %vec.ind = phi <4 x i32> [ %vec.ind.next.1, %vector.body ], [ <i32 0, i32 1, i32 2, i32 3>, %0 ]
  %step.add = add <4 x i32> %vec.ind, splat (i32 4)
  %5 = uitofp nneg <4 x i32> %vec.ind to <4 x float>
  %6 = uitofp nneg <4 x i32> %step.add to <4 x float>
  %7 = getelementptr inbounds nuw [4 x i8], ptr %4, i64 %index
  %8 = getelementptr inbounds nuw i8, ptr %7, i64 16
  store <4 x float> %5, ptr %7, align 4, !tbaa !13
  store <4 x float> %6, ptr %8, align 4, !tbaa !13
  %vec.ind.next = add <4 x i32> %vec.ind, splat (i32 8)
  %step.add.1 = add <4 x i32> %vec.ind, splat (i32 12)
  %9 = uitofp nneg <4 x i32> %vec.ind.next to <4 x float>
  %10 = uitofp nneg <4 x i32> %step.add.1 to <4 x float>
  %11 = getelementptr inbounds nuw [4 x i8], ptr %4, i64 %index
  %12 = getelementptr inbounds nuw i8, ptr %11, i64 32
  %13 = getelementptr inbounds nuw i8, ptr %11, i64 48
  store <4 x float> %9, ptr %12, align 4, !tbaa !13
  store <4 x float> %10, ptr %13, align 4, !tbaa !13
  %index.next.1 = add nuw nsw i64 %index, 16
  %vec.ind.next.1 = add <4 x i32> %vec.ind, splat (i32 16)
  %14 = icmp eq i64 %index.next.1, 1048576
  br i1 %14, label %.preheader, label %vector.body, !llvm.loop !15

.preheader:                                       ; preds = %vector.body
  %15 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %16 = getelementptr inbounds nuw i8, ptr %2, i64 8
  %17 = getelementptr inbounds nuw i8, ptr %1, i64 16
  %18 = getelementptr inbounds nuw i8, ptr %2, i64 16
  %19 = getelementptr inbounds nuw i8, ptr %3, i64 4
  %20 = getelementptr inbounds nuw i8, ptr %3, i64 8
  %21 = getelementptr inbounds nuw i8, ptr %3, i64 16
  %22 = getelementptr inbounds nuw i8, ptr %3, i64 24
  %23 = getelementptr inbounds nuw i8, ptr %3, i64 32
  %24 = getelementptr inbounds nuw i8, ptr %3, i64 40
  %25 = getelementptr inbounds nuw i8, ptr %3, i64 56
  %26 = getelementptr inbounds nuw i8, ptr %3, i64 64
  br label %28

27:                                               ; preds = %31
  call void @free(ptr noundef %4) #4
  br label %33

28:                                               ; preds = %.preheader, %31
  %.01722 = phi i32 [ 0, %.preheader ], [ %32, %31 ]
  store i64 1048576, ptr %1, align 8
  store i64 1048576, ptr %2, align 8
  store ptr %4, ptr %15, align 8
  store ptr %4, ptr %16, align 8
  store ptr null, ptr %17, align 8
  store ptr null, ptr %18, align 8
  store i32 4, ptr %3, align 8
  store i32 3, ptr %19, align 4
  store ptr %1, ptr %20, align 8
  store ptr %2, ptr %21, align 8
  store ptr @.offload_sizes, ptr %22, align 8
  store ptr @.offload_maptypes, ptr %23, align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %24, i8 0, i64 16, i1 false)
  store i64 1048576, ptr %25, align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(36) %26, i8 0, i64 36, i1 false)
  %29 = call i32 @__tgt_target_kernel(ptr nonnull @3, i64 -1, i32 0, i32 0, ptr nonnull @.__omp_offloading_811_507524_main_l15.region_id, ptr nonnull %3)
  %.not19 = icmp eq i32 %29, 0
  br i1 %.not19, label %31, label %30

30:                                               ; preds = %28
  call void (ptr, i32, ptr, ...) @__kmpc_fork_teams(ptr nonnull @3, i32 2, ptr nonnull @__omp_offloading_811_507524_main_l15.omp_outlined, i64 1048576, ptr nonnull %4)
  br label %31

31:                                               ; preds = %28, %30
  %32 = add nuw nsw i32 %.01722, 1
  %exitcond24.not = icmp eq i32 %32, 20
  br i1 %exitcond24.not, label %27, label %28, !llvm.loop !19

33:                                               ; preds = %0, %27
  %.0 = phi i32 [ 0, %27 ], [ 1, %0 ]
  ret i32 %.0
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(ptr captures(none)) #1

; Function Attrs: mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite, errnomem: write)
declare noalias noundef ptr @malloc(i64 noundef) local_unnamed_addr #2

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(ptr captures(none)) #1

; Function Attrs: alwaysinline norecurse nounwind uwtable
define internal void @__omp_offloading_811_507524_main_l15.omp_outlined(ptr noalias noundef readonly captures(none) %0, ptr noalias readnone captures(none) %1, i64 noundef %2, ptr noundef %3) #3 {
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  call void @llvm.lifetime.start.p0(ptr nonnull %5) #4
  store i32 0, ptr %5, align 4, !tbaa !8
  call void @llvm.lifetime.start.p0(ptr nonnull %6) #4
  store i32 1048575, ptr %6, align 4, !tbaa !8
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #4
  store i32 1, ptr %7, align 4, !tbaa !8
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #4
  store i32 0, ptr %8, align 4, !tbaa !8
  %9 = load i32, ptr %0, align 4, !tbaa !8
  call void @__kmpc_for_static_init_4(ptr nonnull @1, i32 %9, i32 92, ptr nonnull %8, ptr nonnull %5, ptr nonnull %6, ptr nonnull %7, i32 1, i32 1)
  %10 = load i32, ptr %6, align 4, !tbaa !8
  %11 = call i32 @llvm.smin.i32(i32 %10, i32 1048575)
  store i32 %11, ptr %6, align 4, !tbaa !8
  %12 = load i32, ptr %5, align 4, !tbaa !8
  %.not7 = icmp sgt i32 %12, %11
  br i1 %.not7, label %._crit_edge, label %.lr.ph

.lr.ph:                                           ; preds = %4
  %.sroa.0.0.insert.ext = and i64 %2, 4294967295
  br label %13

13:                                               ; preds = %.lr.ph, %13
  %14 = phi i32 [ %11, %.lr.ph ], [ %20, %13 ]
  %.08 = phi i32 [ %12, %.lr.ph ], [ %19, %13 ]
  %15 = load i32, ptr %5, align 4, !llvm.access.group !20
  %16 = zext i32 %15 to i64
  %17 = zext i32 %14 to i64
  call void (ptr, i32, ptr, ...) @__kmpc_fork_call(ptr nonnull @3, i32 4, ptr nonnull @__omp_offloading_811_507524_main_l15.omp_outlined.omp_outlined, i64 %16, i64 %17, i64 %.sroa.0.0.insert.ext, ptr %3), !llvm.access.group !20
  %18 = load i32, ptr %7, align 4, !tbaa !8, !llvm.access.group !20
  %19 = add nsw i32 %18, %.08
  %20 = load i32, ptr %6, align 4, !tbaa !8, !llvm.access.group !20
  %.not = icmp sgt i32 %19, %20
  br i1 %.not, label %._crit_edge, label %13, !llvm.loop !21

._crit_edge:                                      ; preds = %13, %4
  call void @__kmpc_for_static_fini(ptr nonnull @1, i32 %9)
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %6) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %5) #4
  ret void
}

; Function Attrs: nounwind
declare void @__kmpc_for_static_init_4(ptr, i32, i32, ptr, ptr, ptr, ptr, i32, i32) local_unnamed_addr #4

; Function Attrs: alwaysinline norecurse nounwind uwtable
define internal void @__omp_offloading_811_507524_main_l15.omp_outlined.omp_outlined(ptr noalias noundef readonly captures(none) %0, ptr noalias readnone captures(none) %1, i64 noundef %2, i64 noundef %3, i64 %4, ptr noundef captures(none) %5) #3 {
  %7 = alloca i32, align 4
  %8 = alloca i32, align 4
  %9 = alloca i32, align 4
  %10 = alloca i32, align 4
  call void @llvm.lifetime.start.p0(ptr nonnull %7) #4
  call void @llvm.lifetime.start.p0(ptr nonnull %8) #4
  %11 = trunc i64 %2 to i32
  %12 = trunc i64 %3 to i32
  store i32 %11, ptr %7, align 4, !tbaa !8
  store i32 %12, ptr %8, align 4, !tbaa !8
  call void @llvm.lifetime.start.p0(ptr nonnull %9) #4
  store i32 1, ptr %9, align 4, !tbaa !8
  call void @llvm.lifetime.start.p0(ptr nonnull %10) #4
  store i32 0, ptr %10, align 4, !tbaa !8
  %13 = load i32, ptr %0, align 4, !tbaa !8
  call void @__kmpc_for_static_init_4(ptr nonnull @2, i32 %13, i32 34, ptr nonnull %10, ptr nonnull %7, ptr nonnull %8, ptr nonnull %9, i32 1, i32 1)
  %14 = load i32, ptr %8, align 4, !tbaa !8
  %15 = call i32 @llvm.smin.i32(i32 %14, i32 1048575)
  store i32 %15, ptr %8, align 4, !tbaa !8
  %16 = load i32, ptr %7, align 4, !tbaa !8
  %.not10 = icmp sgt i32 %16, %15
  br i1 %.not10, label %._crit_edge, label %.lr.ph.preheader

.lr.ph.preheader:                                 ; preds = %6
  %17 = sext i32 %16 to i64
  %18 = add nsw i32 %15, 1
  %19 = sub i32 %15, %16
  %20 = zext i32 %19 to i64
  %21 = add nuw nsw i64 %20, 1
  %min.iters.check = icmp ult i32 %19, 7
  br i1 %min.iters.check, label %.lr.ph.preheader15, label %vector.ph

vector.ph:                                        ; preds = %.lr.ph.preheader
  %n.vec = and i64 %21, 8589934584
  %22 = add nsw i64 %n.vec, %17
  %invariant.gep = getelementptr [4 x i8], ptr %5, i64 %17
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %gep = getelementptr [4 x i8], ptr %invariant.gep, i64 %index
  %23 = getelementptr inbounds nuw i8, ptr %gep, i64 16
  %wide.load = load <4 x float>, ptr %gep, align 4, !tbaa !13, !llvm.access.group !24
  %wide.load14 = load <4 x float>, ptr %23, align 4, !tbaa !13, !llvm.access.group !24
  %24 = fmul <4 x float> %wide.load, splat (float 2.000000e+00)
  %25 = fmul <4 x float> %wide.load14, splat (float 2.000000e+00)
  store <4 x float> %24, ptr %gep, align 4, !tbaa !13, !llvm.access.group !24
  store <4 x float> %25, ptr %23, align 4, !tbaa !13, !llvm.access.group !24
  %index.next = add nuw i64 %index, 8
  %26 = icmp eq i64 %index.next, %n.vec
  br i1 %26, label %middle.block, label %vector.body, !llvm.loop !25

middle.block:                                     ; preds = %vector.body
  %cmp.n = icmp eq i64 %21, %n.vec
  br i1 %cmp.n, label %._crit_edge, label %.lr.ph.preheader15

.lr.ph.preheader15:                               ; preds = %.lr.ph.preheader, %middle.block
  %indvars.iv.ph = phi i64 [ %17, %.lr.ph.preheader ], [ %22, %middle.block ]
  br label %.lr.ph

.lr.ph:                                           ; preds = %.lr.ph.preheader15, %.lr.ph
  %indvars.iv = phi i64 [ %indvars.iv.next, %.lr.ph ], [ %indvars.iv.ph, %.lr.ph.preheader15 ]
  %27 = getelementptr inbounds [4 x i8], ptr %5, i64 %indvars.iv
  %28 = load float, ptr %27, align 4, !tbaa !13, !llvm.access.group !24
  %29 = fmul float %28, 2.000000e+00
  store float %29, ptr %27, align 4, !tbaa !13, !llvm.access.group !24
  %indvars.iv.next = add nsw i64 %indvars.iv, 1
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond.not = icmp eq i32 %18, %lftr.wideiv
  br i1 %exitcond.not, label %._crit_edge, label %.lr.ph, !llvm.loop !27

._crit_edge:                                      ; preds = %.lr.ph, %middle.block, %6
  call void @__kmpc_for_static_fini(ptr nonnull @2, i32 %13)
  call void @llvm.lifetime.end.p0(ptr nonnull %10) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %9) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %8) #4
  call void @llvm.lifetime.end.p0(ptr nonnull %7) #4
  ret void
}

; Function Attrs: nounwind
declare void @__kmpc_for_static_fini(ptr, i32) local_unnamed_addr #4

; Function Attrs: nounwind
declare !callback !28 void @__kmpc_fork_call(ptr, i32, ptr, ...) local_unnamed_addr #4

; Function Attrs: nounwind
declare !callback !28 void @__kmpc_fork_teams(ptr, i32, ptr, ...) local_unnamed_addr #4

; Function Attrs: nounwind
declare i32 @__tgt_target_kernel(ptr, i64, i32, i32, ptr, ptr) local_unnamed_addr #4

; Function Attrs: mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @free(ptr allocptr noundef captures(none)) local_unnamed_addr #5

; Function Attrs: nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none)
declare i32 @llvm.smin.i32(i32, i32) #6

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #7

attributes #0 = { nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { mustprogress nofree nounwind willreturn allockind("alloc,uninitialized") allocsize(0) memory(inaccessiblemem: readwrite, errnomem: write) "alloc-family"="malloc" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #3 = { alwaysinline norecurse nounwind uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { nounwind }
attributes #5 = { mustprogress nounwind willreturn allockind("free") memory(argmem: readwrite, inaccessiblemem: readwrite) "alloc-family"="malloc" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { nocallback nocreateundeforpoison nofree nosync nounwind speculatable willreturn memory(none) }
attributes #7 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #8 = { nounwind allocsize(0) }

!omp_offload.info = !{!1}
!llvm.offloading.symbols = !{!2}
!llvm.module.flags = !{!3, !4, !5, !6}
!llvm.ident = !{!7}
!llvm.errno.tbaa = !{!8}
!llvm.embedded.objects = !{!12}

!0 = !{}
!1 = !{i32 0, i32 2065, i32 5272868, !"main", i32 15, i32 0, i32 0}
!2 = !{ptr @.offloading.entry_name}
!3 = !{i32 7, !"openmp", i32 51}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{i32 7, !"PIE Level", i32 2}
!6 = !{i32 7, !"uwtable", i32 2}
!7 = !{!"clang version 23.0.0git (https://github.com/llvm/llvm-project.git 22b330eb09b9e4ab3d64a1f6ad0fe42e23569d77)"}
!8 = !{!9, !9, i64 0}
!9 = !{!"int", !10, i64 0}
!10 = !{!"omnipotent char", !11, i64 0}
!11 = !{!"Simple C/C++ TBAA"}
!12 = !{ptr @llvm.embedded.object, !".llvm.offloading"}
!13 = !{!14, !14, i64 0}
!14 = !{!"float", !10, i64 0}
!15 = distinct !{!15, !16, !17, !18}
!16 = !{!"llvm.loop.mustprogress"}
!17 = !{!"llvm.loop.isvectorized", i32 1}
!18 = !{!"llvm.loop.unroll.runtime.disable"}
!19 = distinct !{!19, !16}
!20 = distinct !{}
!21 = distinct !{!21, !22, !23}
!22 = !{!"llvm.loop.parallel_accesses", !20}
!23 = !{!"llvm.loop.vectorize.enable", i1 true}
!24 = distinct !{}
!25 = distinct !{!25, !26, !17, !18}
!26 = !{!"llvm.loop.parallel_accesses", !24}
!27 = distinct !{!27, !26, !18, !17}
!28 = !{!29}
!29 = !{i64 2, i64 -1, i64 -1, i1 true}
