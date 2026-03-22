; tiny module for ll-dump smoke test
define i32 @foo(i32 %x) {
entry:
  %cmp = icmp slt i32 %x, 0
  br i1 %cmp, label %neg, label %pos

neg:
  %n = sub i32 0, %x
  br label %merge

pos:
  br label %merge

merge:
  %r = phi i32 [ %n, %neg ], [ %x, %pos ]
  ret i32 %r
}

declare void @bar()

; simple counted loop + inner loop for nested LoopInfo
define void @nested_loops(i32 %n) {
entry:
  br label %outer

outer:
  %oi = phi i32 [ 0, %entry ], [ %oinc, %outer.inc ]
  %outer_done = icmp sge i32 %oi, %n
  br i1 %outer_done, label %outer.end, label %outer.body

outer.body:
  br label %inner

inner:
  %ii = phi i32 [ 0, %outer.body ], [ %iinc, %inner.inc ]
  %inner_done = icmp sge i32 %ii, %n
  br i1 %inner_done, label %inner.end, label %inner.inc

inner.inc:
  %iinc = add i32 %ii, 1
  br label %inner

inner.end:
  br label %outer.inc

outer.inc:
  %oinc = add i32 %oi, 1
  br label %outer

outer.end:
  ret void
}

; GEP + load/store: stride-1 and strided (2*i) index
define void @array_walk(ptr %arr, i32 %n) {
entry:
  br label %loop

loop:
  %i = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %done = icmp sge i32 %i, %n
  br i1 %done, label %exit, label %body

body:
  %p = getelementptr inbounds i32, ptr %arr, i32 %i
  %v = load i32, ptr %p
  store i32 %v, ptr %p
  %i2 = shl i32 %i, 1
  %p2 = getelementptr inbounds i32, ptr %arr, i32 %i2
  %v2 = load i32, ptr %p2
  %inc = add i32 %i, 1
  br label %loop

exit:
  ret void
}
