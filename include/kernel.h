#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Kernel configuration constants
#define DEFAULT_GRID_SIZE 65535
#define DEFAULT_BLOCK_SIZE 256
#define DEFAULT_WALKS_PER_THREAD 4

// Kernel function declaration
__global__ void pollards_rho_kernel(
    uint64_t start_k,
    uint64_t *result_k,
    int *found,
    const unsigned char *target_address,
    int num_addresses
);

// Helper functions
__device__ bool is_distinguished(const uint64_t* x, const uint64_t* y);
__device__ void* allocate_memory(size_t size);
__device__ void free_memory(void* ptr);

#ifdef __cplusplus
}
#endif
