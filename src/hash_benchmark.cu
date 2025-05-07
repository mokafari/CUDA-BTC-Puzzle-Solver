#include <cuda_runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sha256_optimized.cuh"
#include "ripemd160_optimized.cuh"

// Benchmark parameters
#define NUM_ITERATIONS 1000
#define MAX_BATCH_SIZE 1024
#define MAX_INPUT_SIZE 1024
#define NUM_BLOCKS 256
#define THREADS_PER_BLOCK 256

// Benchmark kernels
__global__ void benchmark_sha256_kernel(uint8_t* inputs, size_t* input_lengths,
                                      uint8_t* outputs, int num_inputs) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_inputs) return;
    
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, inputs + idx * SHA256_BLOCK_SIZE, input_lengths[idx]);
    sha256_final(&ctx, outputs + idx * SHA256_DIGEST_SIZE);
}

__global__ void benchmark_ripemd160_kernel(uint8_t* inputs, size_t* input_lengths,
                                         uint8_t* outputs, int num_inputs) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_inputs) return;
    
    RIPEMD160_CTX ctx;
    ripemd160_init(&ctx);
    ripemd160_update(&ctx, inputs + idx * RIPEMD160_BLOCK_SIZE, input_lengths[idx]);
    ripemd160_final(&ctx, outputs + idx * RIPEMD160_DIGEST_SIZE);
}

// Host functions for benchmarking
void benchmark_hash_function(const char* name, void (*kernel)(uint8_t*, size_t*, uint8_t*, int),
                           int block_size, int digest_size) {
    // Allocate host memory
    uint8_t* h_inputs = (uint8_t*)malloc(MAX_BATCH_SIZE * block_size);
    size_t* h_input_lengths = (size_t*)malloc(MAX_BATCH_SIZE * sizeof(size_t));
    uint8_t* h_outputs = (uint8_t*)malloc(MAX_BATCH_SIZE * digest_size);
    
    // Initialize test data
    for (int i = 0; i < MAX_BATCH_SIZE; i++) {
        h_input_lengths[i] = block_size;
        for (int j = 0; j < block_size; j++) {
            h_inputs[i * block_size + j] = (uint8_t)(rand() % 256);
        }
    }
    
    // Allocate device memory
    uint8_t *d_inputs, *d_outputs;
    size_t *d_input_lengths;
    cudaMalloc(&d_inputs, MAX_BATCH_SIZE * block_size);
    cudaMalloc(&d_outputs, MAX_BATCH_SIZE * digest_size);
    cudaMalloc(&d_input_lengths, MAX_BATCH_SIZE * sizeof(size_t));
    
    // Copy data to device
    cudaMemcpy(d_inputs, h_inputs, MAX_BATCH_SIZE * block_size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_input_lengths, h_input_lengths, MAX_BATCH_SIZE * sizeof(size_t), cudaMemcpyHostToDevice);
    
    // Create CUDA events for timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    // Warm up
    kernel<<<NUM_BLOCKS, THREADS_PER_BLOCK>>>(d_inputs, d_input_lengths, d_outputs, MAX_BATCH_SIZE);
    
    // Benchmark
    float total_time = 0;
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        cudaEventRecord(start);
        kernel<<<NUM_BLOCKS, THREADS_PER_BLOCK>>>(d_inputs, d_input_lengths, d_outputs, MAX_BATCH_SIZE);
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        
        float milliseconds = 0;
        cudaEventElapsedTime(&milliseconds, start, stop);
        total_time += milliseconds;
    }
    
    // Calculate and print results
    float avg_time = total_time / NUM_ITERATIONS;
    float hashes_per_second = (MAX_BATCH_SIZE * 1000.0f) / avg_time;
    
    printf("%s Benchmark Results:\n", name);
    printf("  Average time per batch: %.3f ms\n", avg_time);
    printf("  Hashes per second: %.2f\n", hashes_per_second);
    printf("  Batch size: %d\n", MAX_BATCH_SIZE);
    printf("  Input size: %d bytes\n\n", block_size);
    
    // Cleanup
    cudaFree(d_inputs);
    cudaFree(d_outputs);
    cudaFree(d_input_lengths);
    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    free(h_inputs);
    free(h_outputs);
    free(h_input_lengths);
}

int main() {
    // Set random seed
    srand(time(NULL));
    
    printf("Starting Hash Function Benchmarks\n");
    printf("=================================\n\n");
    
    // Benchmark SHA256
    benchmark_hash_function("SHA256", 
                          (void(*)(uint8_t*, size_t*, uint8_t*, int))benchmark_sha256_kernel,
                          SHA256_BLOCK_SIZE, SHA256_DIGEST_SIZE);
    
    // Benchmark RIPEMD160
    benchmark_hash_function("RIPEMD160",
                          (void(*)(uint8_t*, size_t*, uint8_t*, int))benchmark_ripemd160_kernel,
                          RIPEMD160_BLOCK_SIZE, RIPEMD160_DIGEST_SIZE);
    
    printf("Benchmark Complete\n");
    return 0;
}
