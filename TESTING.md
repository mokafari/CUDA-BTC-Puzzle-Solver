# Testing Documentation for Bitcoin Puzzle Solver

## Prerequisites

- CUDA Toolkit 11.0 or higher
- C++ compiler with C++14 support
- CMake 3.10 or higher
- Visual Studio 2019 or higher (for Windows)

## Building the Tests

1. Create a build directory:
```bash
mkdir build
cd build
```

2. Configure with CMake:
```bash
cmake ..
```

3. Build the project:
```bash
cmake --build . --config Release
```

## Running the Tests

### Component Tests

The project includes several component-level tests that verify individual parts of the system:

1. **SHA256 Tests**
   - Verifies the CUDA implementation of SHA256 against known test vectors
   - Tests both single-block and multi-block messages
   - Validates padding and length handling

2. **RIPEMD160 Tests**
   - Validates the CUDA implementation of RIPEMD160
   - Tests against standard test vectors
   - Verifies hash output formatting

3. **Elliptic Curve Tests**
   - Tests point addition and doubling operations
   - Validates scalar multiplication
   - Verifies against known secp256k1 test vectors

4. **Address Generation Tests**
   - Tests the complete address generation pipeline
   - Validates against known Bitcoin addresses
   - Checks handling of edge cases

### Running Tests

From the build directory:

```bash
./test_suite
```

Expected output:
```
=== Running Component Tests ===
SHA256 Tests: PASSED (16/16 cases)
RIPEMD160 Tests: PASSED (12/12 cases)
EC Point Tests: PASSED (8/8 cases)
Address Tests: PASSED (4/4 cases)

All tests passed!
```

### Performance Tests

The project also includes performance benchmarks:

```bash
./perf_test
```

This will run:
1. Address generation throughput test
2. Chain generation speed test
3. Hash table collision rate analysis

## Adding New Tests

1. **Adding Test Cases**
   - Add new test vectors to `test_keys.h`
   - Follow the existing struct formats for consistency

2. **Creating New Test Functions**
   - Add test functions to `test_kernel.cu`
   - Follow the naming convention: `test_[component]`
   - Include both positive and negative test cases

3. **Registering Tests**
   - Add new tests to `run_component_tests()` in `test_kernel.cu`
   - Update the test count in the results reporting

## Debugging Failed Tests

1. **Enable Debug Output**
   - Set `DEBUG_OUTPUT` in `test_kernel.cu` to 1
   - Recompile and run tests
   - Check detailed output for each test case

2. **Using CUDA Debug Tools**
   - Use `cuda-memcheck` for memory issues:
     ```bash
     cuda-memcheck ./test_suite
     ```
   - Use `cuda-gdb` for step-by-step debugging:
     ```bash
     cuda-gdb ./test_suite
     ```

## Common Issues and Solutions

1. **CUDA Runtime Errors**
   - Check CUDA driver version compatibility
   - Verify GPU compute capability requirements
   - Ensure sufficient GPU memory

2. **Test Failures**
   - Check input data formatting
   - Verify endianness handling
   - Validate memory alignment

3. **Performance Issues**
   - Monitor GPU utilization
   - Check memory transfer patterns
   - Analyze warp divergence

## Continuous Integration

The test suite is designed to be run in CI environments. Example GitHub Actions workflow:

```yaml
name: CUDA Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install CUDA
        run: |
          wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
          sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
          sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/7fa2af80.pub
          sudo add-apt-repository "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /"
          sudo apt-get update
          sudo apt-get -y install cuda-11-0
      - name: Build and Test
        run: |
          mkdir build && cd build
          cmake ..
          cmake --build . --config Release
          ./test_suite
```
