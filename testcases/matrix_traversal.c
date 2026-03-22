#include <stdio.h>
#define N 64

int main() {
    int A[N][N];

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            A[i][j] = i + j;
        }
    }

    return 0;
}
