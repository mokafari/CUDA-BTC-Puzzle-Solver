#pragma once

#include <stdint.h>

extern "C" {

__device__ void warp_reduce_sum(uint64_t* result, const uint64_t* input);
__device__ void warp_scan_inclusive(uint64_t* result, const uint64_t* input);
__device__ void warp_broadcast(uint64_t* result, const uint64_t* input, int lane);

__device__ void coalesced_load_uint256(uint64_t* dest, const uint64_t* src);
__device__ void coalesced_store_uint256(uint64_t* dest, const uint64_t* src);
__device__ void shared_memory_load_uint256(uint64_t* dest, const uint64_t* src);
__device__ void shared_memory_store_uint256(uint64_t* dest, const uint64_t* src);

} // extern "C"
