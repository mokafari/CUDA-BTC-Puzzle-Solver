#ifndef POINT_OPS_OPTIMIZED_CUH
#define POINT_OPS_OPTIMIZED_CUH

#include <cuda_runtime.h>
#include <stdint.h>

// Constants for secp256k1
__constant__ uint64_t P[4];  // Prime modulus
__constant__ uint64_t N[4];  // Group order
__constant__ uint64_t G_X[4];  // Generator x coordinate
__constant__ uint64_t G_Y[4];  // Generator y coordinate
__constant__ uint64_t BETA[4];  // Endomorphism constant

// Point structures
struct JPoint {  // Jacobian coordinates
    uint64_t X[4];
    uint64_t Y[4];
    uint64_t Z[4];
};

struct APoint {  // Affine coordinates
    uint64_t x[4];
    uint64_t y[4];
};

// Field operations
__device__ void field_add(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ void field_subtract(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ void field_multiply(uint64_t* result, const uint64_t* a, const uint64_t* b);
__device__ void field_square(uint64_t* result, const uint64_t* a);
__device__ void field_inverse(uint64_t* result, const uint64_t* a);
__device__ void field_negate(uint64_t* result, const uint64_t* a);

// Point operations
__device__ void point_set_infinity(JPoint* p);
__device__ bool point_is_at_infinity(const JPoint* p);
__device__ void point_double(JPoint* p);
__device__ void point_add_mixed(JPoint* result, const APoint* p);
__device__ void point_add(JPoint* result, const JPoint* p1, const JPoint* p2);
__device__ void affine_to_jacobian(JPoint* result, const uint64_t* x, const uint64_t* y);
__device__ void jacobian_to_affine(uint64_t* x, uint64_t* y, const JPoint* p);

// Scalar multiplication
__device__ void scalar_multiply(uint64_t* x, uint64_t* y, const uint64_t* k);
__device__ void scalar_multiply_endomorphism(uint64_t* x, uint64_t* y, const uint64_t* k);

// Batch operations
__device__ void batch_inversion(uint64_t* results, const uint64_t* inputs, int count);

// Helper functions
__device__ void set_zero_uint256(uint64_t* x);
__device__ void set_one_uint256(uint64_t* x);
__device__ bool is_zero_uint256(const uint64_t* x);
__device__ void copy_uint256(uint64_t* dst, const uint64_t* src);

#endif // POINT_OPS_OPTIMIZED_CUH
