/* Runnable baseline for perf stat: same trip space as bench_after.c, no omp split. */
void body(int i) { (void)i; }

void split_demo(int n) {
  for (int i = 0; i < n; ++i)
    body(i);
}

int main(void) {
  for (int r = 0; r < 2000; ++r)
    split_demo(4096);
  return 0;
}
