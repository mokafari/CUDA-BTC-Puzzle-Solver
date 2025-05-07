#include "utils.h"

__device__ bool is_zero(const uint64_t *a) {
    return (a[0] == 0) && (a[1] == 0) && (a[2] == 0) && (a[3] == 0);
}

__device__ bool is_negative(const uint64_t *a) {
    return (a[3] & 0x8000000000000000ULL) != 0;
}

__device__ bool uint256_equal(const uint64_t *a, const uint64_t *b) {
    return (a[0] == b[0]) && (a[1] == b[1]) && (a[2] == b[2]) && (a[3] == b[3]);
}

__device__ int compare_address(const unsigned char *address1, const unsigned char *address2) {
    for (int i = 0; i < 25; i++) {
        if (address1[i] < address2[i]) return -1;
        if (address1[i] > address2[i]) return 1;
    }
    return 0;
}

__device__ int binary_search_addresses(const unsigned char *target, const unsigned char *addresses, int num_addresses) {
    int low = 0;
    int high = num_addresses - 1;

    while (low <= high) {
        int mid = low + (high - low) / 2;
        int cmp = compare_address(target, &addresses[mid * 25]);

        if (cmp == 0) {
            return mid; // Found
        } else if (cmp < 0) {
            high = mid - 1;
        } else {
            low = mid + 1;
        }
    }

    return -1; // Not found
}