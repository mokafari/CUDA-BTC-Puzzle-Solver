#ifndef ADDRESS_NEW_H
#define ADDRESS_NEW_H

#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

__device__ void pubkey_to_address_kernel(uint8_t* address, const uint64_t* x, const uint64_t* y);
__device__ bool compare_address(const uint8_t* address, const uint8_t* target);

#ifdef __cplusplus
}
#endif

#endif // ADDRESS_NEW_H
