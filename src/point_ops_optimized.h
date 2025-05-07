#ifndef POINT_OPS_OPTIMIZED_H
#define POINT_OPS_OPTIMIZED_H

#include "cuda_base_types.h"
#include "point_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Point operations
__device__ __noinline__ void point_add_mixed_optimized(JPoint* result, const APoint* point);
__device__ __noinline__ void point_double_optimized(JPoint* result);
__device__ __noinline__ void scalar_multiply_optimized(JPoint* result, const uint64_t* scalar);
__device__ __noinline__ void scalar_multiply_endomorphism(JPoint* result, const uint64_t* scalar);

// Field operations
__device__ __noinline__ void field_multiply(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ __noinline__ void field_square(uint64_t* result, const uint64_t* a);
__device__ __noinline__ void field_subtract(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ __noinline__ void field_divide(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ __noinline__ void field_inverse(uint64_t* result, const uint64_t* a);

// Helper functions
__device__ __noinline__ void copy_point(JPoint* dest, const JPoint* src);
__device__ __noinline__ void set_infinity(JPoint* point);
__device__ __noinline__ bool is_infinity(const JPoint* point);
__device__ __noinline__ void jacobian_to_affine(uint64_t* x, uint64_t* y, const JPoint* point);
__device__ __noinline__ void affine_to_jacobian(JPoint* result, const uint64_t* x, const uint64_t* y);

// Scalar decomposition for endomorphism
__device__ __noinline__ void decompose_scalar(uint64_t* k1, uint64_t* k2, const uint64_t* k);

#ifdef __cplusplus
}
#endif

#endif // POINT_OPS_OPTIMIZED_H
