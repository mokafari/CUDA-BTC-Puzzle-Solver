#include <stdio.h>
#include <string.h>
#include "ripemd160_cuda.cuh"

// Test vectors from the RIPEMD-160 specification
struct TestVector {
    const char* input;
    const char* expected;
};

const TestVector TEST_VECTORS[] = {
    {"", "9c1185a5c5e9fc54612808977ee8f548b2258d31"},
    {"a", "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"},
    {"abc", "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"},
    {"message digest", "5d0689ef49d2fae572b881b123a85ffa21595f36"},
    {"abcdefghijklmnopqrstuvwxyz", "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"},
    {"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "12a053384a9c0c88e405a06c27dcf49ada62eb2b"},
    {"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", "b0e20b6e3116640286ed3a87a5713079b21f5189"},
};

const int NUM_TEST_VECTORS = sizeof(TEST_VECTORS) / sizeof(TestVector);

// Convert hex string to bytes
__host__ void hex_to_bytes(const char* hex, uint8_t* bytes, size_t len) {
    for (size_t i = 0; i < len; i++) {
        char high = hex[i*2];
        char low = hex[i*2 + 1];
        high = (high >= 'a') ? (high - 'a' + 10) : (high - '0');
        low = (low >= 'a') ? (low - 'a' + 10) : (low - '0');
        bytes[i] = (high << 4) | low;
    }
}

// Convert bytes to hex string
__host__ void bytes_to_hex(const uint8_t* bytes, char* hex, size_t len) {
    const char HEX_CHARS[] = "0123456789abcdef";
    for (size_t i = 0; i < len; i++) {
        hex[i*2] = HEX_CHARS[bytes[i] >> 4];
        hex[i*2 + 1] = HEX_CHARS[bytes[i] & 0xF];
    }
    hex[len*2] = '\0';
}

// Test kernel
__global__ void test_ripemd160_kernel(const uint8_t* inputs, const size_t* lengths,
                                     uint8_t* outputs, size_t num_tests) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_tests) return;

    RIPEMD160_CTX ctx;
    RIPEMD160_Init(&ctx);
    RIPEMD160_Update(&ctx, inputs + idx * RIPEMD160_BLOCK_LENGTH, lengths[idx]);
    RIPEMD160_Final(outputs + idx * RIPEMD160_DIGEST_LENGTH, &ctx);
}

int main() {
    // Allocate host memory
    uint8_t* h_inputs = new uint8_t[NUM_TEST_VECTORS * RIPEMD160_BLOCK_LENGTH];
    size_t* h_lengths = new size_t[NUM_TEST_VECTORS];
    uint8_t* h_outputs = new uint8_t[NUM_TEST_VECTORS * RIPEMD160_DIGEST_LENGTH];
    uint8_t* h_expected = new uint8_t[NUM_TEST_VECTORS * RIPEMD160_DIGEST_LENGTH];

    // Prepare test data
    for (int i = 0; i < NUM_TEST_VECTORS; i++) {
        size_t input_len = strlen(TEST_VECTORS[i].input);
        memcpy(h_inputs + i * RIPEMD160_BLOCK_LENGTH, TEST_VECTORS[i].input, input_len);
        h_lengths[i] = input_len;
        hex_to_bytes(TEST_VECTORS[i].expected, h_expected + i * RIPEMD160_DIGEST_LENGTH, RIPEMD160_DIGEST_LENGTH);
    }

    // Allocate device memory
    uint8_t* d_inputs;
    size_t* d_lengths;
    uint8_t* d_outputs;
    cudaMalloc(&d_inputs, NUM_TEST_VECTORS * RIPEMD160_BLOCK_LENGTH);
    cudaMalloc(&d_lengths, NUM_TEST_VECTORS * sizeof(size_t));
    cudaMalloc(&d_outputs, NUM_TEST_VECTORS * RIPEMD160_DIGEST_LENGTH);

    // Copy data to device
    cudaMemcpy(d_inputs, h_inputs, NUM_TEST_VECTORS * RIPEMD160_BLOCK_LENGTH, cudaMemcpyHostToDevice);
    cudaMemcpy(d_lengths, h_lengths, NUM_TEST_VECTORS * sizeof(size_t), cudaMemcpyHostToDevice);

    // Launch kernel
    int threadsPerBlock = 256;
    int blocksPerGrid = (NUM_TEST_VECTORS + threadsPerBlock - 1) / threadsPerBlock;
    test_ripemd160_kernel<<<blocksPerGrid, threadsPerBlock>>>(d_inputs, d_lengths, d_outputs, NUM_TEST_VECTORS);

    // Copy results back
    cudaMemcpy(h_outputs, d_outputs, NUM_TEST_VECTORS * RIPEMD160_DIGEST_LENGTH, cudaMemcpyDeviceToHost);

    // Verify results
    char computed_hex[41];
    char expected_hex[41];
    bool all_passed = true;

    printf("Running RIPEMD-160 tests...\n");
    for (int i = 0; i < NUM_TEST_VECTORS; i++) {
        bytes_to_hex(h_outputs + i * RIPEMD160_DIGEST_LENGTH, computed_hex, RIPEMD160_DIGEST_LENGTH);
        bytes_to_hex(h_expected + i * RIPEMD160_DIGEST_LENGTH, expected_hex, RIPEMD160_DIGEST_LENGTH);

        bool passed = (memcmp(h_outputs + i * RIPEMD160_DIGEST_LENGTH,
                            h_expected + i * RIPEMD160_DIGEST_LENGTH,
                            RIPEMD160_DIGEST_LENGTH) == 0);
        all_passed &= passed;

        printf("Test %d: %s\n", i + 1, passed ? "PASSED" : "FAILED");
        printf("Input: \"%s\"\n", TEST_VECTORS[i].input);
        printf("Expected:  %s\n", expected_hex);
        printf("Computed:  %s\n\n", computed_hex);
    }

    printf("Overall test result: %s\n", all_passed ? "ALL TESTS PASSED" : "SOME TESTS FAILED");

    // Cleanup
    delete[] h_inputs;
    delete[] h_lengths;
    delete[] h_outputs;
    delete[] h_expected;
    cudaFree(d_inputs);
    cudaFree(d_lengths);
    cudaFree(d_outputs);

    return all_passed ? 0 : 1;
}
