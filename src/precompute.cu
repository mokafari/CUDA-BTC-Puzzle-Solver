#include <cuda_runtime.h>
#include "point_ops_new.h"
#include "secp256k1_params.h"

// Host arrays for precomputed points
uint64_t h_precomp_x[16][4];
uint64_t h_precomp_y[16][4];

// Function to initialize precomputed points
void initialize_precomputed_points() {
    // Base point (generator)
    uint64_t x[4], y[4];
    copy(x, Gx);
    copy(y, Gy);
    
    // Store generator point
    for (int j = 0; j < 4; j++) {
        h_precomp_x[1][j] = x[j];
        h_precomp_y[1][j] = y[j];
    }
    
    // Compute 2G through 15G
    JPoint P;
    affine_to_jacobian(&P, x, y);
    
    for (int i = 2; i < 16; i++) {
        point_add_mixed(&P, x, y);
        jacobian_to_affine(x, y, &P);
        
        for (int j = 0; j < 4; j++) {
            h_precomp_x[i][j] = x[j];
            h_precomp_y[i][j] = y[j];
        }
    }
    
    // Point at infinity for index 0
    for (int j = 0; j < 4; j++) {
        h_precomp_x[0][j] = h_precomp_y[0][j] = 0;
    }
    h_precomp_y[0][0] = 1;  // Y coordinate of point at infinity
    
    // Copy precomputed tables to device constant memory
    cudaMemcpyToSymbol(precomp_x, h_precomp_x, sizeof(h_precomp_x));
    cudaMemcpyToSymbol(precomp_y, h_precomp_y, sizeof(h_precomp_y));
}
