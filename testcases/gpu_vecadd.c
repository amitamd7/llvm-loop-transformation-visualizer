// Simple vector add — used to test CPU and GPU profiling paths.
// CPU: clang -S -emit-llvm -O0 -fno-discard-value-names gpu_vecadd.c -o before.ll
//      opt -passes=licm before.ll -S -o after.ll
// GPU: clang -S -emit-llvm -fopenmp --offload-arch=gfx90a -O0 gpu_vecadd_omp.c -o before_gpu.ll
#include <stdlib.h>

void vecadd(float *restrict A, float *restrict B, float *restrict C, int N) {
  float scale = 2.0f;
  for (int i = 0; i < N; i++) {
    float s = scale * 3.0f;   // loop-invariant — LICM should hoist this
    C[i] = A[i] + B[i] * s;
  }
}

int main() {
  int N = 1024 * 1024;
  float *A = (float *)malloc(N * sizeof(float));
  float *B = (float *)malloc(N * sizeof(float));
  float *C = (float *)malloc(N * sizeof(float));
  for (int i = 0; i < N; i++) { A[i] = (float)i; B[i] = (float)(N - i); }
  for (int rep = 0; rep < 100; rep++)
    vecadd(A, B, C, N);
  free(A); free(B); free(C);
  return 0;
}
