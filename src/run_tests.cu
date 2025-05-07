#include <stdio.h>
#include <cuda_runtime.h>
#include "test_address_optimized.h"

int main() {
    printf("Starting test suite...\n\n");
    
    // Initialize CUDA
    cudaFree(0);  // Force CUDA context initialization
    
    // Run optimized address generation tests
    printf("\n=== Testing Optimized Address Generation ===\n");
    bool address_tests_passed = run_optimized_address_tests();
    
    // Print final results
    printf("\n=== Test Suite Summary ===\n");
    printf("Optimized Address Tests: %s\n", address_tests_passed ? "PASSED" : "FAILED");
    
    bool all_passed = address_tests_passed;
    printf("\nOverall Test Result: %s\n", all_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    
    return all_passed ? 0 : 1;
}
