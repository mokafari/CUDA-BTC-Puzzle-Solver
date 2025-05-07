#ifndef SECP256K1_PARAMS_H
#define SECP256K1_PARAMS_H

#include <cuda_runtime.h>
#include <stdint.h>
#include "point_ops_optimized.h"

// Function to initialize parameters
void init_secp256k1_params();

#endif // SECP256K1_PARAMS_H
