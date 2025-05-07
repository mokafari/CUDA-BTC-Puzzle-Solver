#include "test_suite.cuh"
#include "../src/point_types.h"
#include "../src/modular_arithmetic.cuh"
#include "../src/point_operations.cuh"
#include "../src/sha256_cuda.cuh"
#include "../src/ripemd160_cuda.cuh"
#include "../src/address_optimized.cuh"

// Test modular arithmetic operations
__global__ void test_modular_arithmetic(TestResult* results, const ModArithTestVector* vectors, int num_vectors) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_vectors) return;
    
    uint64_t result[4];
    const ModArithTestVector* test = &vectors[idx];
    
    if (strcmp(test->operation, "add") == 0) {
        mod_add_optimized(result, test->a, test->b, P);
    } else if (strcmp(test->operation, "sub") == 0) {
        mod_sub_optimized(result, test->a, test->b, P);
    } else if (strcmp(test->operation, "mul") == 0) {
        mod_mul_optimized(result, test->a, test->b, P);
    }
    
    bool passed = true;
    for (int i = 0; i < 4 && passed; i++) {
        passed = (result[i] == test->expected[i]);
    }
    
    results[idx].passed = passed;
    results[idx].test_name = test->operation;
    results[idx].message = passed ? "Success" : "Result mismatch";
}

// Test point operations
__global__ void test_point_operations(TestResult* results, const PointOpTestVector* vectors, int num_vectors) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_vectors) return;
    
    const PointOpTestVector* test = &vectors[idx];
    JPoint result;
    
    // Perform scalar multiplication
    scalar_multiply_optimized(result.x, result.y, test->k);
    
    bool passed = true;
    for (int i = 0; i < 4 && passed; i++) {
        passed = (result.x[i] == test->expected_x[i] && 
                 result.y[i] == test->expected_y[i]);
    }
    
    results[idx].passed = passed;
    results[idx].test_name = "Scalar Multiplication";
    results[idx].message = passed ? "Success" : "Point mismatch";
}

// Test hash functions
__global__ void test_hash_functions(TestResult* results, const HashTestVector* vectors, int num_vectors) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_vectors) return;
    
    const HashTestVector* test = &vectors[idx];
    uint8_t hash[32];
    
    if (idx % 2 == 0) {
        // SHA256 test
        sha256_hash_optimized(test->input, test->input_len, hash);
        results[idx].test_name = "SHA256";
    } else {
        // RIPEMD160 test
        RIPEMD160_Hash(test->input, test->input_len, hash);
        results[idx].test_name = "RIPEMD160";
    }
    
    bool passed = true;
    for (int i = 0; i < (idx % 2 == 0 ? 32 : 20) && passed; i++) {
        passed = (hash[i] == test->expected[i]);
    }
    
    results[idx].passed = passed;
    results[idx].message = passed ? "Success" : "Hash mismatch";
}

// Test address generation
__global__ void test_address_generation(TestResult* results, const AddressTestVector* vectors, int num_vectors) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_vectors) return;
    
    const AddressTestVector* test = &vectors[idx];
    uint8_t address[25];
    uint8_t isDist;
    
    generate_address_optimized_test(test->private_key, address, &isDist);
    
    // Convert binary address to base58check
    char base58_addr[35];
    base58check_encode(address, 25, (uint8_t*)base58_addr);
    
    bool passed = strcmp(base58_addr, test->expected_address) == 0;
    
    results[idx].passed = passed;
    results[idx].test_name = "Address Generation";
    results[idx].message = passed ? "Success" : "Address mismatch";
}

// Performance benchmark kernels
__global__ void benchmark_mod_arithmetic(uint64_t* throughput) {
    const int NUM_ITERATIONS = 1000000;
    uint64_t a[4] = {1, 0, 0, 0};
    uint64_t b[4] = {2, 0, 0, 0};
    uint64_t r[4];
    
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    cudaEventRecord(start);
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        mod_add_optimized(r, a, b, P);
        mod_mul_optimized(r, a, b, P);
    }
    cudaEventRecord(stop);
    
    float milliseconds = 0;
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    *throughput = (uint64_t)((NUM_ITERATIONS * 2 * 1000.0f) / milliseconds);
}

__global__ void benchmark_point_ops(uint64_t* throughput) {
    const int NUM_ITERATIONS = 10000;
    uint64_t k[4] = {1, 0, 0, 0};
    JPoint result;
    
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    cudaEventRecord(start);
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        scalar_multiply_optimized(result.x, result.y, k);
    }
    cudaEventRecord(stop);
    
    float milliseconds = 0;
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    *throughput = (uint64_t)((NUM_ITERATIONS * 1000.0f) / milliseconds);
}

__global__ void benchmark_hashing(uint64_t* throughput) {
    const int NUM_ITERATIONS = 100000;
    const uint8_t data[] = "benchmark data for hashing";
    uint8_t hash[32];
    
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    cudaEventRecord(start);
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        sha256_hash_optimized(data, sizeof(data)-1, hash);
        RIPEMD160_Hash(hash, 32, hash);
    }
    cudaEventRecord(stop);
    
    float milliseconds = 0;
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    *throughput = (uint64_t)((NUM_ITERATIONS * 1000.0f) / milliseconds);
}

__global__ void benchmark_address_gen(uint64_t* throughput) {
    const int NUM_ITERATIONS = 10000;
    uint64_t private_key[4] = {1, 0, 0, 0};
    uint8_t address[25];
    uint8_t isDist;
    
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    
    cudaEventRecord(start);
    for (int i = 0; i < NUM_ITERATIONS; i++) {
        generate_address_optimized_test(private_key, address, &isDist);
    }
    cudaEventRecord(stop);
    
    float milliseconds = 0;
    cudaEventSynchronize(stop);
    cudaEventElapsedTime(&milliseconds, start, stop);
    
    *throughput = (uint64_t)((NUM_ITERATIONS * 1000.0f) / milliseconds);
}
