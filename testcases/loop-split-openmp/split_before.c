/* Baseline: single canonical loop (no omp split). Mirrors split_after trip space. */
extern void body(int);

void split_demo(int n) {
  for (int i = 0; i < n; ++i)
    body(i);
}
