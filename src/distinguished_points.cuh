#ifndef DISTINGUISHED_POINTS_CUH
#define DISTINGUISHED_POINTS_CUH

#include <cuda_runtime.h>
#include <stdint.h>

// Configuration parameters for Distinguished Points method
#define DISTINGUISHED_BITS 16  // Number of trailing zero bits required for a distinguished point
#define CHAIN_LENGTH 10000    // Length of each chain
#define TABLE_SIZE (1 << 20)  // Size of the chain table (1M entries)
#define TABLE_LOAD_FACTOR 0.75f // Maximum load factor before resizing

// Structure to store chain entries
typedef struct {
    uint64_t start_key;    // Starting private key of the chain
    uint64_t end_key;      // Ending private key of the chain
    uint8_t end_address[20]; // Final Bitcoin address of the chain
    bool valid;            // Flag to indicate if the entry is valid
    bool deleted;          // Flag for lazy deletion
} ChainEntry;

// Global variables (device-side)
extern __device__ ChainEntry g_chain_table[TABLE_SIZE];
extern __device__ unsigned int g_num_chains;
extern __device__ unsigned int g_num_collisions;

// Function declarations
__device__ bool is_distinguished(const uint8_t* address);
__device__ int find_chain_entry(const uint8_t* address);
__device__ bool add_chain_entry(uint64_t start_key, uint64_t end_key, const uint8_t* end_address);
__device__ void verify_chain(uint64_t start_key, uint64_t end_key, const uint8_t* target_address, uint64_t* found_key);

// Statistics functions
__device__ float get_table_load_factor();
__device__ unsigned int get_collision_count();
__device__ void increment_collision_count();

// Utility functions
__device__ unsigned int hash_address(const uint8_t* address);
__device__ bool compare_addresses(const uint8_t* addr1, const uint8_t* addr2);

#endif // DISTINGUISHED_POINTS_CUH
