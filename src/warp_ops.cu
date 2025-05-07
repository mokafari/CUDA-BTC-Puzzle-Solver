#include <cuda_runtime.h>
#include "warp_ops.h"
#include "uint256_ops.h"

#define WARP_SIZE 32

extern "C" {

// Shared memory for warp-level operations
extern __shared__ uint64_t shared_mem[];

__device__ void warp_reduce_sum(uint64_t* result, const uint64_t* input) {
    uint64_t sum = *input;
    
    #pragma unroll
    for (int offset = 16; offset > 0; offset /= 2) {
        sum += __shfl_down_sync(0xffffffff, sum, offset);
    }
    
    *result = sum;
}

__device__ void warp_scan_inclusive(uint64_t* result, const uint64_t* input) {
    uint64_t value = *input;
    uint32_t lane = threadIdx.x & 31;
    
    #pragma unroll
    for (int offset = 1; offset <= 16; offset *= 2) {
        uint64_t n = __shfl_up_sync(0xffffffff, value, offset);
        if (lane >= offset) value += n;
    }
    
    *result = value;
}

__device__ void warp_broadcast(uint64_t* result, const uint64_t* input, int lane) {
    *result = __shfl_sync(0xffffffff, *input, lane);
}

__device__ void coalesced_load_uint256(uint64_t* dest, const uint64_t* src) {
    uint32_t lane = threadIdx.x & 31;
    if (lane < 4) {
        dest[lane] = src[lane];
    }
}

__device__ void coalesced_store_uint256(uint64_t* dest, const uint64_t* src) {
    uint32_t lane = threadIdx.x & 31;
    if (lane < 4) {
        dest[lane] = src[lane];
    }
}

__device__ void shared_memory_load_uint256(uint64_t* dest, const uint64_t* src) {
    uint32_t lane = threadIdx.x & 31;
    if (lane < 4) {
        dest[lane] = src[lane];
    }
}

__device__ void shared_memory_store_uint256(uint64_t* dest, const uint64_t* src) {
    uint32_t lane = threadIdx.x & 31;
    if (lane < 4) {
        dest[lane] = src[lane];
    }
}

__device__ void warp_mul_mod_p(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p) {
    uint64_t temp[4];
    montgomery_multiply_uint256(temp, a, b, p);
    copy_uint256(result, temp);
}

__device__ void warp_montgomery_multiply(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p) {
    montgomery_multiply_uint256(result, a, b, p);
}

} // extern "C"
