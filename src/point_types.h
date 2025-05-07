#pragma once

#include <cuda_runtime.h>
#include <stdint.h>

// Point in affine coordinates (x,y)
struct APoint {
    uint64_t x[4];
    uint64_t y[4];
    bool infinity;
};

// Point in Jacobian coordinates (X:Y:Z)
struct JPoint {
    uint64_t x[4];
    uint64_t y[4];
    uint64_t z[4];
    bool infinity;
};

// Point in projective coordinates (X:Y:Z)
struct PPoint {
    uint64_t x[4];
    uint64_t y[4];
    uint64_t z[4];
    bool infinity;
};

// Constants for secp256k1
__constant__ uint64_t P[4] = {
    0xFFFFFFFEFFFFFC2F, 0xFFFFFFFFFFFFFFFF,
    0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF
};

__constant__ uint64_t N[4] = {
    0xBFD25E8CD0364141, 0xBAAEDCE6AF48A03B,
    0xFFFFFFFFFFFFFFFE, 0xFFFFFFFFFFFFFFFF
};

__constant__ uint64_t G_x[4] = {
    0x79BE667EF9DCBBAC, 0x55A06295CE870B07,
    0x029BFCDB2DCE28D9, 0x59F2815B16F81798
};

__constant__ uint64_t G_y[4] = {
    0x483ADA7726A3C465, 0x5DA4FBFC0E1108A8,
    0xFD17B448A6855419, 0x9C47D08FFB10D4B8
};
