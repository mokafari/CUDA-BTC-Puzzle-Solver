#ifndef SHA256_H
#define SHA256_H

#include <stdint.h>

// SHA-256 constants
#define K0  0x428a2f98
#define K1  0x71374491
#define K2  0xb5c0fbcf
#define K3  0xe9b5dba5
#define K4  0x3956c25b
#define K5  0x59f111f1
#define K6  0x923f82a4
#define K7  0xab1c5ed5
#define K8  0xd807aa98
#define K9  0x12835b01
#define K10 0x243185be
#define K11 0x550c7dc3
#define K12 0x72be5d74
#define K13 0x80deb1fe
#define K14 0x9bdc06a7
#define K15 0xc19bf174
#define K16 0xe49b69c1
#define K17 0xefbe4786
#define K18 0x0fc19dc6
#define K19 0x240ca1cc
#define K20 0x2de92c6f
#define K21 0x4a7484aa
#define K22 0x5cb0a9dc
#define K23 0x76f988da
#define K24 0x983e5152
#define K25 0xa831c66d
#define K26 0xb00327c8
#define K27 0xbf597fc7
#define K28 0xc6e00bf3
#define K29 0xd5a79147
#define K30 0x06ca6351
#define K31 0x14292967
#define K32 0x27b70a85
#define K33 0x2e1b2138
#define K34 0x4d2c6dfc
#define K35 0x53380d13
#define K36 0x650a7354
#define K37 0x766a0abb
#define K38 0x81c2c92e
#define K39 0x92722c85
#define K40 0xa2bfe8a1
#define K41 0xa81a664b
#define K42 0xc24b8b70
#define K43 0xc76c51a3
#define K44 0xd192e819
#define K45 0xd6990624
#define K46 0xf40e3585
#define K47 0x106aa070
#define K48 0x19a4c116
#define K49 0x1e376c08
#define K50 0x2748774c
#define K51 0x34b0bcb5
#define K52 0x391c0cb3
#define K53 0x4ed8aa4a
#define K54 0x5b9cca4f
#define K55 0x682e6ff3
#define K56 0x748f82ee
#define K57 0x78a5636f
#define K58 0x84c87814
#define K59 0x8cc70208
#define K60 0x90befffa
#define K61 0xa4506ceb
#define K62 0xbef9a3f7
#define K63 0xc67178f2

__device__ uint32_t Ch(uint32_t x, uint32_t y, uint32_t z);
__device__ uint32_t Maj(uint32_t x, uint32_t y, uint32_t z);
__device__ uint32_t ROTR(uint32_t x, uint32_t n);
__device__ uint32_t Sigma0(uint32_t x);
__device__ uint32_t Sigma1(uint32_t x);
__device__ uint32_t sigma0(uint32_t x);
__device__ uint32_t sigma1(uint32_t x);

__device__ void sha256_transform(uint32_t state[8], const uint32_t block[16]);

#endif // SHA256_H