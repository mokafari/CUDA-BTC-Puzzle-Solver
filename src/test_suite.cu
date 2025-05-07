#include <stdio.h>
#include <string.h>
#include "sha256_optimized.cuh"
#include "ripemd160_cuda.cuh"
#include "point_ops_optimized.cuh"
#include "address_optimized.h"

// Test vectors for each component
struct TestVector {
    const char* name;
    const char* input;
    const char* expected;
    size_t input_len;
};

// SHA256 test vectors
const TestVector SHA256_VECTORS[] = {
    {"Empty string", "", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0},
    {"Basic string", "abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", 3},
    {"Long string", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", 
     "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", 56}
};

// RIPEMD160 test vectors
const TestVector RIPEMD160_VECTORS[] = {
    {"Empty string", "", "9c1185a5c5e9fc54612808977ee8f548b2258d31", 0},
    {"Basic string", "abc", "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc", 3},
    {"Long string", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
     "12a053384a9c0c88e405a06c27dcf49ada62eb2b", 56}
};

// Point multiplication test vectors (x, y coordinates in hex)
struct PointTestVector {
    uint64_t k[4];
    const char* expected_x;
    const char* expected_y;
};

const PointTestVector POINT_VECTORS[] = {
    // k = 1
    {{1, 0, 0, 0},
     "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798",
     "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8"},
    // k = 2
    {{2, 0, 0, 0},
     "C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5",
     "1AE168FEA63DC339A3C58419466CEAEEF7F632653266D0E1236431A950CFE52A"}
};

// Address test vectors
struct AddressTestVector {
    uint64_t private_key[4];
    const char* expected_address;
};

const AddressTestVector ADDRESS_VECTORS[] = {
    // Private key = 1
    {{1, 0, 0, 0}, "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"},
    // Private key = 2
    {{2, 0, 0, 0}, "1CUNEBjYrCn2y1SdiUMohaKUi4wpP326Lb"}
};

// Helper functions for hex conversion
__device__ __host__ void hex_to_bytes(const char* hex, uint8_t* bytes, size_t len) {
    for (size_t i = 0; i < len; i++) {
        char high = hex[i*2];
        char low = hex[i*2 + 1];
        high = (high >= 'a') ? (high - 'a' + 10) : (high - '0');
        low = (low >= 'a') ? (low - 'a' + 10) : (low - '0');
        bytes[i] = (high << 4) | low;
    }
}

__device__ __host__ void bytes_to_hex(const uint8_t* bytes, char* hex, size_t len) {
    const char HEX_CHARS[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        hex[i*2] = HEX_CHARS[bytes[i] >> 4];
        hex[i*2 + 1] = HEX_CHARS[bytes[i] & 0xF];
    }
    hex[len*2] = '\0';
}

// Test kernels
__global__ void test_sha256_kernel(const TestVector* vectors, bool* results, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;

    uint8_t hash[32];
    uint8_t expected[32];
    
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, (const uint8_t*)vectors[idx].input, vectors[idx].input_len);
    sha256_final(&ctx, hash);
    
    hex_to_bytes(vectors[idx].expected, expected, 32);
    
    bool match = true;
    for (int i = 0; i < 32; i++) {
        if (hash[i] != expected[i]) {
            match = false;
            break;
        }
    }
    results[idx] = match;
}

__global__ void test_ripemd160_kernel(const TestVector* vectors, bool* results, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;

    uint8_t hash[20];
    uint8_t expected[20];
    
    RIPEMD160_CTX ctx;
    RIPEMD160_Init(&ctx);
    RIPEMD160_Update(&ctx, (const uint8_t*)vectors[idx].input, vectors[idx].input_len);
    RIPEMD160_Final(hash, &ctx);
    
    hex_to_bytes(vectors[idx].expected, expected, 20);
    
    bool match = true;
    for (int i = 0; i < 20; i++) {
        if (hash[i] != expected[i]) {
            match = false;
            break;
        }
    }
    results[idx] = match;
}

__global__ void test_point_mult_kernel(const PointTestVector* vectors, bool* results, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;

    uint64_t x[4], y[4];
    uint8_t computed_x[32], computed_y[32];
    uint8_t expected_x[32], expected_y[32];
    
    JPoint result;
    point_set_infinity(&result);
    scalar_multiply(x, y, vectors[idx].k);
    
    // Convert results to bytes
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 8; j++) {
            computed_x[i*8 + j] = (x[3-i] >> (56 - j*8)) & 0xFF;
            computed_y[i*8 + j] = (y[3-i] >> (56 - j*8)) & 0xFF;
        }
    }
    
    hex_to_bytes(vectors[idx].expected_x, expected_x, 32);
    hex_to_bytes(vectors[idx].expected_y, expected_y, 32);
    
    bool match = true;
    for (int i = 0; i < 32; i++) {
        if (computed_x[i] != expected_x[i] || computed_y[i] != expected_y[i]) {
            match = false;
            break;
        }
    }
    results[idx] = match;
}

__global__ void test_address_kernel(const AddressTestVector* vectors, bool* results, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;

    uint8_t address[35];
    uint8_t isDist;
    
    generate_address_optimized(vectors[idx].private_key, address, &isDist);
    
    bool match = true;
    for (int i = 0; vectors[idx].expected_address[i] != '\0' && address[i] != '\0'; i++) {
        if (vectors[idx].expected_address[i] != address[i]) {
            match = false;
            break;
        }
    }
    results[idx] = match;
}

// Main test runner
bool run_test_suite() {
    bool all_passed = true;
    bool* d_results;
    cudaMalloc(&d_results, sizeof(bool) * 10);  // Max test cases
    
    // Test SHA256
    {
        printf("\nTesting SHA256...\n");
        TestVector* d_vectors;
        cudaMalloc(&d_vectors, sizeof(SHA256_VECTORS));
        cudaMemcpy(d_vectors, SHA256_VECTORS, sizeof(SHA256_VECTORS), cudaMemcpyHostToDevice);
        
        test_sha256_kernel<<<1, sizeof(SHA256_VECTORS)/sizeof(TestVector)>>>(d_vectors, d_results, sizeof(SHA256_VECTORS)/sizeof(TestVector));
        
        bool results[10];
        cudaMemcpy(results, d_results, sizeof(bool) * sizeof(SHA256_VECTORS)/sizeof(TestVector), cudaMemcpyDeviceToHost);
        
        for (size_t i = 0; i < sizeof(SHA256_VECTORS)/sizeof(TestVector); i++) {
            printf("Test '%s': %s\n", SHA256_VECTORS[i].name, results[i] ? "PASSED" : "FAILED");
            all_passed &= results[i];
        }
        
        cudaFree(d_vectors);
    }
    
    // Test RIPEMD160
    {
        printf("\nTesting RIPEMD160...\n");
        TestVector* d_vectors;
        cudaMalloc(&d_vectors, sizeof(RIPEMD160_VECTORS));
        cudaMemcpy(d_vectors, RIPEMD160_VECTORS, sizeof(RIPEMD160_VECTORS), cudaMemcpyHostToDevice);
        
        test_ripemd160_kernel<<<1, sizeof(RIPEMD160_VECTORS)/sizeof(TestVector)>>>(d_vectors, d_results, sizeof(RIPEMD160_VECTORS)/sizeof(TestVector));
        
        bool results[10];
        cudaMemcpy(results, d_results, sizeof(bool) * sizeof(RIPEMD160_VECTORS)/sizeof(TestVector), cudaMemcpyDeviceToHost);
        
        for (size_t i = 0; i < sizeof(RIPEMD160_VECTORS)/sizeof(TestVector); i++) {
            printf("Test '%s': %s\n", RIPEMD160_VECTORS[i].name, results[i] ? "PASSED" : "FAILED");
            all_passed &= results[i];
        }
        
        cudaFree(d_vectors);
    }
    
    // Test Point Multiplication
    {
        printf("\nTesting Point Multiplication...\n");
        PointTestVector* d_vectors;
        cudaMalloc(&d_vectors, sizeof(POINT_VECTORS));
        cudaMemcpy(d_vectors, POINT_VECTORS, sizeof(POINT_VECTORS), cudaMemcpyHostToDevice);
        
        test_point_mult_kernel<<<1, sizeof(POINT_VECTORS)/sizeof(PointTestVector)>>>(d_vectors, d_results, sizeof(POINT_VECTORS)/sizeof(PointTestVector));
        
        bool results[10];
        cudaMemcpy(results, d_results, sizeof(bool) * sizeof(POINT_VECTORS)/sizeof(PointTestVector), cudaMemcpyDeviceToHost);
        
        for (size_t i = 0; i < sizeof(POINT_VECTORS)/sizeof(PointTestVector); i++) {
            printf("Test k=%llu: %s\n", POINT_VECTORS[i].k[0], results[i] ? "PASSED" : "FAILED");
            all_passed &= results[i];
        }
        
        cudaFree(d_vectors);
    }
    
    // Test Address Generation
    {
        printf("\nTesting Address Generation...\n");
        AddressTestVector* d_vectors;
        cudaMalloc(&d_vectors, sizeof(ADDRESS_VECTORS));
        cudaMemcpy(d_vectors, ADDRESS_VECTORS, sizeof(ADDRESS_VECTORS), cudaMemcpyHostToDevice);
        
        test_address_kernel<<<1, sizeof(ADDRESS_VECTORS)/sizeof(AddressTestVector)>>>(d_vectors, d_results, sizeof(ADDRESS_VECTORS)/sizeof(AddressTestVector));
        
        bool results[10];
        cudaMemcpy(results, d_results, sizeof(bool) * sizeof(ADDRESS_VECTORS)/sizeof(AddressTestVector), cudaMemcpyDeviceToHost);
        
        for (size_t i = 0; i < sizeof(ADDRESS_VECTORS)/sizeof(AddressTestVector); i++) {
            printf("Test private_key=%llu: %s\n", ADDRESS_VECTORS[i].private_key[0], results[i] ? "PASSED" : "FAILED");
            all_passed &= results[i];
        }
        
        cudaFree(d_vectors);
    }
    
    cudaFree(d_results);
    
    printf("\nOverall test result: %s\n", all_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    return all_passed;
}

int main() {
    return run_test_suite() ? 0 : 1;
}
