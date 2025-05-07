#ifndef UINT256_OPS_H
#define UINT256_OPS_H

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Basic arithmetic operations
__device__ __noinline__ void add_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p);
__device__ __noinline__ void sub_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p);
__device__ __noinline__ void mul_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p);
__device__ __noinline__ void lshift_mod_p_uint256(uint64_t* result, const uint64_t* a, int shift, const uint64_t* p);

// Utility functions
__device__ __noinline__ void copy_uint256(uint64_t* dest, const uint64_t* src);
__device__ __noinline__ bool is_zero_uint256(const uint64_t* a);
__device__ __noinline__ void set_zero_uint256(uint64_t* a);
__device__ __noinline__ void set_one_uint256(uint64_t* a);
__device__ __noinline__ int compare_uint256(const uint64_t* a, const uint64_t* b);

// Montgomery arithmetic
__device__ __noinline__ void to_montgomery_uint256(uint64_t* result, const uint64_t* a, const uint64_t* p);
__device__ __noinline__ void from_montgomery_uint256(uint64_t* result, const uint64_t* a, const uint64_t* p);
__device__ __noinline__ void montgomery_multiply_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p);

// Modular inversion
__device__ __noinline__ void inv_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* p);

#ifdef __cplusplus
}
#endif

#endif // UINT256_OPS_H
