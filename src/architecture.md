# Bitcoin Puzzle Break Architecture

## Core Components

### Base Types and Utilities
- `cuda_base_types.h`: Core type definitions for CUDA implementation
- `types.h`: Common type definitions
- `utils.cu`: Utility functions
- `warp_ops.{h,cu}`: Warp-level operations for optimization

### Mathematical Operations
- `uint256_ops.{h,cu}`: 256-bit integer arithmetic operations
- `secp256k1_params.{h,cu}`: secp256k1 curve parameters
- `secp256k1_device_params.h`: Device-specific curve parameters

### Point Operations
- `point_types.h`: Elliptic curve point type definitions
- `point_ops_optimized.{h,cu}`: Optimized elliptic curve point operations
  - Point addition
  - Point doubling
  - Scalar multiplication
  - Field arithmetic

### Address Generation
- `address_optimized.{h,cu}`: Bitcoin address generation
  - Public key to address conversion
  - Base58Check encoding
  - Address validation

### Cryptographic Functions
- `sha256_optimized.{cu,cuh}`: Optimized SHA256 implementation
- `ripemd160.{h,cu}`: RIPEMD160 implementation
- `CudaSHA256/`: SHA256 CUDA implementation directory

### Core Search Logic
- `kernel.cu`: Main CUDA kernel for private key search
- `main.cu`: Program entry point and control flow
- `benchmark.cu`: Performance benchmarking
- `distinguished_points.{cu,cuh}`: Distinguished points table implementation

### Testing Framework
- `test_kernel.{h,cu}`: Core test framework
- `test_address_optimized.{h,cu}`: Address generation tests
- `test_data.h`: Test vectors and constants
- `test_keys.h`: Known key-address pairs for testing
- `test_suite.h`: Complete test suite
- `test_case_gen.cu`: Test case generation utilities

## Function Mappings

### Point Operations (`point_ops_optimized.cu`)
- `point_add`: Point addition (Jacobian + Affine)
- `point_double`: Point doubling (Jacobian)
- `scalar_multiply`: Basic scalar multiplication
- `scalar_multiply_optimized`: Optimized using endomorphism
- `decompose_scalar`: Scalar decomposition for endomorphism
- Field operations: add, subtract, multiply, square, inverse

### Address Generation (`address_optimized.cu`)
- `generate_address_optimized`: Convert public key to address
- `sha256_device`: SHA256 hash computation
- `ripemd160_device`: RIPEMD160 hash computation
- `encode_base58check`: Base58Check encoding

### Search Kernel (`kernel.cu`)
- `search_private_key`: Main search kernel
- `process_batch`: Batch processing of key ranges
- `validate_key`: Key validation against target

## Memory Layout

### Global Memory
- Target address (constant)
- Distinguished points table
- Batch results

### Shared Memory
- Point operation intermediates
- Hash function state
- Warp-level shared data

### Register Usage
- Field arithmetic operations
- Point coordinates
- Temporary variables

## Optimization Strategies

1. **Arithmetic Optimization**
   - Fast modular arithmetic
   - Endomorphism optimization
   - Warp-level parallelization

2. **Memory Access**
   - Coalesced global memory access
   - Shared memory for frequently accessed data
   - Register-heavy implementation

3. **Parallelization**
   - Grid-stride loops
   - Warp-level primitives
   - Batch processing

4. **Search Space**
   - Distinguished points method
   - Range partitioning
   - Early exit conditions

## Build Configuration

- CUDA architecture: sm_89
- Optimization flags: -O3 --use_fast_math
- Debug options: -DVERBOSE, -g, -G
