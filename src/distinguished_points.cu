#include "distinguished_points.cuh"
#include "address_optimized.h"
#include <stdio.h>

// Global variables (device-side)
__device__ ChainEntry g_chain_table[TABLE_SIZE];
__device__ unsigned int g_num_chains = 0;
__device__ unsigned int g_num_collisions = 0;

__device__ bool is_distinguished(const uint8_t* address) {
    // Check if the last DISTINGUISHED_BITS bits are zero
    for (int i = 0; i < DISTINGUISHED_BITS / 8; i++) {
        if (address[19 - i] != 0) {
            return false;
        }
    }
    
    int remaining_bits = DISTINGUISHED_BITS % 8;
    if (remaining_bits > 0) {
        uint8_t mask = (1 << remaining_bits) - 1;
        if ((address[19 - (DISTINGUISHED_BITS / 8)] & mask) != 0) {
            return false;
        }
    }
    
    return true;
}

__device__ unsigned int hash_address(const uint8_t* address) {
    unsigned int hash = 5381;
    for (int i = 0; i < 20; i++) {
        hash = ((hash << 5) + hash) + address[i];  // hash * 33 + c
    }
    return hash % TABLE_SIZE;
}

__device__ bool compare_addresses(const uint8_t* addr1, const uint8_t* addr2) {
    for (int i = 0; i < 20; i++) {
        if (addr1[i] != addr2[i]) {
            return false;
        }
    }
    return true;
}

__device__ float get_table_load_factor() {
    return (float)g_num_chains / TABLE_SIZE;
}

__device__ unsigned int get_collision_count() {
    return g_num_collisions;
}

__device__ void increment_collision_count() {
    atomicAdd(&g_num_collisions, 1);
}

__device__ int find_chain_entry(const uint8_t* address) {
    unsigned int index = hash_address(address);
    unsigned int original_index = index;
    
    do {
        if (!g_chain_table[index].valid) {
            return -1;  // Empty slot, entry not found
        }
        
        if (!g_chain_table[index].deleted && 
            compare_addresses(g_chain_table[index].end_address, address)) {
            return index;  // Found matching entry
        }
        
        index = (index + 1) % TABLE_SIZE;  // Linear probing
    } while (index != original_index);  // Stop if we've searched the entire table
    
    return -1;  // Table is full and entry not found
}

__device__ bool add_chain_entry(uint64_t start_key, uint64_t end_key, const uint8_t* end_address) {
    if (get_table_load_factor() >= TABLE_LOAD_FACTOR) {
        return false;  // Table is too full
    }
    
    unsigned int index = hash_address(end_address);
    unsigned int original_index = index;
    
    do {
        // Try to atomically mark slot as valid
        if (atomicCAS((unsigned int*)&g_chain_table[index].valid, 0, 1) == 0) {
            // Successfully claimed this slot
            g_chain_table[index].start_key = start_key;
            g_chain_table[index].end_key = end_key;
            for (int i = 0; i < 20; i++) {
                g_chain_table[index].end_address[i] = end_address[i];
            }
            g_chain_table[index].deleted = false;
            atomicAdd(&g_num_chains, 1);
            return true;
        }
        
        // Slot was taken, check next one
        index = (index + 1) % TABLE_SIZE;
        if (index == original_index) {
            increment_collision_count();
        }
    } while (index != original_index);
    
    return false;  // Table is full
}

__device__ void verify_chain(uint64_t start_key, uint64_t end_key, const uint8_t* target_address, uint64_t* found_key) {
    uint64_t current_key = start_key;
    uint8_t address[20];
    bool isDist;
    
    while (current_key <= end_key) {
        generate_address_optimized(current_key, address, target_address, &isDist);
        
        // Check if we found the target address
        if (compare_addresses(address, target_address)) {
            *found_key = current_key;
            return;
        }
        
        current_key++;
    }
}
