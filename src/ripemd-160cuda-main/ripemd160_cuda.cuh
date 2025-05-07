#ifndef RIPEMD160_CUDA_H
#define RIPEMD160_CUDA_H

#include <stdint.h>

// Function declarations
__device__ void compress(uint32_t* MDbuf, uint32_t* X);
__global__ void ripemd160_gpu(const uint8_t* msg, uint32_t msg_len, uint8_t* hash);

#endif // RIPEMD160_CUDA_H
