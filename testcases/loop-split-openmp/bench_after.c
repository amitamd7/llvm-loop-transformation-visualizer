/* Runnable OpenMP 6 split variant — use same Clang as branch tiwari_loop_splitting. */
void body(int i) { (void)i; }

void split_demo(int n) {
#pragma omp split counts(3, omp_fill)
  for (int i = 0; i < n; ++i)
    body(i);
}

int main(void) {
  for (int r = 0; r < 2000; ++r)
    split_demo(4096);
  return 0;
}
