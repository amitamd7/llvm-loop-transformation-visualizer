; Simple 1-D loop: one natural loop, stride-1 access to A[i].
; Compare with loop_tiling_after.ll (strip-mined / tiled) in the web diff view.
define void @tile_demo(ptr %A, i32 %N) {
entry:
  br label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %done = icmp sge i32 %i, %N
  br i1 %done, label %exit, label %body

body:
  %p = getelementptr inbounds i32, ptr %A, i32 %i
  %v = load i32, ptr %p
  %v2 = add i32 %v, 1
  store i32 %v2, ptr %p
  %inc = add i32 %i, 1
  br label %loop

exit:
  ret void
}
