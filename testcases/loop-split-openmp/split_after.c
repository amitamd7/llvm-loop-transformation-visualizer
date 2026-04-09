/* OpenMP 6.0 split: iteration space partitioned into chunks + fill (branch). */
extern void body(int);

void split_demo(int n) {
#pragma omp split counts(3, omp_fill)
  for (int i = 0; i < n; ++i)
    body(i);
}
