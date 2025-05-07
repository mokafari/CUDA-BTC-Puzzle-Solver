#pragma once

#include <cuda_runtime.h>
#include <stdint.h>

// Basic integer types used throughout the codebase
typedef uint32_t uint32;
typedef uint64_t uint64;

// Structure for 256-bit integers
struct uint256_t {
    uint64_t v[4];  // Little-endian representation
};

// Common type definitions for cryptographic operations
typedef unsigned char byte;
typedef uint32_t word32;
typedef uint64_t word64;

// Hash digest sizes
#define SHA256_DIGEST_SIZE 32
#define RIPEMD160_DIGEST_SIZE 20

// Useful constants
#define BITS_PER_BYTE 8
#define WORD32_BITS 32
#define WORD64_BITS 64

// Helper macros for bit manipulation
#define ROTR32(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define ROTR64(x, n) (((x) >> (n)) | ((x) << (64 - (n))))
#define SHR32(x, n) ((x) >> (n))
#define SHL32(x, n) ((x) << (n))

// Error codes
enum CryptoError {
    CRYPTO_SUCCESS = 0,
    CRYPTO_ERROR_INVALID_ARGUMENT = -1,
    CRYPTO_ERROR_BUFFER_TOO_SMALL = -2,
    CRYPTO_ERROR_INVALID_FORMAT = -3
};
