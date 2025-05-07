#include "secp256k1_params.h"
#include "secp256k1_device_params.h"

// Initialize curve parameters in Montgomery form
const uint64_t secp256k1_p_init[4] = {
    0xFFFFFFFEFFFFFC2F,
    0xFFFFFFFFFFFFFFFF,
    0xFFFFFFFFFFFFFFFF,
    0x00000000FFFFFFFF
};

const uint64_t secp256k1_n_init[4] = {
    0xBFD25E8CD0364141,
    0xBAAEDCE6AF48A03B,
    0xFFFFFFFFFFFFFFFF,
    0x00000000FFFFFFFF
};

const uint64_t secp256k1_Gx_init[4] = {
    0x59F2815B16F81798,
    0x029BFCDB2DCE28D9,
    0x55A06295CE870B07,
    0x79BE667EF9DCBBAC
};

const uint64_t secp256k1_Gy_init[4] = {
    0x9C47D08FFB10D4B8,
    0xFD17B448A6855419,
    0x5DA4FBFC0E1108A8,
    0x483ADA7726A3C465
};

const uint64_t secp256k1_beta_init[4] = {
    0x719501EE9C4E7B3B,
    0xC1396C28719501EE,
    0x12F58995C1396C28,
    0x7AE96A2B657C0710
};

const uint64_t secp256k1_r2_init[4] = {
    0x000007A2000E90A1,
    0x0000000000000001,
    0x0000000000000000,
    0x0000000000000000
};

const uint64_t secp256k1_mp_init[4] = {
    0x00000001000003D1,
    0x0000000000000000,
    0x0000000000000000,
    0x0000000000000000
};

const uint64_t secp256k1_lambda_init[4] = {
    0x5363AD4CC05C30E0,
    0xA4B1BA7C9E90B3D2,
    0x1B8FAF5F1D0E4E42,
    0x5363AD4CC05C30E0
};

const uint64_t secp256k1_b1_init[4] = {
    0x30C30E0A4B1BA7C9,
    0xE90B3D25363AD4CC,
    0xD0E4E421B8FAF5F1,
    0x05C30E05363AD4CC
};

const uint64_t secp256k1_b2_init[4] = {
    0xCF3CF1F5B4E45836,
    0x16F4C2DAC9C52B33,
    0x2F1B1ADE41705A0E,
    0xFA3CF1FAC9C52B33
};

const uint64_t secp256k1_g1_init[4] = {
    0x55555555555554CD,
    0x5555555555555555,
    0x5555555555555555,
    0x5555555555555555
};

const uint64_t secp256k1_g2_init[4] = {
    0x7FFFFFFFFFFFFE18,
    0x7FFFFFFFFFFFFFFF,
    0x7FFFFFFFFFFFFFFF,
    0x7FFFFFFFFFFFFFFF
};

const JPoint secp256k1_G_init = {
    {0x59F2815B16F81798, 0x029BFCDB2DCE28D9, 0x55A06295CE870B07, 0x79BE667EF9DCBBAC},  // X
    {0x9C47D08FFB10D4B8, 0xFD17B448A6855419, 0x5DA4FBFC0E1108A8, 0x483ADA7726A3C465},  // Y
    {1, 0, 0, 0}  // Z = 1 (affine coordinates)
};

// Copy initialization values to constant memory
void init_secp256k1_params() {
    cudaMemcpyToSymbol(secp256k1_p, secp256k1_p_init, sizeof(secp256k1_p_init));
    cudaMemcpyToSymbol(secp256k1_n, secp256k1_n_init, sizeof(secp256k1_n_init));
    cudaMemcpyToSymbol(secp256k1_Gx, secp256k1_Gx_init, sizeof(secp256k1_Gx_init));
    cudaMemcpyToSymbol(secp256k1_Gy, secp256k1_Gy_init, sizeof(secp256k1_Gy_init));
    cudaMemcpyToSymbol(secp256k1_beta, secp256k1_beta_init, sizeof(secp256k1_beta_init));
    cudaMemcpyToSymbol(secp256k1_r2, secp256k1_r2_init, sizeof(secp256k1_r2_init));
    cudaMemcpyToSymbol(secp256k1_mp, secp256k1_mp_init, sizeof(secp256k1_mp_init));
    cudaMemcpyToSymbol(secp256k1_lambda, secp256k1_lambda_init, sizeof(secp256k1_lambda_init));
    cudaMemcpyToSymbol(secp256k1_b1, secp256k1_b1_init, sizeof(secp256k1_b1_init));
    cudaMemcpyToSymbol(secp256k1_b2, secp256k1_b2_init, sizeof(secp256k1_b2_init));
    cudaMemcpyToSymbol(secp256k1_g1, secp256k1_g1_init, sizeof(secp256k1_g1_init));
    cudaMemcpyToSymbol(secp256k1_g2, secp256k1_g2_init, sizeof(secp256k1_g2_init));
    cudaMemcpyToSymbol(secp256k1_G, &secp256k1_G_init, sizeof(secp256k1_G_init));
}
