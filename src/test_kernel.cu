#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <stdio.h>
#include "test_suite.h"
#include "point_ops_new.h"
#include "address_new.h"
#include "sha256_optimized.cuh"
#include "ripemd-160cuda-main/ripemd160_cuda.cuh"
#include "address_optimized.h"
#include "test_kernel.h"
#include "point_ops_optimized.h"
#include "address_optimized.h"
#include "test_data.h"

#include "test_types.h"
#include "sha256_optimized.cuh"
#include "ripemd160_optimized.cuh"
#include "point_ops_optimized.cuh"
#include "address_optimized.cuh"

// Test kernel for SHA256
__global__ void test_sha256(const HashTest* test_cases, int num_cases, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_cases) return;
    
    const HashTest* test = &test_cases[idx];
    uint8_t hash[32];
    
    // Compute hash
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, (const uint8_t*)test->message, test->length);
    sha256_final(&ctx, hash);
    
    // Convert expected hex string to bytes
    uint8_t expected[32];
    for (int i = 0; i < 32; i++) {
        char high = test->expected[i*2];
        char low = test->expected[i*2+1];
        high = (high >= 'a') ? (high - 'a' + 10) : (high - '0');
        low = (low >= 'a') ? (low - 'a' + 10) : (low - '0');
        expected[i] = (high << 4) | low;
    }
    
    // Compare results
    bool match = true;
    for (int i = 0; i < 32; i++) {
        if (hash[i] != expected[i]) {
            match = false;
            break;
        }
    }
    
    results[idx] = match;
}

// Test kernel for RIPEMD160
__global__ void test_ripemd160(const HashTest* test_cases, int num_cases, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_cases) return;
    
    const HashTest* test = &test_cases[idx];
    uint8_t hash[20];
    
    // Compute hash
    RIPEMD160_CTX ctx;
    ripemd160_init(&ctx);
    ripemd160_update(&ctx, (const uint8_t*)test->message, test->length);
    ripemd160_final(&ctx, hash);
    
    // Convert expected hex string to bytes
    uint8_t expected[20];
    for (int i = 0; i < 20; i++) {
        char high = test->expected[i*2];
        char low = test->expected[i*2+1];
        high = (high >= 'a') ? (high - 'a' + 10) : (high - '0');
        low = (low >= 'a') ? (low - 'a' + 10) : (low - '0');
        expected[i] = (high << 4) | low;
    }
    
    // Compare results
    bool match = true;
    for (int i = 0; i < 20; i++) {
        if (hash[i] != expected[i]) {
            match = false;
            break;
        }
    }
    
    results[idx] = match;
}

// Test kernel for point multiplication
__global__ void test_point_mult(const PointMultTest* tests, int num_tests, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;
    
    const PointMultTest* test = &tests[idx];
    uint64_t x[4], y[4];
    
    // Perform point multiplication
    scalar_multiply(x, y, test->scalar);
    
    // Convert x and y to bytes for comparison
    uint8_t x_bytes[32], y_bytes[32];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 8; j++) {
            x_bytes[i*8 + j] = (x[3-i] >> (56 - j*8)) & 0xFF;
            y_bytes[i*8 + j] = (y[3-i] >> (56 - j*8)) & 0xFF;
        }
    }
    
    // Compare results
    bool match = true;
    for (int i = 0; i < 32; i++) {
        if (x_bytes[i] != test->expected_x[i] || y_bytes[i] != test->expected_y[i]) {
            match = false;
            break;
        }
    }
    
    results[idx] = match;
}

// Test kernel for address generation
__global__ void test_address_generation(const AddressTest* test_cases, int num_cases, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_cases) return;
    
    const AddressTest* test = &test_cases[idx];
    uint8_t address[35];
    uint8_t isDist;
    
    // Generate address
    generate_address_optimized(test->private_key, address, &isDist);
    
    // Compare with expected address
    bool match = true;
    for (int i = 0; test->expected_address[i] != '\0' && address[i] != '\0'; i++) {
        if (test->expected_address[i] != address[i]) {
            match = false;
            break;
        }
    }
    
    results[idx] = match;
}

// Host function to run all tests
void run_all_tests() {
    // Allocate device memory for test cases and results
    bool* d_results;
    cudaMalloc(&d_results, sizeof(bool) * 32);  // Max test cases
    
    // Run SHA256 tests
    HashTest* d_sha256_tests;
    cudaMalloc(&d_sha256_tests, sizeof(SHA256_TEST_CASES));
    cudaMemcpy(d_sha256_tests, SHA256_TEST_CASES, sizeof(SHA256_TEST_CASES), cudaMemcpyHostToDevice);
    test_sha256<<<1, NUM_SHA256_TEST_CASES>>>(d_sha256_tests, NUM_SHA256_TEST_CASES, d_results);
    
    // Run RIPEMD160 tests
    HashTest* d_ripemd160_tests;
    cudaMalloc(&d_ripemd160_tests, sizeof(RIPEMD160_TEST_CASES));
    cudaMemcpy(d_ripemd160_tests, RIPEMD160_TEST_CASES, sizeof(RIPEMD160_TEST_CASES), cudaMemcpyHostToDevice);
    test_ripemd160<<<1, NUM_RIPEMD160_TEST_CASES>>>(d_ripemd160_tests, NUM_RIPEMD160_TEST_CASES, d_results);
    
    // Run point multiplication tests
    PointMultTest* d_point_tests;
    cudaMalloc(&d_point_tests, sizeof(POINT_MULT_TEST_CASES));
    cudaMemcpy(d_point_tests, POINT_MULT_TEST_CASES, sizeof(POINT_MULT_TEST_CASES), cudaMemcpyHostToDevice);
    test_point_mult<<<1, NUM_POINT_MULT_TEST_CASES>>>(d_point_tests, NUM_POINT_MULT_TEST_CASES, d_results);
    
    // Run address generation tests
    AddressTest* d_address_tests;
    cudaMalloc(&d_address_tests, sizeof(ADDRESS_TEST_CASES));
    cudaMemcpy(d_address_tests, ADDRESS_TEST_CASES, sizeof(ADDRESS_TEST_CASES), cudaMemcpyHostToDevice);
    test_address_generation<<<1, NUM_ADDRESS_TEST_CASES>>>(d_address_tests, NUM_ADDRESS_TEST_CASES, d_results);
    
    // Clean up
    cudaFree(d_results);
    cudaFree(d_sha256_tests);
    cudaFree(d_ripemd160_tests);
    cudaFree(d_point_tests);
    cudaFree(d_address_tests);
}

extern "C" {

// Test functions
__global__ void test_point_operations(const TestCase* test_cases, int num_cases, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_cases) return;

    // Test scalar multiplication
    JPoint result;
    scalar_multiply_optimized(&result, test_cases[idx].private_key);

    // Convert result to affine coordinates
    uint64_t x[4], y[4];
    jacobian_to_affine(x, y, &result);

    // Generate address
    uint8_t address[25];
    generate_address_optimized(x, y, address);

    // Compare with expected address
    bool match = true;
    for (int i = 0; i < 25; i++) {
        if (address[i] != test_cases[idx].expected_address[i]) {
            match = false;
            break;
        }
    }
    results[idx] = match;
}

// Run all point operation tests
void run_point_tests(const TestCase* h_test_cases, int num_cases) {
    // Allocate device memory
    TestCase* d_test_cases;
    bool* d_results;
    cudaMalloc(&d_test_cases, num_cases * sizeof(TestCase));
    cudaMalloc(&d_results, num_cases * sizeof(bool));

    // Copy test cases to device
    cudaMemcpy(d_test_cases, h_test_cases, num_cases * sizeof(TestCase), cudaMemcpyHostToDevice);

    // Launch kernel
    int threadsPerBlock = 256;
    int blocksPerGrid = (num_cases + threadsPerBlock - 1) / threadsPerBlock;
    test_point_operations<<<blocksPerGrid, threadsPerBlock>>>(d_test_cases, num_cases, d_results);

    // Copy results back to host
    bool* h_results = new bool[num_cases];
    cudaMemcpy(h_results, d_results, num_cases * sizeof(bool), cudaMemcpyDeviceToHost);

    // Print results
    for (int i = 0; i < num_cases; i++) {
        printf("Test case %d: %s\n", i, h_results[i] ? "PASSED" : "FAILED");
    }

    // Cleanup
    delete[] h_results;
    cudaFree(d_test_cases);
    cudaFree(d_results);
}

// Run all component tests
bool run_component_tests() {
    printf("Running point operation tests...\n");
    run_point_tests(POINT_OPERATION_TEST_CASES, NUM_POINT_OPERATION_TEST_CASES);
    return true;
}

} // extern "C"
