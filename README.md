# CUDA Bitcoin Puzzle Solver

A high-performance CUDA-based tool for solving Bitcoin puzzle transactions by searching for private keys corresponding to specific Bitcoin addresses. This project leverages GPU acceleration and optimized cryptographic routines for maximum throughput.

---

## Features

- **CUDA-Accelerated**: Utilizes NVIDIA GPUs for massive parallelism.
- **Optimized Cryptography**: Fast implementations of secp256k1, SHA256, and RIPEMD160.
- **Bitcoin Address Generation**: Supports compressed public keys and Base58Check encoding.
- **Batch Processing**: Efficiently searches large keyspaces using batched kernel launches.
- **Testing Suite**: Comprehensive tests for cryptographic correctness and performance.
- **Performance Monitoring**: Real-time stats and logging.
- **Python & C++ Interfaces**: Run via C++ executables or Python (with PyCUDA).

---

## Project Structure

- `src/` — Core CUDA/C++ and Python source code
- `include/` — Header files
- `tests/` — Test cases and vectors
- `scripts/` — Build and run scripts
- `build/` — Build artifacts (ignored in version control)
- `docs/` — Design, roadmap, and technical documentation

---

## Quick Start

### Prerequisites

- **NVIDIA GPU** with CUDA Compute Capability 6.0+
- **CUDA Toolkit** 11.0 or higher
- **CMake** 3.10+
- **C++14** compatible compiler (Visual Studio 2019+ recommended on Windows)
- (Optional) **Python 3.7+** with `pycuda`, `numpy`, `base58`, `psutil` for Python interface

### Building (C++/CUDA)

```bash
mkdir build
cd build
cmake ..
cmake --build . --config Release
```

### Running

- **C++ Executable**:
  ```bash
  ./puzzle_solver
  ```
  (Optionally, use `./test_suite` for tests or `./perf_test` for benchmarks.)

- **Python Interface**:
  ```bash
  python src/puzzle_solver.py [bitcoin_address]
  ```
  If no address is provided, defaults to the Satoshi Genesis address.

---

## Testing

Run all tests after building:
```bash
./test_suite
```
See `TESTING.md` for details on test coverage and adding new tests.

---

## Architecture

- **Core Kernel**: `src/kernel.cu` — Main CUDA search logic
- **Cryptography**: `src/sha256_optimized.cu`, `src/ripemd160_cuda.cu`, `src/point_ops_optimized.cu`
- **Address Generation**: `src/address_optimized.cu`
- **Python Interface**: `src/puzzle_solver.py`
- **See** `src/architecture.md` for a full breakdown.

---

## Performance

- Target: >1M addresses/sec, >90% GPU utilization
- Optimizations: warp-level parallelism, memory coalescing, register pressure reduction, endomorphism for EC multiplication

---

## Documentation

- **Roadmap**: `roadmap.md`
- **Design**: `docs/design.md`
- **Memory**: `docs/memory.md`
- **Bugs & Issues**: `docs/bugs.md`

---

## Contributing

Contributions are welcome! See open issues and the roadmap for areas needing help.

---

## License

MIT License. See `LICENSE` for details. 