#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cuda_runtime.h>
#include "test_suite.cuh"
#include "test_vectors.h"

// Utility function to check CUDA errors
#define CHECK_CUDA_ERROR(call) { \
    cudaError_t err = call; \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA error in %s:%d: %s\n", __FILE__, __LINE__, \
                cudaGetErrorString(err)); \
        return false; \
    } \
}

// Helper function to run tests and print results
bool run_test_category(const char* category_name, void(*test_kernel)(TestResult*, void*, int), 
                      void* vectors, int num_vectors, int num_blocks, int num_threads) {
    TestResult* d_results;
    TestResult* h_results;
    bool all_passed = true;
    
    // Allocate device and host memory
    h_results = (TestResult*)malloc(num_vectors * sizeof(TestResult));
    if (!h_results) {
        fprintf(stderr, "Failed to allocate host memory\n");
        return false;
    }
    
    if (cudaMalloc(&d_results, num_vectors * sizeof(TestResult)) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate device memory\n");
        free(h_results);
        return false;
    }
    
    // Run test kernel
    test_kernel<<<num_blocks, num_threads>>>(d_results, vectors, num_vectors);
    
    // Copy results back
    if (cudaMemcpy(h_results, d_results, num_vectors * sizeof(TestResult), 
                   cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to copy results from device\n");
        free(h_results);
        cudaFree(d_results);
        return false;
    }
    
    // Print results
    printf("\n=== %s Tests ===\n", category_name);
    for (int i = 0; i < num_vectors; i++) {
        printf("%s: %s\n", h_results[i].test_name, 
               h_results[i].passed ? "PASS" : "FAIL");
        if (!h_results[i].passed) {
            printf("  Error: %s\n", h_results[i].message);
            all_passed = false;
        }
    }
    
    // Cleanup
    free(h_results);
    if (cudaFree(d_results) != cudaSuccess) {
        fprintf(stderr, "Failed to free device memory\n");
        return false;
    }
    
    return all_passed;
}

// Run performance benchmarks
bool run_benchmarks() {
    uint64_t* d_throughput;
    uint64_t h_throughput;
    
    if (cudaMalloc(&d_throughput, sizeof(uint64_t)) != cudaSuccess) {
        fprintf(stderr, "Failed to allocate benchmark memory\n");
        return false;
    }
    
    printf("\n=== Performance Benchmarks ===\n");
    
    // Modular arithmetic benchmark
    benchmark_mod_arithmetic<<<1, 256>>>(d_throughput);
    if (cudaMemcpy(&h_throughput, d_throughput, sizeof(uint64_t), 
                   cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to read benchmark results\n");
        cudaFree(d_throughput);
        return false;
    }
    printf("Modular arithmetic: %llu ops/sec\n", h_throughput);
    
    // Point operations benchmark
    benchmark_point_ops<<<1, 256>>>(d_throughput);
    if (cudaMemcpy(&h_throughput, d_throughput, sizeof(uint64_t), 
                   cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to read benchmark results\n");
        cudaFree(d_throughput);
        return false;
    }
    printf("Point operations: %llu ops/sec\n", h_throughput);
    
    // Hash functions benchmark
    benchmark_hashing<<<1, 256>>>(d_throughput);
    if (cudaMemcpy(&h_throughput, d_throughput, sizeof(uint64_t), 
                   cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to read benchmark results\n");
        cudaFree(d_throughput);
        return false;
    }
    printf("Hash functions: %llu ops/sec\n", h_throughput);
    
    // Address generation benchmark
    benchmark_address_gen<<<1, 256>>>(d_throughput);
    if (cudaMemcpy(&h_throughput, d_throughput, sizeof(uint64_t), 
                   cudaMemcpyDeviceToHost) != cudaSuccess) {
        fprintf(stderr, "Failed to read benchmark results\n");
        cudaFree(d_throughput);
        return false;
    }
    printf("Address generation: %llu ops/sec\n", h_throughput);
    
    if (cudaFree(d_throughput) != cudaSuccess) {
        fprintf(stderr, "Failed to free benchmark memory\n");
        return false;
    }
    
    return true;
}

int main() {
    bool all_tests_passed = true;
    
    // Run modular arithmetic tests
    all_tests_passed &= run_test_category(
        "Modular Arithmetic",
        (void(*)(TestResult*, void*, int))test_modular_arithmetic,
        (void*)MOD_ARITH_VECTORS,
        sizeof(MOD_ARITH_VECTORS) / sizeof(MOD_ARITH_VECTORS[0]),
        1, 256
    );
    
    // Run point operation tests
    all_tests_passed &= run_test_category(
        "Point Operations",
        (void(*)(TestResult*, void*, int))test_point_operations,
        (void*)POINT_OP_VECTORS,
        sizeof(POINT_OP_VECTORS) / sizeof(POINT_OP_VECTORS[0]),
        1, 256
    );
    
    // Run hash function tests
    all_tests_passed &= run_test_category(
        "Hash Functions",
        (void(*)(TestResult*, void*, int))test_hash_functions,
        (void*)HASH_VECTORS,
        sizeof(HASH_VECTORS) / sizeof(HASH_VECTORS[0]),
        1, 256
    );
    
    // Run address generation tests
    all_tests_passed &= run_test_category(
        "Address Generation",
        (void(*)(TestResult*, void*, int))test_address_generation,
        (void*)ADDRESS_VECTORS,
        sizeof(ADDRESS_VECTORS) / sizeof(ADDRESS_VECTORS[0]),
        1, 256
    );
    
    // Run performance benchmarks
    if (all_tests_passed) {
        if (!run_benchmarks()) {
            all_tests_passed = false;
        }
    }
    
    printf("\n=== Test Suite Summary ===\n");
    printf("Overall result: %s\n", all_tests_passed ? "PASS" : "FAIL");
    
    return all_tests_passed ? 0 : 1;
}
