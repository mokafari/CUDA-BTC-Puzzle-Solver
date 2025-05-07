#ifndef SECP256K1_CUH
#define SECP256K1_CUH

#include <stdint.h>

// Constants for secp256k1
__constant__ uint64_t p[4] = {0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE, 0xFFFFFFFB};  // 2^256 - 2^32 - 2^9 - 2^8 - 2^7 - 2^6 - 2^4 - 1
__constant__ uint64_t n[4] = {0xBFD25E8C, 0xAF48A03B, 0xBAAEDCE6, 0xFFFFFFFE};  // Group order
__constant__ uint64_t Gx[4] = {0x79BE667E, 0xF9DCBBAC, 0x55A06295, 0xCE870B07};  // Generator x
__constant__ uint64_t Gy[4] = {0x483ADA77, 0x26A3C465, 0x5DA4FBFC, 0x0E1108A8};  // Generator y

// Helper functions
__device__ bool is_zero(const uint64_t *a) {
    return (a[0] == 0) && (a[1] == 0) && (a[2] == 0) && (a[3] == 0);
}

__device__ bool is_negative(const uint64_t *a) {
    return (a[3] & 0x8000000000000000ULL) != 0;
}

__device__ bool uint256_equal(const uint64_t *a, const uint64_t *b) {
    return (a[0] == b[0]) && (a[1] == b[1]) && (a[2] == b[2]) && (a[3] == b[3]);
}

// Basic arithmetic operations
__device__ void uint256_add(const uint64_t *a, const uint64_t *b, uint64_t *result) {
    uint64_t carry = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t temp = a[i] + b[i] + carry;
        carry = (temp < a[i]) || (temp == a[i] && carry);
        result[i] = temp;
    }
}

__device__ void uint256_sub(const uint64_t *a, const uint64_t *b, uint64_t *result) {
    uint64_t borrow = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t temp = a[i] - b[i] - borrow;
        borrow = (temp > a[i]) || (temp == a[i] && borrow);
        result[i] = temp;
    }
}

__device__ void uint256_mul_int(const uint64_t *a, uint64_t b, uint64_t *result) {
    uint64_t carry = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t temp = a[i] * b + carry;
        result[i] = temp;
        carry = (temp < a[i] * b) ? 1 : 0;
    }
}

__device__ void uint256_mul(const uint64_t *a, const uint64_t *b, uint64_t *result) {
    uint64_t temp[8] = {0};
    
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 4; j++) {
            uint64_t product = a[i] * b[j];
            uint64_t sum = temp[i + j] + product + carry;
            carry = (sum < product) || ((sum == product) && carry);
            temp[i + j] = sum;
        }
        temp[i + 4] = carry;
    }
    
    // Reduce modulo p
    uint64_t quotient[4] = {0};
    for (int i = 7; i >= 4; i--) {
        quotient[i-4] = temp[i];
    }
    
    uint64_t remainder[4];
    uint64_t quotient_p[4];
    uint256_mul(quotient, p, quotient_p);
    uint256_sub(temp, quotient_p, remainder);
    
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        result[i] = remainder[i];
    }
}

#endif // SECP256K1_CUH
