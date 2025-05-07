#ifndef TEST_KERNEL_H
#define TEST_KERNEL_H

#include <cuda_runtime.h>
#include <stdint.h>
#include "test_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Test functions
__global__ void test_point_operations(const TestCase* test_cases, int num_cases, bool* results);
void run_point_tests(const TestCase* h_test_cases, int num_cases);

// Main test runner
bool run_component_tests();

#ifdef __cplusplus
}
#endif

#endif // TEST_KERNEL_H
