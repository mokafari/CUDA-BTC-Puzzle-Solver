#include <cuda_runtime.h>
#include "point_ops_optimized.h"
#include "secp256k1_device_params.h"
#include "uint256_ops.h"

// Helper functions for uint256 operations
__device__ void set_zero_uint256(uint64_t* x) {
    for (int i = 0; i < 4; i++) {
        x[i] = 0;
    }
}

__device__ void set_one_uint256(uint64_t* x) {
    x[0] = 1;
    for (int i = 1; i < 4; i++) {
        x[i] = 0;
    }
}

__device__ bool is_zero_uint256(const uint64_t* x) {
    for (int i = 0; i < 4; i++) {
        if (x[i] != 0) return false;
    }
    return true;
}

__device__ void copy_uint256(uint64_t* dst, const uint64_t* src) {
    for (int i = 0; i < 4; i++) {
        dst[i] = src[i];
    }
}

extern "C" {

// Field arithmetic functions
__device__ __noinline__ void field_multiply(uint64_t* result, const uint64_t* a, const uint64_t* b) {
    uint64_t temp[8] = {0};
    
    // Schoolbook multiplication
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            uint64_t product_low, product_high;
            asm("mul.hi.u64 %0, %1, %2;" : "=l"(product_high) : "l"(a[i]), "l"(b[j]));
            asm("mul.lo.u64 %0, %1, %2;" : "=l"(product_low) : "l"(a[i]), "l"(b[j]));
            
            uint64_t k = i + j;
            temp[k] += product_low;
            if (temp[k] < product_low) temp[k + 1]++;
            temp[k + 1] += product_high;
            if (temp[k + 1] < product_high) temp[k + 2]++;
        }
    }
    
    // Reduce modulo secp256k1 prime
    const uint64_t prime[4] = {
        0xFFFFFFFEFFFFFC2FULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL
    };
    
    // First reduction
    for (int i = 7; i >= 4; i--) {
        if (temp[i] != 0) {
            uint64_t carry = 0;
            for (int j = 0; j < 4; j++) {
                uint64_t product_low, product_high;
                asm("mul.hi.u64 %0, %1, %2;" : "=l"(product_high) : "l"(temp[i]), "l"(prime[j]));
                asm("mul.lo.u64 %0, %1, %2;" : "=l"(product_low) : "l"(temp[i]), "l"(prime[j]));
                
                uint64_t sum = temp[i - 4 + j] + product_low + carry;
                carry = (sum < temp[i - 4 + j]) || (sum < product_low) ? 1 : 0;
                temp[i - 4 + j] = sum;
                
                carry += product_high;
            }
        }
    }
    
    // Copy result
    for (int i = 0; i < 4; i++) {
        result[i] = temp[i];
    }
}

__device__ __noinline__ void field_square(uint64_t* result, const uint64_t* a) {
    field_multiply(result, a, a);
}

__device__ __noinline__ void field_subtract(uint64_t* result, const uint64_t* a, const uint64_t* b) {
    const uint64_t prime[4] = {
        0xFFFFFFFEFFFFFC2FULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL
    };
    
    uint64_t borrow = 0;
    for (int i = 0; i < 4; i++) {
        uint64_t diff = a[i] - b[i] - borrow;
        borrow = (a[i] < b[i]) || (a[i] == b[i] && borrow);
        result[i] = diff;
    }
    
    if (borrow) {
        uint64_t carry = 0;
        for (int i = 0; i < 4; i++) {
            uint64_t sum = result[i] + prime[i] + carry;
            carry = (sum < result[i]) || (sum < prime[i]);
            result[i] = sum;
        }
    }
}

__device__ __noinline__ void field_divide(uint64_t* result, const uint64_t* a, const uint64_t* b) {
    // Fermat's little theorem: a/b = a * b^(p-2) mod p
    uint64_t b_inv[4];
    uint64_t temp[4];
    
    // b^(p-2) using square-and-multiply
    const uint64_t p_minus_2[4] = {
        0xFFFFFFFEFFFFFC2DULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL,
        0xFFFFFFFFFFFFFFFFULL
    };
    
    // Initialize b_inv to 1
    b_inv[0] = 1;
    b_inv[1] = b_inv[2] = b_inv[3] = 0;
    
    // Copy b to temp
    for (int i = 0; i < 4; i++) {
        temp[i] = b[i];
    }
    
    // Square and multiply
    for (int i = 255; i >= 0; i--) {
        field_square(b_inv, b_inv);
        int word = i >> 6;
        int bit = i & 63;
        if ((p_minus_2[word] >> bit) & 1) {
            field_multiply(b_inv, b_inv, temp);
        }
    }
    
    // Multiply by a
    field_multiply(result, a, b_inv);
}

// Helper functions for point operations
__device__ __noinline__ void copy_point(JPoint* dest, const JPoint* src) {
    copy_uint256(dest->X, src->X);
    copy_uint256(dest->Y, src->Y);
    copy_uint256(dest->Z, src->Z);
}

__device__ __noinline__ void point_set_infinity(JPoint* P) {
    set_zero_uint256(P->X);
    set_zero_uint256(P->Y);
    set_zero_uint256(P->Z);
}

__device__ __noinline__ bool point_is_at_infinity(const JPoint* P) {
    return is_zero_uint256(P->Z);
}

__device__ __noinline__ void point_double_optimized(JPoint* point) {
    if (point_is_at_infinity(point)) return;
    
    uint64_t A[4], B[4], C[4], D[4];
    
    // A = X1^2
    montgomery_multiply_uint256(A, point->X, point->X, secp256k1_p);
    
    // B = Y1^2
    montgomery_multiply_uint256(B, point->Y, point->Y, secp256k1_p);
    
    // C = B^2
    montgomery_multiply_uint256(C, B, B, secp256k1_p);
    
    // D = 2*((X1 + B)^2 - A - C)
    uint64_t tmp1[4], tmp2[4];
    add_mod_p_uint256(tmp1, point->X, B, secp256k1_p);
    montgomery_multiply_uint256(tmp2, tmp1, tmp1, secp256k1_p);
    sub_mod_p_uint256(tmp1, tmp2, A, secp256k1_p);
    sub_mod_p_uint256(tmp2, tmp1, C, secp256k1_p);
    lshift_mod_p_uint256(D, tmp2, 1, secp256k1_p);
    
    // X3 = D^2 - 2*A
    montgomery_multiply_uint256(tmp1, D, D, secp256k1_p);
    lshift_mod_p_uint256(tmp2, A, 1, secp256k1_p);
    sub_mod_p_uint256(point->X, tmp1, tmp2, secp256k1_p);
    
    // Y3 = D*(A - X3) - 8*C
    sub_mod_p_uint256(tmp1, A, point->X, secp256k1_p);
    montgomery_multiply_uint256(tmp2, D, tmp1, secp256k1_p);
    lshift_mod_p_uint256(tmp1, C, 3, secp256k1_p);
    sub_mod_p_uint256(point->Y, tmp2, tmp1, secp256k1_p);
    
    // Z3 = 2*Y1*Z1
    montgomery_multiply_uint256(tmp1, point->Y, point->Z, secp256k1_p);
    lshift_mod_p_uint256(point->Z, tmp1, 1, secp256k1_p);
}

__device__ __noinline__ void point_add_optimized(JPoint* result, const JPoint* point1, const JPoint* point2) {
    if (point_is_at_infinity(point1)) {
        copy_point(result, point2);
        return;
    }
    if (point_is_at_infinity(point2)) {
        copy_point(result, point1);
        return;
    }
    
    uint64_t U1[4], U2[4], S1[4], S2[4], H[4], r[4];
    uint64_t tmp1[4], tmp2[4], tmp3[4];
    
    // U1 = X1*Z2^2
    montgomery_multiply_uint256(tmp1, point2->Z, point2->Z, secp256k1_p);
    montgomery_multiply_uint256(U1, point1->X, tmp1, secp256k1_p);
    
    // U2 = X2*Z1^2
    montgomery_multiply_uint256(tmp1, point1->Z, point1->Z, secp256k1_p);
    montgomery_multiply_uint256(U2, point2->X, tmp1, secp256k1_p);
    
    // S1 = Y1*Z2^3
    montgomery_multiply_uint256(tmp1, point2->Z, tmp1, secp256k1_p);
    montgomery_multiply_uint256(S1, point1->Y, tmp1, secp256k1_p);
    
    // S2 = Y2*Z1^3
    montgomery_multiply_uint256(tmp1, point1->Z, tmp1, secp256k1_p);
    montgomery_multiply_uint256(S2, point2->Y, tmp1, secp256k1_p);
    
    // H = U2 - U1
    sub_mod_p_uint256(H, U2, U1, secp256k1_p);
    
    // r = S2 - S1
    sub_mod_p_uint256(r, S2, S1, secp256k1_p);
    
    if (is_zero_uint256(H)) {
        if (is_zero_uint256(r)) {
            point_double_optimized(result);
        } else {
            point_set_infinity(result);
        }
        return;
    }
    
    // X3 = r^2 - H^3 - 2*U1*H^2
    montgomery_multiply_uint256(tmp1, r, r, secp256k1_p);
    montgomery_multiply_uint256(tmp2, H, H, secp256k1_p);
    montgomery_multiply_uint256(tmp3, tmp2, H, secp256k1_p);
    sub_mod_p_uint256(result->X, tmp1, tmp3, secp256k1_p);
    montgomery_multiply_uint256(tmp1, U1, tmp2, secp256k1_p);
    lshift_mod_p_uint256(tmp2, tmp1, 1, secp256k1_p);
    sub_mod_p_uint256(result->X, result->X, tmp2, secp256k1_p);
    
    // Y3 = r*(U1*H^2 - X3) - S1*H^3
    montgomery_multiply_uint256(tmp1, U1, tmp2, secp256k1_p);
    sub_mod_p_uint256(tmp2, tmp1, result->X, secp256k1_p);
    montgomery_multiply_uint256(tmp1, r, tmp2, secp256k1_p);
    montgomery_multiply_uint256(tmp2, S1, tmp3, secp256k1_p);
    sub_mod_p_uint256(result->Y, tmp1, tmp2, secp256k1_p);
    
    // Z3 = H*Z1*Z2
    montgomery_multiply_uint256(tmp1, point1->Z, point2->Z, secp256k1_p);
    montgomery_multiply_uint256(result->Z, H, tmp1, secp256k1_p);
}

__device__ __noinline__ void scalar_multiply_optimized(JPoint* result, const uint64_t* scalar) {
    JPoint R;
    point_set_infinity(&R);
    
    // Create a temporary point and initialize it with generator point coordinates
    JPoint temp;
    affine_to_jacobian(&temp, secp256k1_Gx, secp256k1_Gy);
    
    // Double-and-add algorithm with optimizations
    for (int i = 255; i >= 0; i--) {
        int bit = (scalar[i >> 6] >> (i & 0x3F)) & 1;
        
        // Always double
        point_double_optimized(&R);
        
        // Add if bit is 1
        if (bit) {
            point_add_optimized(&R, &R, &temp);
        }
    }
    
    // Copy result
    copy_point(result, &R);
}

__device__ __noinline__ void point_add_mixed_optimized(JPoint* result, const APoint* point) {
    if (point_is_at_infinity(result)) {
        affine_to_jacobian(result, point->x, point->y);
        return;
    }
    
    uint64_t U1[4], S1[4], H[4], r[4];
    uint64_t tmp1[4], tmp2[4], tmp3[4];
    
    // U1 = P->x*Z1^2
    montgomery_multiply_uint256(tmp1, result->Z, result->Z, secp256k1_p);
    montgomery_multiply_uint256(U1, point->x, tmp1, secp256k1_p);
    
    // S1 = P->y*Z1^3
    montgomery_multiply_uint256(tmp1, result->Z, tmp1, secp256k1_p);
    montgomery_multiply_uint256(S1, point->y, tmp1, secp256k1_p);
    
    // H = U1 - X1
    sub_mod_p_uint256(H, U1, result->X, secp256k1_p);
    
    // r = S1 - Y1
    sub_mod_p_uint256(r, S1, result->Y, secp256k1_p);
    
    if (is_zero_uint256(H)) {
        if (is_zero_uint256(r)) {
            point_double_optimized(result);
        } else {
            point_set_infinity(result);
        }
        return;
    }
    
    // X3 = r^2 - H^3 - 2*U1*H^2
    montgomery_multiply_uint256(tmp1, r, r, secp256k1_p);
    montgomery_multiply_uint256(tmp2, H, H, secp256k1_p);
    montgomery_multiply_uint256(tmp3, tmp2, H, secp256k1_p);
    sub_mod_p_uint256(result->X, tmp1, tmp3, secp256k1_p);
    montgomery_multiply_uint256(tmp1, U1, tmp2, secp256k1_p);
    lshift_mod_p_uint256(tmp2, tmp1, 1, secp256k1_p);
    sub_mod_p_uint256(result->X, result->X, tmp2, secp256k1_p);
    
    // Y3 = r*(U1*H^2 - X3) - S1*H^3
    montgomery_multiply_uint256(tmp1, U1, tmp2, secp256k1_p);
    sub_mod_p_uint256(tmp2, tmp1, result->X, secp256k1_p);
    montgomery_multiply_uint256(tmp1, r, tmp2, secp256k1_p);
    montgomery_multiply_uint256(tmp2, S1, tmp3, secp256k1_p);
    sub_mod_p_uint256(result->Y, tmp1, tmp2, secp256k1_p);
    
    // Z3 = H*Z1
    montgomery_multiply_uint256(result->Z, H, result->Z, secp256k1_p);
}

__device__ __noinline__ void point_multiply_endomorphism(JPoint* result, const uint64_t* scalar) {
    uint64_t k1[4], k2[4];
    decompose_scalar(k1, k2, scalar);
    
    JPoint temp1, temp2;
    scalar_multiply_optimized(&temp1, k1);
    scalar_multiply_optimized(&temp2, k2);
    point_add_optimized(result, &temp1, &temp2);
}

__device__ __noinline__ void decompose_scalar(uint64_t* k1, uint64_t* k2, const uint64_t* scalar) {
    // Constants for scalar decomposition
    const uint64_t lambda[4] = {
        0x5363AD4CC05C30E0ULL,
        0xA53A0E2D91223078ULL,
        0xD8AC22C8C5AF8EE7ULL,
        0x8E38E38E38E38E38ULL
    };
    
    // Temporary variables
    uint64_t temp[4], rem[4];
    
    // k1 = k / lambda
    field_divide(k1, scalar, lambda);
    
    // k2 = k - k1 * lambda
    field_multiply(temp, k1, lambda);
    field_subtract(k2, scalar, temp);
}

__device__ __noinline__ void affine_to_jacobian(JPoint* jacobian, const uint64_t* x, const uint64_t* y) {
    copy_uint256(jacobian->X, x);
    copy_uint256(jacobian->Y, y);
    set_one_uint256(jacobian->Z);
}

__device__ __noinline__ void jacobian_to_affine(uint64_t* x, uint64_t* y, const JPoint* jacobian) {
    if (point_is_at_infinity(jacobian)) {
        set_zero_uint256(x);
        set_zero_uint256(y);
        return;
    }
    
    uint64_t z_inv[4], z_inv_squared[4], z_inv_cubed[4];
    
    // z_inv = 1/Z
    inv_mod_p_uint256(z_inv, jacobian->Z, secp256k1_p);
    
    // z_inv_squared = z_inv^2
    montgomery_multiply_uint256(z_inv_squared, z_inv, z_inv, secp256k1_p);
    
    // z_inv_cubed = z_inv_squared * z_inv
    montgomery_multiply_uint256(z_inv_cubed, z_inv_squared, z_inv, secp256k1_p);
    
    // x = X * z_inv_squared
    montgomery_multiply_uint256(x, jacobian->X, z_inv_squared, secp256k1_p);
    
    // y = Y * z_inv_cubed
    montgomery_multiply_uint256(y, jacobian->Y, z_inv_cubed, secp256k1_p);
}

// Endomorphism optimization functions
__device__ __noinline__ void apply_endomorphism(JPoint* R, const JPoint* P) {
    // Apply the endomorphism map (x, y) -> (beta * x, y)
    // where beta is the cube root of 1 mod p
    montgomery_multiply_uint256(R->X, P->X, secp256k1_beta, secp256k1_p);
    copy_uint256(R->Y, P->Y);
    copy_uint256(R->Z, P->Z);
}

__device__ __noinline__ void scalar_multiply_endomorphism(JPoint* R, const uint64_t* k) {
    uint64_t k1[4], k2[4];
    JPoint Q;
    
    // Decompose k into k1 and k2
    decompose_scalar(k1, k2, k);
    
    // Calculate k1*P
    scalar_multiply_optimized(R, k1);
    
    // Calculate k2*beta(P)
    copy_point(&Q, &secp256k1_G);
    apply_endomorphism(&Q, &Q);
    scalar_multiply_optimized(&Q, k2);
    
    // Add the results
    point_add_optimized(R, R, &Q);
}

__device__ __noinline__ void batch_inversion(uint64_t* results, const uint64_t* inputs, int count) {
    if (count <= 0) return;
    
    // Allocate temporary storage
    uint64_t temps[32][4];  // Fixed size array instead of variable length
    
    // Calculate running products
    copy_uint256(temps[0], inputs);
    for (int i = 1; i < count; i++) {
        montgomery_multiply_uint256(temps[i], temps[i-1], &inputs[i*4], secp256k1_p);
    }
    
    // Calculate inverse of final product
    uint64_t acc[4];
    inv_mod_p_uint256(acc, temps[count-1], secp256k1_p);
    
    // Calculate individual inverses
    for (int i = count-1; i > 0; i--) {
        montgomery_multiply_uint256(&results[i*4], acc, temps[i-1], secp256k1_p);
        montgomery_multiply_uint256(acc, acc, &inputs[i*4], secp256k1_p);
    }
    copy_uint256(&results[0], acc);
}

__device__ __noinline__ void precompute_window(JPoint* table, const JPoint* P, int window_size) {
    int table_size = 1 << window_size;
    
    // First entry is the identity point
    point_set_infinity(&table[0]);
    
    // Second entry is P
    copy_point(&table[1], P);
    
    // Calculate remaining entries
    for (int i = 2; i < table_size; i++) {
        copy_point(&table[i], &table[i-1]);
        point_add_optimized(&table[i], &table[i], P);
    }
}

__device__ __noinline__ void scalar_multiply_window(JPoint* R, const uint64_t* k, const JPoint* table, int window_size) {
    point_set_infinity(R);
    
    // Process scalar bits in windows
    int bits = 256;
    int window_mask = (1 << window_size) - 1;
    
    for (int i = bits - 1; i >= 0; i -= window_size) {
        // Double the result window_size times
        for (int j = 0; j < window_size; j++) {
            point_double_optimized(R);
        }
        
        // Extract the window value
        int pos = i / 64;
        int shift = i % 64;
        int window_val;
        
        if (shift + window_size <= 64) {
            window_val = (k[pos] >> shift) & window_mask;
        } else {
            window_val = (k[pos] >> shift) | ((k[pos+1] << (64 - shift)) & window_mask);
        }
        
        // Add the precomputed point
        if (window_val > 0) {
            point_add_optimized(R, R, &table[window_val]);
        }
    }
}

} // extern "C"
