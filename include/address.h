#ifndef ADDRESS_H
#define ADDRESS_H

#include <stdint.h>

__device__ void pubkey_to_address_kernel(uint64_t *x, uint64_t *y, unsigned char *result);
__device__ int compare_address(const unsigned char *address1, const unsigned char *address2);
__device__ int binary_search_addresses(const unsigned char *target, const unsigned char *addresses, int num_addresses);

#endif // ADDRESS_H