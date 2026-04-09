#define N 128

double A[N][N], B[N][N];

void jacobi_step(void) {
  for (int i = 1; i < N - 1; i++)
    for (int j = 1; j < N - 1; j++)
      B[i][j] = 0.25 * (A[i-1][j] + A[i+1][j] + A[i][j-1] + A[i][j+1]);
}

int main(void) {
  for (int i = 0; i < N; i++)
    for (int j = 0; j < N; j++)
      A[i][j] = (double)(i * N + j);
  for (int iter = 0; iter < 200; iter++)
    jacobi_step();
  return 0;
}
