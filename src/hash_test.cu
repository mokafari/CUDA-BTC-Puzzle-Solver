#include <cuda_runtime.h>
#include <stdio.h>
#include <string.h>
#include "sha256_optimized.cuh"
#include "ripemd160_optimized.cuh"

// Test vectors from the official specifications
struct TestVector {
    const char* input;
    const char* sha256;
    const char* ripemd160;
};

TestVector test_vectors[] = {
    {
        "", // Empty string
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "9c1185a5c5e9fc54612808977ee8f548b2258d31"
    },
    {
        "abc",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"
    },
    {
        "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
        "12a053384a9c0c88e405a06c27dcf49ada62eb2b"
    }
};

// Helper function to convert hex string to bytes
void hex_to_bytes(const char* hex, uint8_t* bytes, size_t len) {
    for (size_t i = 0; i < len; i++) {
        sscanf(hex + i*2, "%2hhx", &bytes[i]);
    }
}

// Helper function to convert bytes to hex string
void bytes_to_hex(const uint8_t* bytes, char* hex, size_t len) {
    for (size_t i = 0; i < len; i++) {
        sprintf(hex + i*2, "%02x", bytes[i]);
    }
    hex[len*2] = '\0';
}

// Test kernels
__global__ void test_sha256_kernel(const uint8_t* inputs, size_t* input_lengths,
                                  uint8_t* outputs, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;
    
    SHA256_CTX ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, inputs + idx * SHA256_BLOCK_SIZE, input_lengths[idx]);
    sha256_final(&ctx, outputs + idx * SHA256_DIGEST_SIZE);
}

__global__ void test_ripemd160_kernel(const uint8_t* inputs, size_t* input_lengths,
                                     uint8_t* outputs, int num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;
    
    RIPEMD160_CTX ctx;
    ripemd160_init(&ctx);
    ripemd160_update(&ctx, inputs + idx * RIPEMD160_BLOCK_SIZE, input_lengths[idx]);
    ripemd160_final(&ctx, outputs + idx * RIPEMD160_DIGEST_SIZE);
}

// Main test function
bool run_hash_tests() {
    int num_tests = sizeof(test_vectors) / sizeof(TestVector);
    bool all_passed = true;
    
    // Allocate host memory
    size_t max_input_len = 1024;
    uint8_t* h_inputs = (uint8_t*)malloc(num_tests * max_input_len);
    size_t* h_input_lengths = (size_t*)malloc(num_tests * sizeof(size_t));
    uint8_t* h_sha256_outputs = (uint8_t*)malloc(num_tests * SHA256_DIGEST_SIZE);
    uint8_t* h_ripemd160_outputs = (uint8_t*)malloc(num_tests * RIPEMD160_DIGEST_SIZE);
    
    // Prepare test inputs
    for (int i = 0; i < num_tests; i++) {
        size_t len = strlen(test_vectors[i].input);
        memcpy(h_inputs + i * max_input_len, test_vectors[i].input, len);
        h_input_lengths[i] = len;
    }
    
    // Allocate device memory
    uint8_t *d_inputs, *d_sha256_outputs, *d_ripemd160_outputs;
    size_t *d_input_lengths;
    cudaMalloc(&d_inputs, num_tests * max_input_len);
    cudaMalloc(&d_input_lengths, num_tests * sizeof(size_t));
    cudaMalloc(&d_sha256_outputs, num_tests * SHA256_DIGEST_SIZE);
    cudaMalloc(&d_ripemd160_outputs, num_tests * RIPEMD160_DIGEST_SIZE);
    
    // Copy data to device
    cudaMemcpy(d_inputs, h_inputs, num_tests * max_input_len, cudaMemcpyHostToDevice);
    cudaMemcpy(d_input_lengths, h_input_lengths, num_tests * sizeof(size_t), cudaMemcpyHostToDevice);
    
    // Run tests
    test_sha256_kernel<<<1, num_tests>>>(d_inputs, d_input_lengths, d_sha256_outputs, num_tests);
    test_ripemd160_kernel<<<1, num_tests>>>(d_inputs, d_input_lengths, d_ripemd160_outputs, num_tests);
    
    // Copy results back
    cudaMemcpy(h_sha256_outputs, d_sha256_outputs, num_tests * SHA256_DIGEST_SIZE, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ripemd160_outputs, d_ripemd160_outputs, num_tests * RIPEMD160_DIGEST_SIZE, cudaMemcpyDeviceToHost);
    
    // Verify results
    char hex_output[129]; // Large enough for both hash types
    uint8_t expected_hash[64]; // Large enough for both hash types
    
    printf("Running Hash Function Tests\n");
    printf("==========================\n\n");
    
    // Test SHA256
    printf("SHA256 Tests:\n");
    for (int i = 0; i < num_tests; i++) {
        hex_to_bytes(test_vectors[i].sha256, expected_hash, SHA256_DIGEST_SIZE);
        bytes_to_hex(h_sha256_outputs + i * SHA256_DIGEST_SIZE, hex_output, SHA256_DIGEST_SIZE);
        
        bool passed = memcmp(h_sha256_outputs + i * SHA256_DIGEST_SIZE, expected_hash, SHA256_DIGEST_SIZE) == 0;
        all_passed &= passed;
        
        printf("Test %d: %s\n", i + 1, passed ? "PASSED" : "FAILED");
        printf("  Input: %s\n", test_vectors[i].input);
        printf("  Expected: %s\n", test_vectors[i].sha256);
        printf("  Got:      %s\n\n", hex_output);
    }
    
    // Test RIPEMD160
    printf("RIPEMD160 Tests:\n");
    for (int i = 0; i < num_tests; i++) {
        hex_to_bytes(test_vectors[i].ripemd160, expected_hash, RIPEMD160_DIGEST_SIZE);
        bytes_to_hex(h_ripemd160_outputs + i * RIPEMD160_DIGEST_SIZE, hex_output, RIPEMD160_DIGEST_SIZE);
        
        bool passed = memcmp(h_ripemd160_outputs + i * RIPEMD160_DIGEST_SIZE, expected_hash, RIPEMD160_DIGEST_SIZE) == 0;
        all_passed &= passed;
        
        printf("Test %d: %s\n", i + 1, passed ? "PASSED" : "FAILED");
        printf("  Input: %s\n", test_vectors[i].input);
        printf("  Expected: %s\n", test_vectors[i].ripemd160);
        printf("  Got:      %s\n\n", hex_output);
    }
    
    // Cleanup
    cudaFree(d_inputs);
    cudaFree(d_input_lengths);
    cudaFree(d_sha256_outputs);
    cudaFree(d_ripemd160_outputs);
    free(h_inputs);
    free(h_input_lengths);
    free(h_sha256_outputs);
    free(h_ripemd160_outputs);
    
    printf("Test Summary: %s\n", all_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    return all_passed;
}

int main() {
    if (run_hash_tests()) {
        return 0;
    }
    return 1;
}
