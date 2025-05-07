#ifndef SECP256K1_NEW_H
#define SECP256K1_NEW_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Curve parameters
__constant__ uint64_t p[4] = {
    0xFFFFFFFEFFFFFC2F, 0xFFFFFFFFFFFFFFFF,
    0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF
};

__constant__ uint64_t n[4] = {
    0xBFD25E8CD0364141, 0xBAAEDCE6AF48A03B,
    0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF
};

__constant__ uint64_t Gx[4] = {
    0x79BE667EF9DCBBAC, 0x55A06295CE870B07,
    0x029BFCDB2DCE28D9, 0x59F2815B16F81798
};

__constant__ uint64_t Gy[4] = {
    0x483ADA7726A3C465, 0x5DA4FBFC0E1108A8,
    0x04E9B8D0E3EF5C2F, 0x2F8BAE4866A08CFE
};

__constant__ uint64_t a[4] = {0, 0, 0, 0};  // a = 0 for secp256k1

#ifdef __cplusplus
}
#endif

#endif // SECP256K1_NEW_H
