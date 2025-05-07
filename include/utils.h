#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>

__device__ bool is_zero(const uint64_t *a);
__device__ bool is_negative(const uint64_t *a);
__device__ bool uint256_equal(const uint64_t *a, const uint64_t *b);
__device__ int compare_address(const unsigned char *address1, const unsigned char *address2);
__device__ int binary_search_addresses(const unsigned char *target, const unsigned char *addresses, int num_addresses);

#endif // UTILS_H