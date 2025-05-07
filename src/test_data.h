#ifndef TEST_DATA_H
#define TEST_DATA_H

#include "test_types.h"

// SHA256 test vectors
const HashTest SHA256_TEST_CASES[] = {
    {
        "", // Empty string
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        0
    },
    {
        "abc",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        3
    },
    {
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
        56
    }
};

// RIPEMD160 test vectors
const HashTest RIPEMD160_TEST_CASES[] = {
    {
        "", // Empty string
        "9c1185a5c5e9fc54612808977ee8f548b2258d31",
        0
    },
    {
        "abc",
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc",
        3
    },
    {
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "12a053384a9c0c88e405a06c27dcf49ada62eb2b",
        56
    }
};

// Address test vectors
const AddressTest ADDRESS_TEST_CASES[] = {
    {
        {0x1234567890abcdef, 0x1234567890abcdef, 0x1234567890abcdef, 0x1234567890abcdef},
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    }
};

#define NUM_SHA256_TEST_CASES (sizeof(SHA256_TEST_CASES) / sizeof(HashTest))
#define NUM_RIPEMD160_TEST_CASES (sizeof(RIPEMD160_TEST_CASES) / sizeof(HashTest))
#define NUM_ADDRESS_TEST_CASES (sizeof(ADDRESS_TEST_CASES) / sizeof(AddressTest))

#endif // TEST_DATA_H
