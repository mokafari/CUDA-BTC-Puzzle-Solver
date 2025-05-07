#include "uint256_ops.h"
#include "secp256k1_device_params.h"

// Montgomery constants for p (secp256k1 prime)
__device__ __constant__ uint64_t R[4] = {1, 0, 0, 0};  // R = 2^256 mod p
__device__ __constant__ uint64_t R2[4] = {0x1000003d1, 0, 0, 0};  // R^2 mod p
__device__ __constant__ uint64_t N0 = 0xd838091dd2253531ULL;  // -p^(-1) mod 2^64

extern "C" {

__device__ __noinline__ void copy_uint256(uint64_t* dest, const uint64_t* src) {
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        dest[i] = src[i];
    }
}

__device__ __noinline__ bool is_zero_uint256(const uint64_t* a) {
    uint64_t result = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        result |= a[i];
    }
    return result == 0;
}

__device__ __noinline__ void set_zero_uint256(uint64_t* a) {
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        a[i] = 0;
    }
}

__device__ __noinline__ void set_one_uint256(uint64_t* a) {
    a[0] = 1;
    #pragma unroll
    for (int i = 1; i < 4; i++) {
        a[i] = 0;
    }
}

__device__ __noinline__ int compare_uint256(const uint64_t* a, const uint64_t* b) {
    for (int i = 3; i >= 0; i--) {
        if (a[i] > b[i]) return 1;
        if (a[i] < b[i]) return -1;
    }
    return 0;
}

__device__ __noinline__ void add_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p) {
    uint64_t carry = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t sum = a[i] + b[i] + carry;
        carry = (sum < a[i]) || (sum == a[i] && b[i] != 0);
        result[i] = sum;
    }
    
    if (carry || compare_uint256(result, p) >= 0) {
        carry = 0;
        #pragma unroll
        for (int i = 0; i < 4; i++) {
            uint64_t diff = result[i] - p[i] - carry;
            carry = (result[i] < p[i]) || (result[i] == p[i] && carry);
            result[i] = diff;
        }
    }
}

__device__ __noinline__ void sub_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p) {
    uint64_t borrow = 0;
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        uint64_t diff = a[i] - b[i] - borrow;
        borrow = (a[i] < b[i]) || (a[i] == b[i] && borrow);
        result[i] = diff;
    }
    
    if (borrow) {
        uint64_t carry = 0;
        #pragma unroll
        for (int i = 0; i < 4; i++) {
            uint64_t sum = result[i] + p[i] + carry;
            carry = (sum < result[i]) || (sum == result[i] && p[i] != 0);
            result[i] = sum;
        }
    }
}

__device__ __noinline__ void lshift_mod_p_uint256(uint64_t* result, const uint64_t* a, int shift, const uint64_t* p) {
    uint64_t temp[4];
    copy_uint256(temp, a);
    
    while (shift > 0) {
        uint64_t carry = 0;
        #pragma unroll
        for (int i = 0; i < 4; i++) {
            uint64_t t = (temp[i] << 1) | carry;
            carry = temp[i] >> 63;
            temp[i] = t;
        }
        
        if (carry || compare_uint256(temp, p) >= 0) {
            sub_mod_p_uint256(temp, temp, p, p);
        }
        shift--;
    }
    
    copy_uint256(result, temp);
}

__device__ __noinline__ void montgomery_multiply_uint256(uint64_t* result, const uint64_t* a, const uint64_t* b, const uint64_t* p) {
    uint64_t t[8] = {0};
    
    // Compute a * b
    for (int i = 0; i < 4; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 4; j++) {
            uint64_t prod_lo, prod_hi;
            prod_lo = a[i] * b[j];
            prod_hi = __umul64hi(a[i], b[j]);
            
            uint64_t sum = t[i+j] + prod_lo + carry;
            carry = (sum < prod_lo) || (sum == prod_lo && carry);
            t[i+j] = sum;
            
            sum = t[i+j+1] + prod_hi + carry;
            carry = (sum < prod_hi) || (sum == prod_hi && carry);
            t[i+j+1] = sum;
        }
    }
    
    // Montgomery reduction
    for (int i = 0; i < 4; i++) {
        uint64_t m = t[i] * secp256k1_mp[0];
        uint64_t carry = 0;
        
        for (int j = 0; j < 4; j++) {
            uint64_t prod_lo = m * p[j];
            uint64_t prod_hi = __umul64hi(m, p[j]);
            
            uint64_t sum = t[i+j] + prod_lo + carry;
            carry = (sum < prod_lo) || (sum == prod_lo && carry);
            t[i+j] = sum;
            
            if (j < 3) {
                sum = t[i+j+1] + prod_hi + carry;
                carry = (sum < prod_hi) || (sum == prod_hi && carry);
                t[i+j+1] = sum;
            }
        }
    }
    
    // Final reduction
    #pragma unroll
    for (int i = 0; i < 4; i++) {
        result[i] = t[i+4];
    }
    
    if (compare_uint256(result, p) >= 0) {
        sub_mod_p_uint256(result, result, p, p);
    }
}

__device__ __noinline__ void inv_mod_p_uint256(uint64_t* result, const uint64_t* a, const uint64_t* p) {
    uint64_t u[4], v[4], x1[4], x2[4];
    
    // Initialize
    copy_uint256(u, a);
    copy_uint256(v, p);
    set_one_uint256(x1);
    set_zero_uint256(x2);
    
    // While u != 1 and v != 1
    while (!is_zero_uint256(u) && !is_zero_uint256(v)) {
        while ((u[0] & 1) == 0) {  // While u is even
            // u = u/2
            for (int i = 0; i < 3; i++) {
                u[i] = (u[i] >> 1) | (u[i+1] << 63);
            }
            u[3] >>= 1;
            
            // If x1 is odd, add p
            if (x1[0] & 1) {
                add_mod_p_uint256(x1, x1, p, p);
            }
            // x1 = x1/2
            for (int i = 0; i < 3; i++) {
                x1[i] = (x1[i] >> 1) | (x1[i+1] << 63);
            }
            x1[3] >>= 1;
        }
        
        while ((v[0] & 1) == 0) {  // While v is even
            // v = v/2
            for (int i = 0; i < 3; i++) {
                v[i] = (v[i] >> 1) | (v[i+1] << 63);
            }
            v[3] >>= 1;
            
            // If x2 is odd, add p
            if (x2[0] & 1) {
                add_mod_p_uint256(x2, x2, p, p);
            }
            // x2 = x2/2
            for (int i = 0; i < 3; i++) {
                x2[i] = (x2[i] >> 1) | (x2[i+1] << 63);
            }
            x2[3] >>= 1;
        }
        
        if (compare_uint256(u, v) >= 0) {
            sub_mod_p_uint256(u, u, v, p);
            sub_mod_p_uint256(x1, x1, x2, p);
        } else {
            sub_mod_p_uint256(v, v, u, p);
            sub_mod_p_uint256(x2, x2, x1, p);
        }
    }
    
    if (is_zero_uint256(u)) {
        copy_uint256(result, x2);
    } else {
        copy_uint256(result, x1);
    }
}

} // extern "C"