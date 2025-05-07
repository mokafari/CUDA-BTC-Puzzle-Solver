#include <stdio.h>
#include <cuda_runtime.h>
#include "kernel.h"
#include "test_kernel.h"
#include "benchmark.h"
#include "address_optimized.h"
#include "distinguished_points.cuh"

// Constants for kernel launch configuration
const int THREADS_PER_BLOCK = 256;
const int MAX_BLOCKS = 65535;

int main(int argc, char** argv) {
    printf("Bitcoin Puzzle Break\n");
    printf("===================\n\n");
    
    // Initialize CUDA
    cudaError_t err = cudaSetDevice(0);
    if (err != cudaSuccess) {
        printf("Error: Failed to initialize CUDA device: %s\n", cudaGetErrorString(err));
        return 1;
    }
    
    // Run tests if requested
    if (argc > 1 && strcmp(argv[1], "--test") == 0) {
        if (!run_component_tests()) {
            printf("Error: Component tests failed\n");
            return 1;
        }
    }
    
    // Run benchmarks if requested
    if (argc > 1 && strcmp(argv[1], "--benchmark") == 0) {
        run_benchmarks();
        return 0;
    }
    
    // Main search loop
    printf("Starting private key search...\n");
    
    // Allocate device memory
    uint8_t* d_target;
    bool* d_found;
    cudaMalloc(&d_target, 20);
    cudaMalloc(&d_found, sizeof(bool));
    cudaMemset(d_found, 0, sizeof(bool));
    
    // Target address (replace with actual target)
    uint8_t target_address[20] = {
        0x62, 0x31, 0x50, 0x63, 0x9f, 0xef, 0xc8, 0x7c,
        0x65, 0x52, 0x1f, 0x5c, 0xa3, 0x35, 0x0c, 0x79,
        0x89, 0xb5, 0x47, 0x66
    };
    
    // Copy target address to device
    cudaMemcpy(d_target, target_address, 20, cudaMemcpyHostToDevice);
    
    // Calculate grid dimensions
    int num_threads = THREADS_PER_BLOCK;
    int num_blocks = (num_threads + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    if (num_blocks > MAX_BLOCKS) num_blocks = MAX_BLOCKS;
    
    dim3 grid(num_blocks);
    dim3 block(THREADS_PER_BLOCK);
    
    // Start from key = 1
    uint64_t current_key[4] = {1, 0, 0, 0};
    size_t batch_size = num_blocks * THREADS_PER_BLOCK;
    
    bool found = false;
    while (!found) {
        // Launch kernel
        search_private_key<<<grid, block>>>(current_key, batch_size, d_target, d_found);
        
        // Check for errors
        err = cudaGetLastError();
        if (err != cudaSuccess) {
            printf("Error: Failed to launch kernel: %s\n", cudaGetErrorString(err));
            break;
        }
        
        // Check if key was found
        cudaMemcpy(&found, d_found, sizeof(bool), cudaMemcpyDeviceToHost);
        if (found) break;
        
        // Update current key for next batch
        current_key[0] += batch_size;
        if (current_key[0] < batch_size) {  // Handle overflow
            current_key[1]++;
            if (current_key[1] == 0) {
                current_key[2]++;
                if (current_key[2] == 0) {
                    current_key[3]++;
                }
            }
        }
    }
    
    // Cleanup
    cudaFree(d_target);
    cudaFree(d_found);
    
    return 0;
}
