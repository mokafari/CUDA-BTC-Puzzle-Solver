#ifndef SHA256_OPTIMIZED_H
#define SHA256_OPTIMIZED_H

#include <stdint.h>
#include <cuda_runtime.h>

// SHA256 constants
#define SHA256_BLOCK_SIZE 64
#define SHA256_DIGEST_SIZE 32
#define SHA256_ROUNDS 64

// Optimized rotation and shift operations using PTX intrinsics
#define ROTR(a,b) __funnelshift_r(a, a, b)
#define SHR(a,b) ((a) >> (b))

// Optimized SHA256 functions using minimal operations
#define CH(x,y,z) ((z) ^ ((x) & ((y) ^ (z))))
#define MAJ(x,y,z) (((x) & (y)) | ((z) & ((x) | (y))))

// Sigma functions optimized for GPU
#define EP0(x) (ROTR(x,2) ^ ROTR(x,13) ^ ROTR(x,22))
#define EP1(x) (ROTR(x,6) ^ ROTR(x,11) ^ ROTR(x,25))
#define SIG0(x) (ROTR(x,7) ^ ROTR(x,18) ^ SHR(x,3))
#define SIG1(x) (ROTR(x,17) ^ ROTR(x,19) ^ SHR(x,10))

// Aligned SHA256 context structure optimized for vectorized operations
typedef struct __align__(16) {
    union {
        uint8_t data[64];     // Input buffer (512 bits)
        uint32_t data_w[16];  // Word view of data
        uint2 data_v[8];      // Vector view of data
    };
    uint32_t datalen;         // Length of input buffer
    uint64_t bitlen;          // Total length in bits
    union {
        uint32_t state[8];    // Hash state (256 bits)
        uint2 state_v[4];     // Vectorized view of state
        uint4 state_v4[2];    // 4-way vectorized view
    };
} SHA256_CTX;

extern "C" {
    // Core SHA256 functions
    __device__ __forceinline__ uint32_t load_bigendian(const uint8_t* ptr);
    __device__ __forceinline__ void store_bigendian(uint8_t* ptr, uint32_t val);
    __device__ __forceinline__ uint2 load_bigendian2(const uint8_t* ptr);
    __device__ __forceinline__ void store_bigendian2(uint8_t* ptr, uint2 val);
    
    // Context management
    __device__ void sha256_init(SHA256_CTX *ctx);
    __device__ void sha256_update(SHA256_CTX *ctx, const uint8_t data[], size_t len);
    __device__ void sha256_final(SHA256_CTX *ctx, uint8_t hash[]);
    __device__ void sha256_transform(SHA256_CTX *ctx, const uint8_t data[]);
    
    // Batch processing
    __device__ void sha256_batch(const uint8_t* inputs[], size_t input_lengths[], 
                                uint8_t* outputs[], int batch_size);
}

#endif // SHA256_OPTIMIZED_H
