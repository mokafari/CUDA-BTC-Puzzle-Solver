#ifndef BENCHMARK_CONFIG_H
#define BENCHMARK_CONFIG_H

#include <cuda_runtime.h>
#include <stdint.h>

// Benchmark configuration structure
struct BenchmarkParams {
    uint64_t start_key;
    uint64_t end_key;
    uint64_t range;
    int chain_length;
    int distinguished_bits;
    int table_size;
    int window_size;        // For windowed scalar multiplication
    int batch_size;         // Number of operations per kernel launch
    int num_iterations;     // Number of iterations for each benchmark
    dim3 grid;
    dim3 block;
    bool verify_results;    // Whether to verify results against CPU implementation
    bool verbose;           // Whether to print detailed output
};

// Performance metrics structure
struct BenchmarkMetrics {
    double total_time;          // Total execution time in seconds
    double avg_time;           // Average time per operation
    double ops_per_second;     // Operations per second
    double keys_per_second;    // Keys processed per second
    int collisions;            // Number of hash table collisions (if applicable)
    float load_factor;         // Hash table load factor (if applicable)
    float gpu_utilization;     // GPU utilization percentage
    float memory_throughput;   // Memory throughput in GB/s
};

// Benchmark parameter sets for different test configurations
const BenchmarkParams BENCHMARK_PARAM_SETS[] = {
    // Base configuration
    {
        0x4000000000000000ULL,    // start_key
        0x4000000000010000ULL,    // end_key
        0x10000ULL,               // range
        10000,                    // chain_length
        16,                       // distinguished_bits
        1 << 20,                  // table_size
        4,                        // window_size
        1024,                     // batch_size
        10,                       // num_iterations
        dim3(256, 1, 1),         // grid
        dim3(256, 1, 1),         // block
        true,                     // verify_results
        false                     // verbose
    },
    // High throughput configuration
    {
        0x4000000000000000ULL,    // start_key
        0x4000000000020000ULL,    // end_key
        0x20000ULL,               // range
        20000,                    // chain_length
        18,                       // distinguished_bits
        1 << 21,                  // table_size
        5,                        // window_size
        2048,                     // batch_size
        10,                       // num_iterations
        dim3(512, 1, 1),         // grid
        dim3(256, 1, 1),         // block
        true,                     // verify_results
        false                     // verbose
    },
    // Memory-optimized configuration
    {
        0x4000000000000000ULL,    // start_key
        0x4000000000040000ULL,    // end_key
        0x40000ULL,               // range
        15000,                    // chain_length
        17,                       // distinguished_bits
        1 << 20,                  // table_size
        4,                        // window_size
        1024,                     // batch_size
        10,                       // num_iterations
        dim3(384, 1, 1),         // grid
        dim3(256, 1, 1),         // block
        true,                     // verify_results
        false                     // verbose
    }
};

#define NUM_PARAM_SETS (sizeof(BENCHMARK_PARAM_SETS) / sizeof(BenchmarkParams))

// Debug output control
#ifdef DEBUG
#define DEBUG_PRINT(fmt, ...) printf("[DEBUG] " fmt "\n", ##__VA_ARGS__)
#else
#define DEBUG_PRINT(fmt, ...)
#endif

#endif // BENCHMARK_CONFIG_H
