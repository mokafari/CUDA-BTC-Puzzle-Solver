#pragma once

#include "test_suite.cuh"

// Modular arithmetic test vectors
const ModArithTestVector MOD_ARITH_VECTORS[] = {
    // Addition test vectors
    {
        {1, 0, 0, 0},
        {2, 0, 0, 0},
        {3, 0, 0, 0},
        "add"
    },
    // Subtraction test vectors
    {
        {3, 0, 0, 0},
        {1, 0, 0, 0},
        {2, 0, 0, 0},
        "sub"
    },
    // Multiplication test vectors
    {
        {2, 0, 0, 0},
        {3, 0, 0, 0},
        {6, 0, 0, 0},
        "mul"
    }
};

// Point operation test vectors
const PointOpTestVector POINT_OP_VECTORS[] = {
    // k=1 should give generator point
    {
        {1, 0, 0, 0},
        {0x79BE667EF9DCBBAC, 0x55A06295CE870B07, 0x029BFCDB2DCE28D9, 0x59F2815B16F81798},
        {0x483ADA7726A3C465, 0x5DA4FBFC0E1108A8, 0xFD17B448A6855419, 0x9C47D08FFB10D4B8}
    },
    // k=2 test vector
    {
        {2, 0, 0, 0},
        {0xC6047F9441ED7D6D, 0x3045406E95C07CD8, 0x5C778E4B8CEF3CA7, 0xABACB9A6D6FB1D01},
        {0x1AE168FEA63DC339, 0xA3C58419466CEAEE, 0x7F8C2B8E7F0F86E7, 0x98E086B454F8E204}
    }
};

// Hash function test vectors
const uint8_t TEST_INPUT_1[] = "abc";
const uint8_t TEST_INPUT_2[] = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";

const HashTestVector HASH_VECTORS[] = {
    // SHA256 test vectors
    {
        TEST_INPUT_1,
        3,
        {0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
         0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c, 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad}
    },
    // RIPEMD160 test vectors
    {
        TEST_INPUT_1,
        3,
        {0x8e, 0xb2, 0x08, 0xf7, 0xe0, 0x5d, 0x98, 0x7a, 0x9b, 0x04, 0x4a, 0x8e, 0x98, 0xc6, 0xb0, 0x87,
         0xf1, 0x5a, 0x0b, 0xfc}
    }
};

// Address generation test vectors
const AddressTestVector ADDRESS_VECTORS[] = {
    // Test vector 1 (private key 1)
    {
        {1, 0, 0, 0},
        "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"
    },
    // Test vector 2 (private key 2)
    {
        {2, 0, 0, 0},
        "1CQh4XbESwh5Wc5YWy4ajhZUBQsmt9YUD7"
    }
};
