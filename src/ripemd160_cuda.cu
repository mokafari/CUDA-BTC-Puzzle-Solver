#include "ripemd160_cuda.cuh"

// Constants in device constant memory
__constant__ uint32_t RIPEMD160_K1[16] = {
    0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E,
    0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000,
    0x8F1BBCDC, 0xA953FD4E, 0x50A28BE6, 0x5C4DD124, 0x6D703EF3,
    0x7A6D76E9
};

__constant__ uint32_t RIPEMD160_K2[16] = {
    0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000,
    0x8F1BBCDC, 0xA953FD4E, 0x50A28BE6, 0x5C4DD124, 0x6D703EF3,
    0x7A6D76E9, 0x00000000, 0x8F1BBCDC, 0xA953FD4E, 0x50A28BE6,
    0x5C4DD124
};

__constant__ uint8_t RIPEMD160_R1[16] = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
};

__constant__ uint8_t RIPEMD160_R2[16] = {
    7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8
};

__constant__ uint8_t RIPEMD160_S1[16] = {
    11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8
};

__constant__ uint8_t RIPEMD160_S2[16] = {
    7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12
};

// Optimized load/store using PTX intrinsics
__device__ __forceinline__ uint32_t load_uint32_le(const uint8_t* ptr) {
    uint32_t val;
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(val) : "r"(*(const uint32_t*)ptr));
    return val;
}

__device__ __forceinline__ void store_uint32_le(uint8_t* ptr, uint32_t val) {
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(*(uint32_t*)ptr) : "r"(val));
}

// RIPEMD-160 round functions
__device__ __forceinline__ uint32_t RIPEMD160_F(uint32_t x, uint32_t y, uint32_t z) {
    return x ^ y ^ z;
}

__device__ __forceinline__ uint32_t RIPEMD160_G(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) | (~x & z);
}

__device__ __forceinline__ uint32_t RIPEMD160_H(uint32_t x, uint32_t y, uint32_t z) {
    return (x | ~y) ^ z;
}

__device__ __forceinline__ uint32_t RIPEMD160_I(uint32_t x, uint32_t y, uint32_t z) {
    return (x & z) | (y & ~z);
}

__device__ __forceinline__ uint32_t RIPEMD160_J(uint32_t x, uint32_t y, uint32_t z) {
    return x ^ (y | ~z);
}

// Rotation helper
__device__ __forceinline__ uint32_t ROTL32(uint32_t x, int n) {
    return (x << n) | (x >> (32 - n));
}

// Initialize RIPEMD-160 context
__device__ void RIPEMD160_Init(RIPEMD160_CTX* ctx) {
    ctx->state[0] = 0x67452301;
    ctx->state[1] = 0xEFCDAB89;
    ctx->state[2] = 0x98BADCFE;
    ctx->state[3] = 0x10325476;
    ctx->state[4] = 0xC3D2E1F0;
    ctx->count = 0;
}

// Process a block of data
__device__ void RIPEMD160_Transform(uint32_t* state, const uint8_t* block) {
    uint32_t a = state[0];
    uint32_t b = state[1];
    uint32_t c = state[2];
    uint32_t d = state[3];
    uint32_t e = state[4];
    uint32_t aa = a;
    uint32_t bb = b;
    uint32_t cc = c;
    uint32_t dd = d;
    uint32_t ee = e;

    uint32_t x[16];
    for (int i = 0; i < 16; i++) {
        x[i] = ((uint32_t)block[i*4]) |
               ((uint32_t)block[i*4+1] << 8) |
               ((uint32_t)block[i*4+2] << 16) |
               ((uint32_t)block[i*4+3] << 24);
    }

    // Round 1
    for (int i = 0; i < 16; i++) {
        uint32_t temp = RIPEMD160_F(b, c, d) + x[i] + RIPEMD160_K1[i];
        temp = ROTL32(temp, RIPEMD160_S1[i]) + e;
        a = e;
        e = d;
        d = ROTL32(c, 10);
        c = b;
        b = temp;
    }

    // Round 2
    for (int i = 0; i < 16; i++) {
        uint32_t temp = RIPEMD160_G(bb, cc, dd) + x[RIPEMD160_R2[i]] + RIPEMD160_K2[i];
        temp = ROTL32(temp, RIPEMD160_S2[i]) + ee;
        aa = ee;
        ee = dd;
        dd = ROTL32(cc, 10);
        cc = bb;
        bb = temp;
    }

    state[0] = a;
    state[1] = b;
    state[2] = c;
    state[3] = d;
    state[4] = e;
}

__device__ void RIPEMD160_Update(RIPEMD160_CTX* ctx, const uint8_t* data, size_t len) {
    size_t have = ctx->count % RIPEMD160_BLOCK_SIZE;
    size_t need = RIPEMD160_BLOCK_SIZE - have;
    
    ctx->count += len;
    
    if (have > 0 && len >= need) {
        memcpy(ctx->buffer + have, data, need);
        RIPEMD160_Transform(ctx->state, ctx->buffer);
        data += need;
        len -= need;
        have = 0;
    }
    
    while (len >= RIPEMD160_BLOCK_SIZE) {
        RIPEMD160_Transform(ctx->state, data);
        data += RIPEMD160_BLOCK_SIZE;
        len -= RIPEMD160_BLOCK_SIZE;
    }
    
    if (len > 0) {
        memcpy(ctx->buffer + have, data, len);
    }
}

__device__ void RIPEMD160_Final(uint8_t* digest, RIPEMD160_CTX* ctx) {
    uint64_t bitcount = ctx->count * 8;
    size_t padlen = (ctx->count % RIPEMD160_BLOCK_SIZE < 56) ? 
                    (56 - ctx->count % RIPEMD160_BLOCK_SIZE) : 
                    (120 - ctx->count % RIPEMD160_BLOCK_SIZE);
    
    // Add padding
    uint8_t pad[128] = {0};
    pad[0] = 0x80;
    RIPEMD160_Update(ctx, pad, padlen);
    
    // Add length
    uint8_t lengthbuf[8];
    for (int i = 0; i < 8; i++) {
        lengthbuf[i] = (bitcount >> (i * 8)) & 0xFF;
    }
    RIPEMD160_Update(ctx, lengthbuf, 8);
    
    // Copy final state to digest
    for (int i = 0; i < 5; i++) {
        digest[i*4] = (ctx->state[i] >> 0) & 0xFF;
        digest[i*4 + 1] = (ctx->state[i] >> 8) & 0xFF;
        digest[i*4 + 2] = (ctx->state[i] >> 16) & 0xFF;
        digest[i*4 + 3] = (ctx->state[i] >> 24) & 0xFF;
    }
}

__device__ void RIPEMD160_Hash(const uint8_t* data, size_t len, uint8_t* digest) {
    RIPEMD160_CTX ctx;
    RIPEMD160_Init(&ctx);
    RIPEMD160_Update(&ctx, data, len);
    RIPEMD160_Final(digest, &ctx);
}

__device__ void RIPEMD160_Batch(const uint8_t* input, size_t data_len, size_t num_items, uint8_t* output) {
    for (size_t idx = 0; idx < num_items; idx++) {
        RIPEMD160_Hash(input + idx * data_len, data_len, output + idx * RIPEMD160_DIGEST_SIZE);
    }
}

// Batch processing kernel
__global__ void RIPEMD160_Transform_Batch(
    const uint8_t* input,
    size_t* input_lengths,
    uint8_t* output,
    size_t num_elements
) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_elements) return;

    RIPEMD160_CTX ctx;
    RIPEMD160_Init(&ctx);
    RIPEMD160_Update(&ctx, input + idx * RIPEMD160_BLOCK_LENGTH, input_lengths[idx]);
    RIPEMD160_Final(output + idx * RIPEMD160_DIGEST_LENGTH, &ctx);
}
