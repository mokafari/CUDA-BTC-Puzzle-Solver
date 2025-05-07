#pragma once

#include <cuda_runtime.h>
#include <stdint.h>

#define RIPEMD160_BLOCK_SIZE 64
#define RIPEMD160_DIGEST_SIZE 20

// RIPEMD-160 context structure
typedef struct {
    uint32_t state[5];
    uint64_t count;
    uint8_t buffer[RIPEMD160_BLOCK_SIZE];
} RIPEMD160_CTX;

// Function declarations
extern "C" {
    __device__ void RIPEMD160_Init(RIPEMD160_CTX* ctx);
    __device__ void RIPEMD160_Update(RIPEMD160_CTX* ctx, const uint8_t* data, size_t len);
    __device__ void RIPEMD160_Final(uint8_t* digest, RIPEMD160_CTX* ctx);
    __device__ void RIPEMD160_Transform(uint32_t* state, const uint8_t* block);
    __device__ void RIPEMD160_Hash(const uint8_t* data, size_t len, uint8_t* digest);
    __device__ void RIPEMD160_Batch(const uint8_t* input, size_t data_len, size_t num_items, uint8_t* output);
}

// RIPEMD-160 constants
__constant__ uint32_t RIPEMD160_K1[16];
__constant__ uint32_t RIPEMD160_K2[16];
__constant__ uint8_t RIPEMD160_R1[16];
__constant__ uint8_t RIPEMD160_R2[16];
__constant__ uint8_t RIPEMD160_S1[16];
__constant__ uint8_t RIPEMD160_S2[16];

// Helper macros for RIPEMD160
#define RIPEMD160_F(x, y, z) ((x) ^ (y) ^ (z))
#define RIPEMD160_G(x, y, z) (((x) & (y)) | (~(x) & (z)))
#define RIPEMD160_H(x, y, z) (((x) | ~(y)) ^ (z))
#define RIPEMD160_I(x, y, z) (((x) & (z)) | ((y) & ~(z)))
#define RIPEMD160_J(x, y, z) ((x) ^ ((y) | ~(z)))

#define ROTL32(x, n) (((x) << (n)) | ((x) >> (32 - (n))))
