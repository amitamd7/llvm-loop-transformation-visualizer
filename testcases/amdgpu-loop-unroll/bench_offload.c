/* OpenMP offload loop — rocprof can run the linked host binary; IR differs with unroll flags. */
#include <omp.h>
#include <stdlib.h>

int main(void) {
  const int N = 1 << 20;
  float *a = (float *)malloc((size_t)N * sizeof(float));
  if (!a)
    return 1;
  for (int i = 0; i < N; ++i)
    a[i] = (float)i;

  /* Hot loop on device (matches scalar mul in kernel.c intent). */
  for (int rep = 0; rep < 20; ++rep)
#pragma omp target teams distribute parallel for simd
    for (int i = 0; i < N; ++i)
      a[i] = a[i] * 2.0f;

  free(a);
  return 0;
}
