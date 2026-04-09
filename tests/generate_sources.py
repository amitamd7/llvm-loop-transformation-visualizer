#!/usr/bin/env python3
"""
generate_sources.py — Generate diverse C source files for testing the
LLVM Loop Transform Visualiser against 50 CPU + 50 GPU transformations.

Sources are parameterized to exercise:
- Single / nested / deeply nested loops
- Known / unknown trip counts
- Stride-1 / strided / indirect memory access patterns
- Reductions, stencils, matrix ops, triangular loops
- Data dependencies (flow, anti, output, loop-carried)
- Multiple functions per file
- Edge cases: empty loops, single-iteration, huge trip counts

Each source is written to {outdir}/cpu_{N}.c or {outdir}/gpu_{N}.c.
"""

import os
import sys

CPU_SOURCES = [
    # (filename_suffix, description, code)
    ("single_loop_stride1", "simple stride-1 loop",
     """
void f(float *A, int N) {
  for (int i = 0; i < N; i++)
    A[i] = A[i] * 2.0f;
}
int main(void) {
  float A[1024];
  for (int i = 0; i < 1024; i++) A[i] = (float)i;
  for (int r = 0; r < 500; r++) f(A, 1024);
  return 0;
}"""),

    ("nested_2d_stride1", "nested 2D stride-1",
     """
#define N 64
double A[N][N], B[N][N];
void f(void) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++)
      B[i][j] = A[i][j] + 1.0;
}
int main(void) {
  for (int i=0;i<N;i++) for(int j=0;j<N;j++) A[i][j]=i*N+j;
  for (int r = 0; r < 200; r++) f();
  return 0;
}"""),

    ("nested_3d", "triple-nested loop",
     """
#define N 16
float C[N][N][N];
void f(float *restrict A) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++)
      for (int k = 0; k < N; k++)
        C[i][j][k] = A[i*N*N + j*N + k] + 1.0f;
}
int main(void) {
  float A[N*N*N];
  for (int i=0; i<N*N*N; i++) A[i]=(float)i;
  for (int r = 0; r < 100; r++) f(A);
  return 0;
}"""),

    ("reduction_sum", "simple reduction",
     """
float f(const float *A, int N) {
  float sum = 0.0f;
  for (int i = 0; i < N; i++)
    sum += A[i];
  return sum;
}
int main(void) {
  float A[2048];
  for (int i=0; i<2048; i++) A[i]=(float)i;
  volatile float s = 0;
  for (int r = 0; r < 1000; r++) s = f(A, 2048);
  return 0;
}"""),

    ("reduction_minmax", "min/max reduction",
     """
void f(const int *A, int N, int *mn, int *mx) {
  int lo = A[0], hi = A[0];
  for (int i = 1; i < N; i++) {
    if (A[i] < lo) lo = A[i];
    if (A[i] > hi) hi = A[i];
  }
  *mn = lo; *mx = hi;
}
int main(void) {
  int A[512]; for (int i=0;i<512;i++) A[i]=i*7-256;
  int mn, mx;
  for (int r=0; r<2000; r++) f(A, 512, &mn, &mx);
  return 0;
}"""),

    ("stencil_1d", "1D stencil",
     """
#define N 256
double A[N], B[N];
void f(void) {
  for (int i = 1; i < N-1; i++)
    B[i] = 0.25 * (A[i-1] + 2.0*A[i] + A[i+1]);
}
int main(void) {
  for (int i=0;i<N;i++) A[i]=(double)i;
  for (int r=0;r<1000;r++) f();
  return 0;
}"""),

    ("stencil_2d_jacobi", "2D Jacobi stencil",
     """
#define N 64
double A[N][N], B[N][N];
void f(void) {
  for (int i = 1; i < N-1; i++)
    for (int j = 1; j < N-1; j++)
      B[i][j] = 0.25*(A[i-1][j]+A[i+1][j]+A[i][j-1]+A[i][j+1]);
}
int main(void) {
  for(int i=0;i<N;i++) for(int j=0;j<N;j++) A[i][j]=i*N+j;
  for(int r=0;r<200;r++) f();
  return 0;
}"""),

    ("matmul_ijk", "matrix multiply i-j-k",
     """
#define N 32
double A[N][N], B[N][N], C[N][N];
void f(void) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++) {
      double s = 0.0;
      for (int k = 0; k < N; k++)
        s += A[i][k] * B[k][j];
      C[i][j] = s;
    }
}
int main(void) {
  for(int i=0;i<N;i++) for(int j=0;j<N;j++){A[i][j]=i+j;B[i][j]=i-j;}
  for(int r=0;r<50;r++) f();
  return 0;
}"""),

    ("strided_access", "strided memory access",
     """
void f(float *A, int N, int stride) {
  for (int i = 0; i < N; i++)
    A[i * stride] += 1.0f;
}
int main(void) {
  float A[8192]={0};
  for(int r=0;r<500;r++) f(A, 512, 8);
  return 0;
}"""),

    ("triangular_loop", "triangular nested loop",
     """
#define N 128
int A[N][N];
void f(void) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j <= i; j++)
      A[i][j] = A[i][j] + i + j;
}
int main(void) {
  for(int i=0;i<N;i++) for(int j=0;j<N;j++) A[i][j]=i*N+j;
  for(int r=0;r<500;r++) f();
  return 0;
}"""),

    ("loop_with_call", "loop containing a function call",
     """
static float helper(float x) { return x * x + 1.0f; }
void f(float *A, int N) {
  for (int i = 0; i < N; i++)
    A[i] = helper(A[i]);
}
int main(void) {
  float A[1024]; for(int i=0;i<1024;i++) A[i]=(float)i;
  for(int r=0;r<500;r++) f(A, 1024);
  return 0;
}"""),

    ("anti_dependency", "loop with anti-dependency",
     """
void f(float *A, int N) {
  for (int i = 0; i < N-1; i++)
    A[i] = A[i+1] + 1.0f;
}
int main(void) {
  float A[1024]; for(int i=0;i<1024;i++) A[i]=(float)i;
  for(int r=0;r<500;r++) f(A, 1024);
  return 0;
}"""),

    ("output_dependency", "loop with output dependency",
     """
void f(float *A, float *B, int N) {
  for (int i = 0; i < N; i++) {
    A[0] = B[i];
    A[0] = A[0] + 1.0f;
  }
}
int main(void) {
  float A[1]={0}, B[512]; for(int i=0;i<512;i++) B[i]=(float)i;
  for(int r=0;r<1000;r++) f(A, B, 512);
  return 0;
}"""),

    ("flow_dependency", "loop-carried flow dependency",
     """
void f(float *A, int N) {
  for (int i = 1; i < N; i++)
    A[i] = A[i-1] * 2.0f;
}
int main(void) {
  float A[1024]; A[0]=1.0f;
  for(int r=0;r<500;r++) f(A, 1024);
  return 0;
}"""),

    ("known_trip_fixed", "loop with fixed trip count 256",
     """
float A[256];
void f(void) {
  for (int i = 0; i < 256; i++)
    A[i] = A[i] * 3.14f;
}
int main(void) {
  for(int i=0;i<256;i++) A[i]=(float)i;
  for(int r=0;r<1000;r++) f();
  return 0;
}"""),

    ("unknown_trip", "loop with unknown trip count from parameter",
     """
void f(float *A, int N) {
  for (int i = 0; i < N; i++)
    A[i] = A[i] + (float)i;
}
int main(void) {
  float A[1024]; for(int i=0;i<1024;i++) A[i]=(float)i;
  for(int r=0;r<500;r++) f(A, 1024);
  return 0;
}"""),

    ("multi_function", "file with multiple loop functions",
     """
void f1(float *A, int N) { for (int i=0;i<N;i++) A[i]+=1.0f; }
void f2(float *A, int N) { for (int i=0;i<N;i++) A[i]*=2.0f; }
void f3(float *A, int N) {
  for (int i=1;i<N;i++) A[i] = A[i-1]+A[i];
}
int main(void) {
  float A[512]; for(int i=0;i<512;i++) A[i]=(float)i;
  for(int r=0;r<200;r++){f1(A,512);f2(A,512);f3(A,512);}
  return 0;
}"""),

    ("empty_body_loop", "loop with trivial body (no memory)",
     """
int f(int N) {
  int s = 0;
  for (int i = 0; i < N; i++) s++;
  return s;
}
int main(void) {
  volatile int s=0;
  for(int r=0;r<10000;r++) s=f(1000);
  return 0;
}"""),

    ("conditional_in_loop", "loop with if-else",
     """
void f(float *A, float *B, int N) {
  for (int i = 0; i < N; i++) {
    if (A[i] > 0.0f) B[i] = A[i] * 2.0f;
    else              B[i] = -A[i];
  }
}
int main(void) {
  float A[1024],B[1024]; for(int i=0;i<1024;i++) A[i]=(float)(i-512);
  for(int r=0;r<500;r++) f(A,B,1024);
  return 0;
}"""),

    ("dot_product", "dot product of two arrays",
     """
float f(const float *A, const float *B, int N) {
  float d = 0.0f;
  for (int i = 0; i < N; i++) d += A[i]*B[i];
  return d;
}
int main(void) {
  float A[1024],B[1024];
  for(int i=0;i<1024;i++){A[i]=(float)i;B[i]=(float)(1024-i);}
  volatile float r=0;
  for(int i=0;i<1000;i++) r=f(A,B,1024);
  return 0;
}"""),

    ("saxpy", "SAXPY: A[i] = a*X[i] + Y[i]",
     """
void f(float a, float *X, float *Y, float *A, int N) {
  for (int i = 0; i < N; i++) A[i] = a*X[i]+Y[i];
}
int main(void) {
  float X[2048],Y[2048],A[2048];
  for(int i=0;i<2048;i++){X[i]=(float)i;Y[i]=(float)(2048-i);}
  for(int r=0;r<500;r++) f(2.5f,X,Y,A,2048);
  return 0;
}"""),

    ("copy_array", "simple array copy",
     """
void f(float *dst, const float *src, int N) {
  for (int i = 0; i < N; i++) dst[i] = src[i];
}
int main(void) {
  float a[4096],b[4096]; for(int i=0;i<4096;i++) a[i]=(float)i;
  for(int r=0;r<500;r++) f(b,a,4096);
  return 0;
}"""),

    ("reverse_copy", "reverse array copy",
     """
void f(float *dst, const float *src, int N) {
  for (int i = 0; i < N; i++) dst[N-1-i] = src[i];
}
int main(void) {
  float a[2048],b[2048]; for(int i=0;i<2048;i++) a[i]=(float)i;
  for(int r=0;r<500;r++) f(b,a,2048);
  return 0;
}"""),

    ("prefix_sum", "sequential prefix sum",
     """
void f(int *A, int N) {
  for (int i = 1; i < N; i++) A[i] += A[i-1];
}
int main(void) {
  int A[512]; for(int i=0;i<512;i++) A[i]=1;
  for(int r=0;r<1000;r++){for(int i=0;i<512;i++) A[i]=1; f(A,512);}
  return 0;
}"""),

    ("polynomial_eval", "Horner polynomial evaluation",
     """
float f(const float *c, int deg, float x) {
  float r = c[deg];
  for (int i = deg-1; i >= 0; i--) r = r*x + c[i];
  return r;
}
int main(void) {
  float c[16]; for(int i=0;i<16;i++) c[i]=(float)i*0.1f;
  volatile float s=0;
  for(int r=0;r<10000;r++) s=f(c,15,1.5f);
  return 0;
}"""),

    ("histogram", "simple histogram",
     """
void f(const int *data, int N, int *hist, int bins) {
  for (int i = 0; i < N; i++) {
    int b = data[i] % bins;
    if (b >= 0 && b < bins) hist[b]++;
  }
}
int main(void) {
  int data[2048], hist[64]={0};
  for(int i=0;i<2048;i++) data[i]=i*7;
  for(int r=0;r<500;r++){for(int i=0;i<64;i++)hist[i]=0; f(data,2048,hist,64);}
  return 0;
}"""),
]

GPU_KERNEL_TEMPLATE = """
#define __global__ __attribute__((amdgpu_kernel))
{code}
"""

GPU_SOURCES = [
    ("reduce_sum", "GPU sum reduction",
     """__global__ void f(const float *in, float *out) {
  float s = 0.0f;
  for (int i = 0; i < 256; i++) s += in[i];
  *out = s;
}"""),

    ("reduce_max", "GPU max reduction",
     """__global__ void f(const float *in, float *out) {
  float m = in[0];
  for (int i = 1; i < 256; i++) if (in[i]>m) m=in[i];
  *out = m;
}"""),

    ("saxpy", "GPU SAXPY",
     """__global__ void f(float a, const float *X, const float *Y, float *A) {
  for (int i = 0; i < 256; i++) A[i] = a*X[i]+Y[i];
}"""),

    ("copy", "GPU array copy",
     """__global__ void f(float *dst, const float *src) {
  for (int i = 0; i < 512; i++) dst[i] = src[i];
}"""),

    ("scale", "GPU scale kernel",
     """__global__ void f(float *A, float s) {
  for (int i = 0; i < 512; i++) A[i] *= s;
}"""),

    ("add_arrays", "GPU vector add",
     """__global__ void f(const float *A, const float *B, float *C) {
  for (int i = 0; i < 256; i++) C[i] = A[i]+B[i];
}"""),

    ("dot_product", "GPU dot product",
     """__global__ void f(const float *A, const float *B, float *out) {
  float d = 0.0f;
  for (int i = 0; i < 256; i++) d += A[i]*B[i];
  *out = d;
}"""),

    ("stencil_1d", "GPU 1D stencil",
     """__global__ void f(const float *in, float *out) {
  for (int i = 1; i < 255; i++)
    out[i] = 0.25f*(in[i-1]+2.0f*in[i]+in[i+1]);
}"""),

    ("matmul_row", "GPU matrix row",
     """__global__ void f(const float *A, const float *B, float *C) {
  for (int j = 0; j < 32; j++) {
    float s = 0.0f;
    for (int k = 0; k < 32; k++) s += A[k]*B[k*32+j];
    C[j] = s;
  }
}"""),

    ("relu", "GPU ReLU activation",
     """__global__ void f(float *A) {
  for (int i = 0; i < 512; i++)
    A[i] = A[i] > 0.0f ? A[i] : 0.0f;
}"""),

    ("polynomial", "GPU polynomial evaluation",
     """__global__ void f(const float *c, float x, float *out) {
  float r = c[7];
  for (int i = 6; i >= 0; i--) r = r*x + c[i];
  *out = r;
}"""),

    ("prefix_sum_local", "GPU prefix sum",
     """__global__ void f(float *A) {
  for (int i = 1; i < 128; i++) A[i] += A[i-1];
}"""),

    ("transpose_block", "GPU block transpose",
     """__global__ void f(const float *in, float *out) {
  for (int i = 0; i < 16; i++)
    for (int j = 0; j < 16; j++)
      out[j*16+i] = in[i*16+j];
}"""),

    ("histogram_local", "GPU histogram",
     """__global__ void f(const int *data, int *hist) {
  for (int i = 0; i < 256; i++) {
    int b = data[i] & 63;
    hist[b]++;
  }
}"""),

    ("conv1d", "GPU 1D convolution",
     """__global__ void f(const float *in, const float *k, float *out) {
  for (int i = 2; i < 254; i++) {
    float s = 0.0f;
    for (int j = 0; j < 5; j++) s += in[i-2+j]*k[j];
    out[i] = s;
  }
}"""),

    ("max_pool", "GPU 1D max pooling",
     """__global__ void f(const float *in, float *out) {
  for (int i = 0; i < 128; i++) {
    float m = in[2*i];
    if (in[2*i+1] > m) m = in[2*i+1];
    out[i] = m;
  }
}"""),

    ("softmax_denom", "GPU softmax denominator",
     """__global__ void f(const float *in, float *out) {
  float s = 0.0f;
  for (int i = 0; i < 256; i++) s += in[i];
  for (int i = 0; i < 256; i++) out[i] = in[i] / s;
}"""),

    ("norm_l2", "GPU L2 norm",
     """__global__ void f(const float *A, float *out) {
  float s = 0.0f;
  for (int i = 0; i < 256; i++) s += A[i]*A[i];
  *out = s;
}"""),

    ("running_mean", "GPU running mean",
     """__global__ void f(const float *in, float *out) {
  float s = 0.0f;
  for (int i = 0; i < 256; i++) {
    s += in[i];
    out[i] = s / (float)(i+1);
  }
}"""),

    ("clamp", "GPU clamp values",
     """__global__ void f(float *A, float lo, float hi) {
  for (int i = 0; i < 512; i++) {
    if (A[i] < lo) A[i] = lo;
    else if (A[i] > hi) A[i] = hi;
  }
}"""),

    ("ewma", "GPU exponentially weighted moving average",
     """__global__ void f(const float *in, float *out, float alpha) {
  out[0] = in[0];
  for (int i = 1; i < 256; i++)
    out[i] = alpha*in[i] + (1.0f-alpha)*out[i-1];
}"""),

    ("abs_diff", "GPU absolute difference",
     """__global__ void f(const float *A, const float *B, float *C) {
  for (int i = 0; i < 256; i++) {
    float d = A[i]-B[i];
    C[i] = d > 0 ? d : -d;
  }
}"""),

    ("scatter", "GPU scatter-add (indirect)",
     """__global__ void f(const int *idx, const float *val, float *out) {
  for (int i = 0; i < 256; i++)
    out[idx[i] & 255] += val[i];
}"""),

    ("gather", "GPU gather (indirect load)",
     """__global__ void f(const int *idx, const float *in, float *out) {
  for (int i = 0; i < 256; i++) out[i] = in[idx[i] & 255];
}"""),

    ("fma_chain", "GPU fused-multiply-add chain",
     """__global__ void f(float *A, float b, float c) {
  for (int i = 0; i < 512; i++) A[i] = A[i]*b + c;
}"""),
]

CPU_PASSES = [
    "licm", "loop-unroll", "loop-rotate", "indvars",
    "loop-simplify", "loop-instsimplify", "loop-deletion",
    "loop-simplifycfg", "loop-sink", "loop-distribute",
    "loop-vectorize", "loop-versioning", "loop-versioning-licm",
    "loop-load-elim", "loop-idiom", "loop-reduce",
    "loop-bound-split", "loop-data-prefetch", "loop-predication",
    "loop-flatten", "loop-interchange",
    "loop-unroll-and-jam", "loop-fusion",
    "simple-loop-unswitch<nontrivial>",
]

GPU_PASSES = [
    "loop-unroll", "licm", "loop-rotate", "indvars",
    "loop-simplify", "loop-instsimplify", "loop-deletion",
    "loop-simplifycfg", "loop-sink", "loop-distribute",
    "loop-vectorize", "loop-versioning",
    "loop-load-elim", "loop-idiom", "loop-reduce",
    "loop-bound-split", "loop-data-prefetch", "loop-predication",
    "loop-flatten", "loop-interchange",
    "loop-unroll-and-jam", "loop-fusion",
    "simple-loop-unswitch<nontrivial>",
    "loop-versioning-licm",
]


def generate(outdir):
    os.makedirs(outdir, exist_ok=True)

    manifest = []

    # 50 CPU tests: pair sources with passes (round-robin)
    for idx in range(50):
        src_idx = idx % len(CPU_SOURCES)
        pass_idx = idx % len(CPU_PASSES)
        suffix, desc, code = CPU_SOURCES[src_idx]
        llvm_pass = CPU_PASSES[pass_idx]
        fname = f"cpu_{idx:02d}_{suffix}.c"
        path = os.path.join(outdir, fname)
        with open(path, 'w') as f:
            f.write(f"/* CPU test {idx}: {desc} + {llvm_pass} */\n")
            f.write(code.strip() + "\n")
        manifest.append({
            "id": f"cpu_{idx:02d}",
            "file": fname,
            "pass": llvm_pass,
            "desc": f"{desc} + {llvm_pass}",
            "mode": "cpu",
        })

    # 50 GPU tests: pair sources with passes (round-robin)
    for idx in range(50):
        src_idx = idx % len(GPU_SOURCES)
        pass_idx = idx % len(GPU_PASSES)
        suffix, desc, kernel_code = GPU_SOURCES[src_idx]
        llvm_pass = GPU_PASSES[pass_idx]
        fname = f"gpu_{idx:02d}_{suffix}.c"
        path = os.path.join(outdir, fname)
        with open(path, 'w') as f:
            full = GPU_KERNEL_TEMPLATE.format(code=kernel_code.strip())
            f.write(f"/* GPU test {idx}: {desc} + {llvm_pass} */\n")
            f.write(full.strip() + "\n")
        manifest.append({
            "id": f"gpu_{idx:02d}",
            "file": fname,
            "pass": llvm_pass,
            "desc": f"{desc} + {llvm_pass}",
            "mode": "gpu",
        })

    import json
    mpath = os.path.join(outdir, "manifest.json")
    with open(mpath, 'w') as f:
        json.dump(manifest, f, indent=2)
    print(f"Generated {len(manifest)} test sources in {outdir}/")
    print(f"Manifest: {mpath}")


if __name__ == "__main__":
    outdir = sys.argv[1] if len(sys.argv) > 1 else "tests/generated_sources"
    generate(outdir)
