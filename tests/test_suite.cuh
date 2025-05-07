#pragma once

#include <cuda_runtime.h>
#include <stdio.h>
#include "../src/point_types.h"
#include "../src/sha256_cuda.cuh"
#include "../src/ripemd160_cuda.cuh"
#include "../src/address_optimized.cuh"

// Test result structure
struct TestResult {
    bool passed;
    const char* test_name;
    const char* message;
};

// Test categories
enum TestCategory {
    MODULAR_ARITHMETIC,
    POINT_OPERATIONS,
    HASH_FUNCTIONS,
    ADDRESS_GENERATION,
    PERFORMANCE
};

// Test vectors for each category
struct ModArithTestVector {
    uint64_t a[4];
    uint64_t b[4];
    uint64_t expected[4];
    const char* operation; // "add", "sub", "mul", or "mod"
};

struct PointOpTestVector {
    uint64_t k[4];        // Scalar
    uint64_t expected_x[4]; // Expected x coordinate
    uint64_t expected_y[4]; // Expected y coordinate
};

struct HashTestVector {
    const uint8_t* input;
    size_t input_len;
    uint8_t expected[32]; // Large enough for both SHA256 and RIPEMD160
};

struct AddressTestVector {
    uint64_t private_key[4];
    const char* expected_address;
};

// Test function declarations
__global__ void test_modular_arithmetic(TestResult* results, const ModArithTestVector* vectors, int num_vectors);
__global__ void test_point_operations(TestResult* results, const PointOpTestVector* vectors, int num_vectors);
__global__ void test_hash_functions(TestResult* results, const HashTestVector* vectors, int num_vectors);
__global__ void test_address_generation(TestResult* results, const AddressTestVector* vectors, int num_vectors);

// Performance test declarations
__global__ void benchmark_mod_arithmetic(uint64_t* throughput);
__global__ void benchmark_point_ops(uint64_t* throughput);
__global__ void benchmark_hashing(uint64_t* throughput);
__global__ void benchmark_address_gen(uint64_t* throughput);
