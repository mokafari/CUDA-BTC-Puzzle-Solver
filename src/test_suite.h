#ifndef TEST_SUITE_H
#define TEST_SUITE_H

#include <stdint.h>
#include "test_types.h"

// Test vectors for SHA256
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

// Test vectors for RIPEMD160
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

// Test vectors for address generation
const AddressTest ADDRESS_TEST_CASES[] = {
    {
        {0x1234567890abcdef, 0x1234567890abcdef, 0x1234567890abcdef, 0x1234567890abcdef},
        "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    }
};

// Test case counts
#define NUM_SHA256_TEST_CASES (sizeof(SHA256_TEST_CASES) / sizeof(HashTest))
#define NUM_RIPEMD160_TEST_CASES (sizeof(RIPEMD160_TEST_CASES) / sizeof(HashTest))
#define NUM_ADDRESS_TEST_CASES (sizeof(ADDRESS_TEST_CASES) / sizeof(AddressTest))

// Function declarations for test kernels
__global__ void test_sha256(const HashTest* test_cases, int num_cases, bool* results);
__global__ void test_ripemd160(const HashTest* test_cases, int num_cases, bool* results);
__global__ void test_address_generation(const AddressTest* test_cases, int num_cases, bool* results, uint8_t* generated_addresses);

// Host functions for running tests
void run_sha256_tests();
void run_ripemd160_tests();
void run_address_tests();

#endif // TEST_SUITE_H
