#ifndef TEST_TYPES_H
#define TEST_TYPES_H

#include <stdint.h>

// Test case structures
struct HashTest {
    const char* message;
    const char* expected;
    size_t length;
};

struct PointMultTest {
    uint64_t scalar[4];
    uint8_t expected_x[32];
    uint8_t expected_y[32];
};

struct AddressTest {
    uint64_t private_key[4];
    const char* expected_address;
};

struct TestCase {
    union {
        HashTest hash;
        PointMultTest point;
        AddressTest address;
    };
    int type;  // 0 = hash, 1 = point, 2 = address
};

// Test vector declarations
extern const HashTest SHA256_TEST_CASES[];
extern const HashTest RIPEMD160_TEST_CASES[];
extern const PointMultTest POINT_MULT_TEST_CASES[];
extern const AddressTest ADDRESS_TEST_CASES[];

// Test count declarations
extern const int NUM_SHA256_TEST_CASES;
extern const int NUM_RIPEMD160_TEST_CASES;
extern const int NUM_POINT_MULT_TEST_CASES;
extern const int NUM_ADDRESS_TEST_CASES;

#endif // TEST_TYPES_H
