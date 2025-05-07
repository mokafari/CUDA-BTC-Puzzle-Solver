#include <stdio.h>
#include <stdint.h>
#include "cuda_base_types.h"
#include "secp256k1_params.h"
#include "point_ops_new.h"
#include "address_new.h"

// Known test vectors for secp256k1
struct TestVector {
    uint64_t k[4];
    uint64_t expected_x[4];
    uint64_t expected_y[4];
};

// k=2 test vector (2G)
const TestVector TEST_VECTOR_2G = {
    {2, 0, 0, 0},
    {0xC6047F9441ED7D6D, 0x3045406E95C07CD8, 0x5C778E4B8CEF3CA7, 0xABACB95FD946343E},
    {0x1AE168FEA63DC339, 0xA3C58419466CEAEE, 0x7F8376544F7D5DA5, 0xF1D3AB8188FD11E0}
};

__global__ void generate_test_address(uint64_t* k, uint64_t* pubx, uint64_t* puby, unsigned char* address, uint64_t* debug_z) {
    if (threadIdx.x == 0 && blockIdx.x == 0) {
        // Create Jacobian point for generator G
        JPoint P;
        
        // Initialize P with generator point
        P.X[0] = 0x79BE667EF9DCBBAC;
        P.X[1] = 0x55A06295CE870B07;
        P.X[2] = 0x029BFCDB2DCE28D9;
        P.X[3] = 0x59F2815B16F81798;
        
        P.Y[0] = 0x483ADA7726A3C465;
        P.Y[1] = 0x5DA4FBFC0E1108A8;
        P.Y[2] = 0xFD17B448A6855419;
        P.Y[3] = 0x9C47D08FFB10D4B8;
        
        P.Z[0] = 1;
        P.Z[1] = P.Z[2] = P.Z[3] = 0;
        
        // Point double (k=2)
        point_double_jacobian(&P);
        
        // Save Z coordinate for debugging
        for(int i = 0; i < 4; i++) {
            debug_z[i] = P.Z[i];
        }
        
        // Convert back to affine coordinates
        jacobian_to_affine(pubx, puby, &P);
        
        // Generate Bitcoin address
        pubkey_to_address_kernel(address, pubx, puby);
    }
}

// Helper function to check CUDA errors
void checkCudaError(cudaError_t err, const char* msg) {
    if (err != cudaSuccess) {
        printf("CUDA Error at %s: %s\n", msg, cudaGetErrorString(err));
        exit(1);
    }
}

// Helper function to print uint256 in hex
void print_uint256(const char* label, const uint64_t* value) {
    printf("%s: 0x%016llx%016llx%016llx%016llx\n", 
           label, value[3], value[2], value[1], value[0]);
}

// Helper function to compare uint256 values
bool compare_uint256(const uint64_t* a, const uint64_t* b) {
    for(int i = 0; i < 4; i++) {
        if(a[i] != b[i]) return false;
    }
    return true;
}

int main() {
    cudaError_t err;
    
    // Initialize CUDA
    err = cudaSetDevice(0);
    checkCudaError(err, "cudaSetDevice");
    
    // Create CUDA events for timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    // Allocate device memory
    uint64_t *d_k, *d_pubx, *d_puby, *d_debug_z;
    unsigned char *d_address;
    
    err = cudaMalloc(&d_k, 4 * sizeof(uint64_t));
    checkCudaError(err, "cudaMalloc d_k");
    err = cudaMalloc(&d_pubx, 4 * sizeof(uint64_t));
    checkCudaError(err, "cudaMalloc d_pubx");
    err = cudaMalloc(&d_puby, 4 * sizeof(uint64_t));
    checkCudaError(err, "cudaMalloc d_puby");
    err = cudaMalloc(&d_debug_z, 4 * sizeof(uint64_t));
    checkCudaError(err, "cudaMalloc d_debug_z");
    err = cudaMalloc(&d_address, 20 * sizeof(unsigned char));
    checkCudaError(err, "cudaMalloc d_address");
    
    // Set up test private key (k=2)
    err = cudaMemcpy(d_k, TEST_VECTOR_2G.k, 4 * sizeof(uint64_t), cudaMemcpyHostToDevice);
    checkCudaError(err, "cudaMemcpy h_k->d_k");
    
    // Record start time
    cudaEventRecord(start);
    
    // Generate address
    generate_test_address<<<1, 1>>>(d_k, d_pubx, d_puby, d_address, d_debug_z);
    err = cudaDeviceSynchronize();
    checkCudaError(err, "kernel launch/sync");
    
    // Record stop time
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);
    
    float milliseconds = 0;
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    // Copy results back
    uint64_t h_pubx[4], h_puby[4], h_debug_z[4];
    unsigned char h_address[20];
    
    err = cudaMemcpy(h_pubx, d_pubx, 4 * sizeof(uint64_t), cudaMemcpyDeviceToHost);
    checkCudaError(err, "cudaMemcpy d_pubx->h_pubx");
    err = cudaMemcpy(h_puby, d_puby, 4 * sizeof(uint64_t), cudaMemcpyDeviceToHost);
    checkCudaError(err, "cudaMemcpy d_puby->h_puby");
    err = cudaMemcpy(h_debug_z, d_debug_z, 4 * sizeof(uint64_t), cudaMemcpyDeviceToHost);
    checkCudaError(err, "cudaMemcpy d_debug_z->h_debug_z");
    err = cudaMemcpy(h_address, d_address, 20 * sizeof(unsigned char), cudaMemcpyDeviceToHost);
    checkCudaError(err, "cudaMemcpy d_address->h_address");
    
    // Print test case details and metrics
    printf("\n=== Test Case Details (k=2) ===\n");
    printf("Expected values (2G):\n");
    print_uint256("X", TEST_VECTOR_2G.expected_x);
    print_uint256("Y", TEST_VECTOR_2G.expected_y);
    
    printf("\nComputed values:\n");
    print_uint256("X", h_pubx);
    print_uint256("Y", h_puby);
    print_uint256("Z", h_debug_z);
    
    printf("\nBitcoin Address: ");
    for(int i = 0; i < 20; i++) {
        printf("%02x", h_address[i]);
    }
    printf("\n");
    
    // Validate results
    bool x_correct = compare_uint256(h_pubx, TEST_VECTOR_2G.expected_x);
    bool y_correct = compare_uint256(h_puby, TEST_VECTOR_2G.expected_y);
    
    printf("\n=== Performance Metrics ===\n");
    printf("Total execution time: %.3f ms\n", milliseconds);
    printf("Point operations per second: %.2f\n", 1000.0f / milliseconds);
    
    printf("\n=== Validation Results ===\n");
    printf("X coordinate correct: %s\n", x_correct ? "YES" : "NO");
    printf("Y coordinate correct: %s\n", y_correct ? "YES" : "NO");
    
    // Free resources
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_k);
    cudaFree(d_pubx);
    cudaFree(d_puby);
    cudaFree(d_debug_z);
    cudaFree(d_address);
    
    return (x_correct && y_correct) ? 0 : 1;
}
