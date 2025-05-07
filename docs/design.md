# Bitcoin Puzzle Solver Design Document

## Architecture Overview

The solver is designed as a highly parallel CUDA application that attempts to find Bitcoin private keys by:
1. Generating candidate private keys
2. Computing corresponding public keys using secp256k1
3. Generating Bitcoin addresses
4. Comparing against target address

### Core Components

#### 1. Key Generation and Search (`kernel.cu`)
- Implements Pollard's Rho with Brent's optimization
- Efficient cycle detection
- Range-specific optimizations
- Key features:
  - No hash table dependency
  - Optimized memory usage
  - Thread cooperation
  - Efficient collision detection

#### 2. Point Operations (`point_ops_new.cu`)
- Implements secp256k1 point arithmetic
- Uses Jacobian coordinates for efficiency
- Implements 4-bit windowed scalar multiplication
- Uses mixed coordinate addition
- Key operations:
  - Point addition (mixed coordinates)
  - Point doubling (Jacobian coordinates)
  - Windowed scalar multiplication
  - Point validation
  - Precomputed points table

#### 3. 256-bit Arithmetic (`uint256_ops.cu`)
- Implements big integer operations
- Uses Montgomery arithmetic for efficiency
- Optimized for 64-bit word size
- Key operations:
  - Montgomery multiplication
  - Montgomery squaring
  - Modular addition/subtraction
  - Modular inversion (Fermat's Little Theorem)
  - Constant-time operations

#### 4. Address Generation (`address_optimized.cu`)
- Optimized Bitcoin address generation
- Uses highly efficient hash functions
- Implements compressed public key format
- Key features:
  - Optimized SHA256 implementation
  - Fast RIPEMD160 with lookup tables
  - Minimized memory transfers
  - Efficient state management

#### 5. Hash Functions
- `sha256_cuda.cu`: Optimized SHA256
  - Uses shared memory for state
  - Vectorized operations
  - Unrolled loops
  - Minimized thread divergence
- `ripemd160_cuda.cu`: Fast RIPEMD160
  - Constant memory lookup tables
  - Optimized round functions
  - Efficient memory access
  - Reduced register pressure

### Memory Hierarchy

1. **Global Memory**
   - Private key candidates
   - Results and found keys
   - Large data structures
   - Optimized access patterns

2. **Constant Memory**
   - Curve parameters (G, n, p)
   - Precomputed points table
   - Hash function constants
   - Montgomery constants

3. **Shared Memory**
   - Hash function state
   - Point operation intermediates
   - Work queue management
   - Temporary buffers

4. **Registers**
   - Critical loop variables
   - Intermediate calculations
   - Frequently accessed data
   - Optimized register pressure

### Parallelization Strategy

1. **Grid-level Parallelism**
   - Multiple starting points for Pollard's Rho
   - Independent thread trajectories
   - Load balancing across blocks
   - Efficient work distribution

2. **Block-level Parallelism**
   - Shared memory for curve parameters
   - Cooperative thread arrays
   - Warp-level primitives
   - Memory coalescing

3. **Thread-level Parallelism**
   - Independent Pollard's Rho walks
   - Minimal divergence
   - Register optimization
   - Efficient branching

### Optimization Techniques

1. **Memory Access**
   - No large hash tables
   - Efficient cycle detection
   - Register pressure management
   - Memory access pattern optimization

2. **Computation**
   - Brent's cycle detection
   - Mixed coordinate point addition
   - Optimized modular arithmetic
   - Thread cooperation

3. **Algorithm-specific**
   - Pollard's Rho iteration function
   - Efficient cycle detection
   - Range-specific optimizations
   - Parameter tuning

### Future Optimizations

1. **Algorithm**
   - Fine-tune Pollard's Rho parameters
   - Optimize iteration function
   - Enhance cycle detection
   - Improve collision handling

2. **Implementation**
   - Further thread cooperation
   - Memory access patterns
   - Register usage
   - Warp utilization

3. **Testing**
   - Algorithm verification
   - Performance profiling
   - Memory analysis
   - Parameter optimization

## Architecture Updates (2024-12-22)

### Optimized Point Operations

#### Core Components
1. **Point Structures**
   - `JPoint`: Jacobian coordinates (X:Y:Z) for efficient point operations
   - `APoint`: Affine coordinates (x,y) for compact storage and I/O

2. **Warp-Level Operations**
   - Shared memory optimizations for warp-wide operations
   - Efficient memory coalescing for uint256 operations
   - Warp-level primitives for parallel reduction and scanning

3. **Endomorphism Optimization**
   - GLV scalar decomposition for faster point multiplication
   - Lambda-based endomorphism map
   - Parallel scalar multiplication using decomposed values

### Memory Hierarchy

```
[Global Memory]
    ↑↓ Coalesced Access
[Shared Memory Banks]
    ↑↓ Warp-Level Operations
[Thread Registers]
    ↑↓ Fast Local Computation
[Constant Memory]
    - Curve Parameters
    - Precomputed Tables
```

### Optimization Strategies

1. **Memory Access**
   - Coalesced global memory access for uint256 operations
   - Bank-conflict-free shared memory access
   - Efficient register usage for critical operations

2. **Warp Synchronization**
   - Warp-level primitives for fast communication
   - Shared memory for intra-warp data sharing
   - Minimal synchronization barriers

3. **Point Arithmetic**
   - Optimized Jacobian coordinate operations
   - Fast modular arithmetic using Montgomery form
   - Endomorphism-based scalar multiplication

4. **Parallelization**
   - Warp-wide parallel processing
   - Load balancing across thread blocks
   - Efficient work distribution

### Performance Considerations

1. **Memory Bottlenecks**
   - Minimize global memory access
   - Use shared memory for frequent operations
   - Optimize memory access patterns

2. **Computation Efficiency**
   - Use warp-level primitives where possible
   - Minimize thread divergence
   - Balance computation and memory access

3. **Scalability**
   - Efficient work distribution
   - Minimize synchronization overhead
   - Handle varying workload sizes

### Future Optimizations

1. **Advanced Techniques**
   - Multi-exponentiation
   - Batch verification
   - Advanced precomputation strategies

2. **Memory Management**
   - Dynamic shared memory allocation
   - Advanced caching strategies
   - Memory pool for temporary storage

3. **Algorithm Improvements**
   - Advanced GLV decomposition
   - Optimized endomorphism maps
   - Enhanced parallel processing

## Implementation Details

### Key Generation
```cpp
// Each thread generates keys in its range
k = start_k + (blockIdx.x * blockDim.x + threadIdx.x);
while (k < end_k) {
    if (validate_key(k)) {
        process_key(k);
    }
    k += gridDim.x * blockDim.x;
}
```

### Point Multiplication
```cpp
// Montgomery ladder for constant-time multiplication
while (bit < 256) {
    // Double and add based on key bit
    if (key & (1ULL << bit)) {
        point_add(&R1, &R0);
        point_double(&R0);
    } else {
        point_add(&R0, &R1);
        point_double(&R1);
    }
    bit++;
}
```

### Address Generation
```cpp
// Generate compressed public key
pubkey[0] = 0x02 | (y[0] & 1);
memcpy(pubkey + 1, x, 32);

// Double SHA256
sha256(pubkey, 33, hash1);
sha256(hash1, 32, hash2);

// RIPEMD160
ripemd160(hash2, 32, address + 1);
address[0] = 0x00;  // Version byte
