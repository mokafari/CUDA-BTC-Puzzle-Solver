#ifndef CUDA_BASE_TYPES_H
#define CUDA_BASE_TYPES_H

#include <stdint.h>

// Point structure in Jacobian coordinates
typedef struct {
    uint64_t X[4];
    uint64_t Y[4];
    uint64_t Z[4];
} JPoint;

#endif // CUDA_BASE_TYPES_H
