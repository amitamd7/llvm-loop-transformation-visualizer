/* GPU reduction kernel — fixed trip count for visible loop-unroll effect. */
#define __global__ __attribute__((amdgpu_kernel))

__global__ void reduce_sum(const float *__restrict__ in, float *__restrict__ out) {
  float acc = 0.0f;
  for (int i = 0; i < 256; ++i)
    acc += in[i];
  *out = acc;
}
