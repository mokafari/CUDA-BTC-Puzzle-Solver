#ifndef ADDRESS_OPTIMIZED_H
#define ADDRESS_OPTIMIZED_H

#include "cuda_base_types.h"
#include "point_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Global variables
extern __device__ volatile bool found_key;
extern __device__ uint8_t target_address[25];

// Address generation functions
__device__ void generate_address_optimized(const uint64_t* x, const uint64_t* y, uint8_t* address);
__device__ bool check_address(const uint8_t* address);

// Hash functions
__device__ void sha256_device(const uint8_t* input, size_t len, uint8_t* output);
__device__ void ripemd160_device(const uint8_t* input, size_t len, uint8_t* output);

// Host functions
void set_target_address(const uint8_t* address);

#ifdef __cplusplus
}
#endif

#endif // ADDRESS_OPTIMIZED_H
