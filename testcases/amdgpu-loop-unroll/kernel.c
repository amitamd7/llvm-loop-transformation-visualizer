/* Simple device loop — compiled to amdgcn IR for opt loop-unroll comparison. */
#define __device__ __attribute__((amdgpu_kernel))

__device__ void kernel(float *a, int n) {
  for (int i = 0; i < n; ++i)
    a[i] = a[i] * 2.0f;
}
