#ifndef TEST_ADDRESS_OPTIMIZED_H
#define TEST_ADDRESS_OPTIMIZED_H

#include <cuda_runtime.h>
#include <stdint.h>
#include "test_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Test functions
__global__ void test_address_generation(const TestCase* test_cases, int num_cases, bool* results);
void run_address_tests();

#ifdef __cplusplus
}
#endif

#endif // TEST_ADDRESS_OPTIMIZED_H
