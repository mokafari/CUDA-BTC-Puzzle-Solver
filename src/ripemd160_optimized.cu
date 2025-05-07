#include "ripemd160_optimized.cuh"

// Optimized load/store using PTX intrinsics
__device__ __forceinline__ uint32_t load_bigendian(const uint8_t* ptr) {
    uint32_t val;
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(val) : "r"(*(const uint32_t*)ptr));
    return val;
}

__device__ __forceinline__ void store_bigendian(uint8_t* ptr, uint32_t val) {
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(*(uint32_t*)ptr) : "r"(val));
}

__device__ __forceinline__ uint2 load_bigendian2(const uint8_t* ptr) {
    uint2 val;
    val.x = load_bigendian(ptr);
    val.y = load_bigendian(ptr + 4);
    return val;
}

__device__ __forceinline__ void store_bigendian2(uint8_t* ptr, uint2 val) {
    store_bigendian(ptr, val.x);
    store_bigendian(ptr + 4, val.y);
}

// Initialize RIPEMD160 context with vectorized state
__device__ void ripemd160_init(RIPEMD160_CTX *ctx) {
    ctx->state[0] = 0x67452301;
    ctx->state[1] = 0xEFCDAB89;
    ctx->state[2] = 0x98BADCFE;
    ctx->state[3] = 0x10325476;
    ctx->state[4] = 0xC3D2E1F0;
    ctx->datalen = 0;
    ctx->bitlen = 0;
}

// Optimized transform function using vectorized operations
__device__ void ripemd160_transform(RIPEMD160_CTX *ctx, const uint8_t data[]) {
    uint32_t a1, b1, c1, d1, e1;  // Left line
    uint32_t a2, b2, c2, d2, e2;  // Right line
    uint32_t t;                   // Temporary value
    uint32_t w[16];              // Message schedule
    
    // Load message block using vectorized operations
    #pragma unroll
    for (int i = 0; i < 8; i++) {
        uint2 v = load_bigendian2(&data[i * 8]);
        w[i * 2] = v.x;
        w[i * 2 + 1] = v.y;
    }
    
    // Initialize working variables
    a1 = ctx->state[0];
    b1 = ctx->state[1];
    c1 = ctx->state[2];
    d1 = ctx->state[3];
    e1 = ctx->state[4];
    
    a2 = a1;
    b2 = b1;
    c2 = c1;
    d2 = d1;
    e2 = e1;
    
    // Main loop with optimized operations
    #pragma unroll
    for (int j = 0; j < 80; j++) {
        int round = j >> 4;
        
        // Left line
        if (round < 1)      t = F1(b1, c1, d1);
        else if (round < 2) t = F2(b1, c1, d1);
        else if (round < 3) t = F3(b1, c1, d1);
        else if (round < 4) t = F4(b1, c1, d1);
        else               t = F5(b1, c1, d1);
        
        t = ROTL(a1 + t + w[r0[j]] + K0[round], s0[j]) + e1;
        a1 = e1;
        e1 = d1;
        d1 = ROTL(c1, 10);
        c1 = b1;
        b1 = t;
        
        // Right line
        if (round < 1)      t = F5(b2, c2, d2);
        else if (round < 2) t = F4(b2, c2, d2);
        else if (round < 3) t = F3(b2, c2, d2);
        else if (round < 4) t = F2(b2, c2, d2);
        else               t = F1(b2, c2, d2);
        
        t = ROTL(a2 + t + w[r1[j]] + K1[round], s1[j]) + e2;
        a2 = e2;
        e2 = d2;
        d2 = ROTL(c2, 10);
        c2 = b2;
        b2 = t;
    }
    
    // Final permutation
    t = ctx->state[1] + c1 + d2;
    ctx->state[1] = ctx->state[2] + d1 + e2;
    ctx->state[2] = ctx->state[3] + e1 + a2;
    ctx->state[3] = ctx->state[4] + a1 + b2;
    ctx->state[4] = ctx->state[0] + b1 + c2;
    ctx->state[0] = t;
}

// Optimized update function with coalesced memory access
__device__ void ripemd160_update(RIPEMD160_CTX *ctx, const uint8_t data[], size_t len) {
    for (size_t i = 0; i < len; i++) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            ripemd160_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

// Optimized final function with vectorized operations
__device__ void ripemd160_final(RIPEMD160_CTX *ctx, uint8_t hash[]) {
    size_t i = ctx->datalen;
    
    if (ctx->datalen < 56) {
        ctx->data[i++] = 0x80;
        while (i < 56) {
            ctx->data[i++] = 0x00;
        }
    } else {
        ctx->data[i++] = 0x80;
        while (i < 64) {
            ctx->data[i++] = 0x00;
        }
        ripemd160_transform(ctx, ctx->data);
        memset(ctx->data, 0, 56);
    }
    
    // Append length using vectorized operations
    ctx->bitlen += ctx->datalen * 8;
    store_bigendian(&ctx->data[56], ctx->bitlen & 0xFFFFFFFFULL);
    store_bigendian(&ctx->data[60], ctx->bitlen >> 32);
    ripemd160_transform(ctx, ctx->data);
    
    // Store final hash using vectorized operations
    #pragma unroll
    for (int i = 0; i < 5; i++) {
        store_bigendian(&hash[i * 4], ctx->state[i]);
    }
}

// Batch processing for multiple hashes
__device__ void ripemd160_batch(const uint8_t* inputs[], size_t input_lengths[], 
                               uint8_t* outputs[], int batch_size) {
    RIPEMD160_CTX ctx;
    
    for (int i = 0; i < batch_size; i++) {
        ripemd160_init(&ctx);
        ripemd160_update(&ctx, inputs[i], input_lengths[i]);
        ripemd160_final(&ctx, outputs[i]);
    }
}

// Benchmark kernel
__global__ void benchmark_ripemd160(uint8_t* inputs, size_t* input_lengths,
                                   uint8_t* outputs, int num_inputs) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_inputs) return;
    
    RIPEMD160_CTX ctx;
    ripemd160_init(&ctx);
    ripemd160_update(&ctx, inputs + idx * RIPEMD160_BLOCK_SIZE, input_lengths[idx]);
    ripemd160_final(&ctx, outputs + idx * RIPEMD160_DIGEST_SIZE);
}
