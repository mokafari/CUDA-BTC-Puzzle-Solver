#include "sha256_optimized.cuh"

// SHA-256 constants in constant memory
__constant__ uint32_t sha256_k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

extern "C" {

// Optimized load/store using PTX intrinsics
__device__ __forceinline__ uint32_t load_bigendian(const uint8_t* ptr) {
    uint32_t val;
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(val) : "r"(*(const uint32_t*)ptr));
    return val;
}

__device__ __forceinline__ void store_bigendian(uint8_t* ptr, uint32_t val) {
    asm("prmt.b32 %0, %1, 0, 0x0123;" : "=r"(*(uint32_t*)ptr) : "r"(val));
}

// Vectorized load/store for uint2
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

// Initialize SHA-256 context with vectorized state
__device__ void sha256_init(SHA256_CTX *ctx) {
    ctx->state_v[0] = make_uint2(0x6a09e667, 0xbb67ae85);
    ctx->state_v[1] = make_uint2(0x3c6ef372, 0xa54ff53a);
    ctx->state_v[2] = make_uint2(0x510e527f, 0x9b05688c);
    ctx->state_v[3] = make_uint2(0x1f83d9ab, 0x5be0cd19);
    ctx->datalen = 0;
    ctx->bitlen = 0;
}

// Optimized transform function using vectorized operations
__device__ void sha256_transform(SHA256_CTX *ctx, const uint8_t data[]) {
    uint32_t w[64];
    uint2 state[4];
    
    // Load state using vectorized operations
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        state[i] = ctx->state_v[i];
    }
    
    // Prepare message schedule with vectorized loads
    #pragma unroll
    for (int i = 0; i < 16; i++) {
        w[i] = load_bigendian(&data[i * 4]);
    }
    
    // Message schedule expansion using vectorized operations
    #pragma unroll
    for (int i = 16; i < 64; i++) {
        w[i] = SIG1(w[i-2]) + w[i-7] + SIG0(w[i-15]) + w[i-16];
    }
    
    // Main loop with register optimization
    uint32_t a = state[0].x;
    uint32_t b = state[0].y;
    uint32_t c = state[1].x;
    uint32_t d = state[1].y;
    uint32_t e = state[2].x;
    uint32_t f = state[2].y;
    uint32_t g = state[3].x;
    uint32_t h = state[3].y;
    
    #pragma unroll
    for (int i = 0; i < 64; i++) {
        uint32_t t1 = h + EP1(e) + CH(e,f,g) + sha256_k[i] + w[i];
        uint32_t t2 = EP0(a) + MAJ(a,b,c);
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    
    // Update state using vectorized operations
    ctx->state_v[0].x += a;
    ctx->state_v[0].y += b;
    ctx->state_v[1].x += c;
    ctx->state_v[1].y += d;
    ctx->state_v[2].x += e;
    ctx->state_v[2].y += f;
    ctx->state_v[3].x += g;
    ctx->state_v[3].y += h;
}

// Optimized update function with coalesced memory access
__device__ void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len) {
    for (size_t i = 0; i < len; i++) {
        ctx->data[ctx->datalen] = data[i];
        ctx->datalen++;
        if (ctx->datalen == 64) {
            sha256_transform(ctx, ctx->data);
            ctx->bitlen += 512;
            ctx->datalen = 0;
        }
    }
}

// Optimized final function with vectorized operations
__device__ void sha256_final(SHA256_CTX *ctx, uint8_t hash[]) {
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
        sha256_transform(ctx, ctx->data);
        memset(ctx->data, 0, 56);
    }
    
    // Append length using vectorized operations
    ctx->bitlen += ctx->datalen * 8;
    store_bigendian(&ctx->data[56], ctx->bitlen >> 56);
    store_bigendian(&ctx->data[60], ctx->bitlen & 0xFFFFFFFFULL);
    sha256_transform(ctx, ctx->data);
    
    // Store final hash using vectorized operations
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        store_bigendian2(&hash[i * 8], ctx->state_v[i]);
    }
}

// Batch processing function for multiple hashes
__device__ void sha256_batch(const uint8_t* inputs[], size_t input_lengths[], 
                           uint8_t* outputs[], int batch_size) {
    SHA256_CTX ctx;
    
    for (int i = 0; i < batch_size; i++) {
        sha256_init(&ctx);
        sha256_update(&ctx, inputs[i], input_lengths[i]);
        sha256_final(&ctx, outputs[i]);
    }
}

}
