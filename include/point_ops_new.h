#ifndef POINT_OPS_NEW_H
#define POINT_OPS_NEW_H

#include <stdint.h>
#include "cuda_base_types.h"
#include "secp256k1_params.h"

// Point operations
#ifdef __cplusplus
extern "C" {
#endif

__device__ bool validate_scalar(const uint64_t* scalar);
__device__ void affine_to_jacobian(JPoint* jP, const uint64_t* x, const uint64_t* y);
__device__ void jacobian_to_affine(uint64_t* x, uint64_t* y, const JPoint* jP);
__device__ void point_double_jacobian(JPoint* P);
__device__ void point_add_jacobian(JPoint* P1, const JPoint* P2);
__device__ void point_negate(JPoint* P);
__device__ bool point_is_at_infinity(const JPoint* P);
__device__ void point_set_infinity(JPoint* P);
__device__ void scalar_multiply(const uint64_t* scalar, uint64_t* x, uint64_t* y);

#ifdef __cplusplus
}
#endif

#endif // POINT_OPS_NEW_H
