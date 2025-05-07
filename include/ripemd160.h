#ifndef RIPEMD160_H
#define RIPEMD160_H

#include <stdint.h>

__device__ uint32_t f(int j, uint32_t x, uint32_t y, uint32_t z);
__device__ uint32_t K_ripemd(int j);
__device__ uint32_t K_prime(int j);
__device__ uint32_t rotr_ripemd160(uint32_t x, int n);
__device__ void ripemd160_transform(uint32_t state[5], const uint32_t block[16]);

#endif // RIPEMD160_H