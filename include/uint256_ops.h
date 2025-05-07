#ifndef UINT256_OPS_H
#define UINT256_OPS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

__device__ bool add_mod_p(uint64_t *result, const uint64_t *a, const uint64_t *b, const uint64_t *p);
__device__ bool sub_mod_p(uint64_t *result, const uint64_t *a, const uint64_t *b, const uint64_t *p);
__device__ bool mul_mod_p(uint64_t *result, const uint64_t *a, const uint64_t *b, const uint64_t *p);
__device__ void mul64(uint64_t a, uint64_t b, uint64_t* hi, uint64_t* lo);
__device__ bool inv_mod_p(uint64_t *result, const uint64_t *a, const uint64_t *p);
__device__ bool is_zero(const uint64_t *a);
__device__ bool is_negative(const uint64_t *a);
__device__ bool uint256_equal(const uint64_t *a, const uint64_t *b);
__device__ void copy(uint64_t *dst, const uint64_t *src);

#ifdef __cplusplus
}
#endif

#endif // UINT256_OPS_H