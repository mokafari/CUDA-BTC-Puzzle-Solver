# Bitcoin Puzzle Solver

A CUDA-based tool for solving Bitcoin puzzle transactions by finding private keys corresponding to specific Bitcoin addresses.

## Current Status

The solver is now correctly:
- Generating Bitcoin addresses from private keys using secp256k1
- Handling 256-bit scalar multiplication
- Implementing compressed public key format
- Using optimized SHA256 and RIPEMD160 implementations
- Validating against known test vectors (e.g. private key 1)

## Components

### Core Components
- `kernel.cu`: Main CUDA kernel and host code
- `point_ops_new.cu`: Elliptic curve point operations
- `uint256_ops.cu`: 256-bit integer arithmetic
- `secp256k1_params.cu`: Curve parameters
- `address_new.cu`: Bitcoin address generation
- `sha256.cu`: Optimized SHA256 hash function with shared memory and vectorized operations
- `ripemd160.cu`: Optimized RIPEMD160 hash function with lookup tables and shared memory

### Build & Run Scripts
- `scripts/build.bat`: Builds the CUDA code
- `scripts/run.bat`: Runs the solver
- `scripts/build_and_run.bat`: Combined build and run

## Building

Requirements:
- CUDA Toolkit 11.0 or higher
- Visual Studio 2019 or higher with CUDA support
- Windows 10/11 64-bit

```bash
# Build the project
scripts/build.bat

# Run the solver
scripts/run.bat

# Or build and run in one step
scripts/build_and_run.bat
```

## Performance Optimizations

1. **SHA256 Optimizations**
   - Shared memory implementation for W array
   - Vectorized operations using __byte_perm for endian swapping
   - Unrolled loops with pragma directives
   - Optimized memory access patterns
   - Register optimization for main loop

2. **RIPEMD160 Optimizations**
   - Constant memory lookup tables for K values
   - Shared memory for block data
   - Optimized f-functions with branch elimination
   - Efficient endian conversion using __byte_perm
   - Register optimization for parallel computation

3. **Memory Management**
   - Coalesced memory access patterns
   - Minimized global memory transactions
   - Efficient use of shared memory
   - Register pressure optimization

4. **Future Optimization Opportunities**
   - Multi-GPU support
   - Further kernel occupancy optimization
   - Advanced memory prefetching
   - Warp-level primitives for better parallelism

## Testing

The solver includes several test cases:
1. Generator point multiplication (k=1)
2. Known private key/address pairs
3. Edge cases (k=0, k=n-1)
4. Invalid inputs

## Contributing

Contributions welcome! Areas that need work:
1. Better memory management
2. Multi-GPU support
3. Additional test vectors

## License

MIT License - See LICENSE file for details
