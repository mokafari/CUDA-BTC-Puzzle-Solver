#ifndef SECP256K1_PARAMS_H
#define SECP256K1_PARAMS_H

#include <stdint.h>
#include "cuda_base_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Curve parameters
#ifndef SECP256K1_PARAMS_IMPL
__device__ __constant__ extern uint64_t p[4];
__device__ __constant__ extern uint64_t n[4];
__device__ __constant__ extern uint64_t Gx[4];
__device__ __constant__ extern uint64_t Gy[4];
__device__ __constant__ extern uint64_t a[4];
__device__ __constant__ extern JPoint secp256k1_G;
#endif

#ifdef __cplusplus
}
#endif

#endif // SECP256K1_PARAMS_H
