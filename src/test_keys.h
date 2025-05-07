#ifndef TEST_KEYS_H
#define TEST_KEYS_H

// Test case 1: Known private key and its corresponding address
// Private key: 1
// Public key (uncompressed):
// 04 79BE667E F9DCBBAC 55A06295 CE870B07 029BFCDB 2DCE28D9 59F2815B 16F81798
//    483ADA77 26A3C465 5DA4FBFC 0E1108A8 FD17B448 A6855419 9C47D08F FB10D4B8
// Address: 1EHNa6Q4Jz2uvNExL497mE43ikXhwF6kZm
struct TestCase {
    uint64_t private_key[4];  // 256-bit private key
    uint8_t address[20];      // 160-bit address (RIPEMD160(SHA256(pubkey)))
    uint8_t pubkey_x[32];     // Expected public key X coordinate
    uint8_t pubkey_y[32];     // Expected public key Y coordinate
};

// Initialize test cases
static const TestCase TEST_CASES[] = {
    // Test Case 1 - Private key: 1
    {
        // Private key: 1 (simplest possible key)
        {0x1ULL, 0x0ULL, 0x0ULL, 0x0ULL},
        
        // Address: 1EHNa6Q4Jz2uvNExL497mE43ikXhwF6kZm
        {
            0x91, 0xb2, 0x4d, 0x0b, 0x1a, 0x71, 0x73, 0x8e,
            0x51, 0x36, 0xc6, 0x84, 0xe3, 0x09, 0x1d, 0xb2,
            0x89, 0x9b, 0x35, 0x3a
        },
        
        // Public key X coordinate
        {
            0x79, 0xBE, 0x66, 0x7E, 0xF9, 0xDC, 0xBB, 0xAC,
            0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07,
            0x02, 0x9B, 0xFC, 0xDB, 0x2D, 0xCE, 0x28, 0xD9,
            0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98
        },
        
        // Public key Y coordinate
        {
            0x48, 0x3A, 0xDA, 0x77, 0x26, 0xA3, 0xC4, 0x65,
            0x5D, 0xA4, 0xFB, 0xFC, 0x0E, 0x11, 0x08, 0xA8,
            0xFD, 0x17, 0xB4, 0x48, 0xA6, 0x85, 0x54, 0x19,
            0x9C, 0x47, 0xD0, 0x8F, 0xFB, 0x10, 0xD4, 0xB8
        }
    }
};

#define NUM_TEST_CASES (sizeof(TEST_CASES) / sizeof(TestCase))

#endif // TEST_KEYS_H
