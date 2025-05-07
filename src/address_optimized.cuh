#pragma once

#include <cuda_runtime.h>
#include <stdint.h>
#include "point_types.h"
#include "ripemd160_cuda.cuh"
#include "sha256_cuda.cuh"

#define ADDRESS_SIZE 25
#define BASE58_SIZE 35

extern "C" {
    __device__ void generate_address_optimized_test(const uint64_t private_key[4], uint8_t* address, uint8_t* isDist);
    __device__ void generate_address_optimized_search(uint64_t private_key_scalar, uint8_t* address, const uint8_t* target_address, bool* found);
    __device__ void base58check_encode(const uint8_t* data, size_t data_len, uint8_t* output);
    __device__ bool compare_address(const uint8_t* address);
    __global__ void process_private_keys(const uint64_t* private_keys, uint8_t* addresses, uint8_t* results, int num_keys);
    void set_target_address(const uint8_t* address);
}
