#include "test_address_optimized.h"
#include "test_data.h"
#include "point_ops_optimized.h"
#include "address_optimized.h"
#include <stdio.h>
#include <stdint.h>
#include <cuda_runtime.h>

__global__ void test_address_optimized_kernel(const TestCase* test_cases, int num_cases, bool* results) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_cases) return;

    const TestCase* test = &test_cases[idx];
    
    // Generate address using optimized implementation
    uint8_t current_address[25];
    JPoint R;
    
    // Compute public key
    scalar_multiply_optimized(&R, test->private_key);
    
    // Convert to address format
    uint64_t x[4], y[4];
    jacobian_to_affine(x, y, &R);
    
    // Generate address
    generate_address_optimized(current_address, x, y);
    
    // Compare with expected
    bool match = true;
    for (int i = 0; i < 25; i++) {
        if (current_address[i] != test->expected_address[i]) {
            match = false;
            break;
        }
    }
    
    results[idx] = match;
    
    if (!match) {
        printf("Test case %d failed!\n", idx);
        printf("Expected: ");
        for (int i = 0; i < 25; i++) printf("%02x", test->expected_address[i]);
        printf("\nGot:      ");
        for (int i = 0; i < 25; i++) printf("%02x", current_address[i]);
        printf("\n");
    }
}

extern "C" bool run_optimized_address_tests() {
    printf("Running optimized address generation tests...\n");
    
    // Allocate device memory
    TestCase* d_test_cases;
    bool* d_results;
    cudaMalloc(&d_test_cases, sizeof(POINT_OPERATION_TEST_CASES));
    cudaMalloc(&d_results, NUM_POINT_OPERATION_TEST_CASES * sizeof(bool));
    
    // Copy test cases to device
    cudaMemcpy(d_test_cases, POINT_OPERATION_TEST_CASES, sizeof(POINT_OPERATION_TEST_CASES), cudaMemcpyHostToDevice);
    
    // Run tests
    int threads_per_block = 256;
    int blocks = (NUM_POINT_OPERATION_TEST_CASES + threads_per_block - 1) / threads_per_block;
    test_address_optimized_kernel<<<blocks, threads_per_block>>>(d_test_cases, NUM_POINT_OPERATION_TEST_CASES, d_results);
    cudaDeviceSynchronize();
    
    // Get results
    bool* results = new bool[NUM_POINT_OPERATION_TEST_CASES];
    cudaMemcpy(results, d_results, NUM_POINT_OPERATION_TEST_CASES * sizeof(bool), cudaMemcpyDeviceToHost);
    
    // Check results
    bool all_passed = true;
    for (size_t i = 0; i < NUM_POINT_OPERATION_TEST_CASES; i++) {
        if (!results[i]) {
            all_passed = false;
            break;
        }
    }
    
    // Cleanup
    delete[] results;
    cudaFree(d_test_cases);
    cudaFree(d_results);
    
    if (all_passed) {
        printf("All optimized address tests passed!\n");
    } else {
        printf("Some optimized address tests failed!\n");
    }
    
    return all_passed;
}
