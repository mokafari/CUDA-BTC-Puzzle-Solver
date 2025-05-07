#ifndef POINT_OPS_CUH
#define POINT_OPS_CUH

#include "secp256k1.cuh"

// Point operations on secp256k1
__device__ void point_double(uint64_t *x, uint64_t *y) {
    if (is_zero(y)) {
        memset(x, 0, sizeof(uint64_t) * 4);
        memset(y, 0, sizeof(uint64_t) * 4);
        return;
    }
    
    // s = (3x^2) / (2y)
    uint64_t xx[4], temp[4], s[4];
    uint256_mul(x, x, xx);
    uint256_mul_int(xx, 3, temp);
    uint256_mul_int(y, 2, s);
    mod_inverse(s, s);
    uint256_mul(temp, s, s);
    
    // xr = s^2 - 2x
    uint256_mul(s, s, temp);
    uint256_mul_int(x, 2, x);
    uint256_sub(temp, x, x);
    
    // yr = s(x - xr) - y
    uint256_sub(temp, x, temp);
    uint256_mul(s, temp, temp);
    uint256_sub(temp, y, y);
}

__device__ void point_add(uint64_t *x1, uint64_t *y1, const uint64_t *x2, const uint64_t *y2) {
    if (is_zero(x2) && is_zero(y2)) return;
    if (is_zero(x1) && is_zero(y1)) {
        memcpy(x1, x2, sizeof(uint64_t) * 4);
        memcpy(y1, y2, sizeof(uint64_t) * 4);
        return;
    }
    
    if (uint256_equal(x1, x2)) {
        if (uint256_equal(y1, y2)) {
            point_double(x1, y1);
        } else {
            memset(x1, 0, sizeof(uint64_t) * 4);
            memset(y1, 0, sizeof(uint64_t) * 4);
        }
        return;
    }
    
    // s = (y2 - y1) / (x2 - x1)
    uint64_t dx[4], dy[4], s[4];
    uint256_sub(x2, x1, dx);
    uint256_sub(y2, y1, dy);
    mod_inverse(dx, dx);
    uint256_mul(dy, dx, s);
    
    // xr = s^2 - x1 - x2
    uint64_t temp[4];
    uint256_mul(s, s, temp);
    uint256_sub(temp, x1, temp);
    uint256_sub(temp, x2, x1);
    
    // yr = s(x1 - xr) - y1
    uint256_sub(temp, x1, temp);
    uint256_mul(s, temp, temp);
    uint256_sub(temp, y1, y1);
}

__device__ void scalar_multiply(uint64_t k, uint64_t *x, uint64_t *y) {
    uint64_t rx[4] = {0}, ry[4] = {0};
    uint64_t tx[4], ty[4];
    memcpy(tx, Gx, sizeof(uint64_t) * 4);
    memcpy(ty, Gy, sizeof(uint64_t) * 4);
    
    while (k) {
        if (k & 1) {
            point_add(rx, ry, tx, ty);
        }
        point_double(tx, ty);
        k >>= 1;
    }
    
    memcpy(x, rx, sizeof(uint64_t) * 4);
    memcpy(y, ry, sizeof(uint64_t) * 4);
}

#endif // POINT_OPS_CUH
