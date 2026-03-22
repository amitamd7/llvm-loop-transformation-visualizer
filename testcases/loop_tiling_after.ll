; Tiled version (tile size 4): outer loop advances t += 4, inner scans i in [t, min(t+4, N)).
; Same @tile_demo name/signature as loop_tiling_before.ll for side-by-side diff in the UI.
define void @tile_demo(ptr %A, i32 %N) {
entry:
  br label %outer

outer:
  %t = phi i32 [ 0, %entry ], [ %tnext, %outer_inc ]
  %outer_done = icmp sge i32 %t, %N
  br i1 %outer_done, label %exit, label %inner_entry

inner_entry:
  br label %inner

inner:
  %i = phi i32 [ %t, %inner_entry ], [ %iinc, %inner_step ]
  %t_end = add i32 %t, 4
  %past_tile = icmp sge i32 %i, %t_end
  %past_n = icmp sge i32 %i, %N
  %stop_inner = or i1 %past_tile, %past_n
  br i1 %stop_inner, label %outer_inc, label %body

body:
  %p = getelementptr inbounds i32, ptr %A, i32 %i
  %v = load i32, ptr %p
  %v2 = add i32 %v, 1
  store i32 %v2, ptr %p
  br label %inner_step

inner_step:
  %iinc = add i32 %i, 1
  br label %inner

outer_inc:
  %tnext = add i32 %t, 4
  br label %outer

exit:
  ret void
}
