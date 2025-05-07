# GPU Bitcoin Solver Build Notes

## Build System Overview

### Compilation Process
1. Individual CUDA files are compiled to object files with optimized flags
2. Device code is linked together
3. Final static library is created

### Key Files
- `update_all10.bat`: Main build script
- `libgpubtc.lib`: Output static library

## Compilation Flags

### CUDA Compiler Options
- `-O3`: Maximum optimization level
- `--use_fast_math`: Enable fast math operations
- `-maxrregcount=64`: Limit register usage
- `--ptxas-options=-v`: Verbose PTX assembly
- `-arch sm_89`: Target Compute Capability 8.9
- `-m64`: 64-bit compilation
- `-dc`: Separate compilation and linking

### Warning Suppressions
- `/wd4244`: Conversion data loss
- `/wd4267`: Size_t to int conversion
- `/wd4305`: Truncation from double to float

## Build Order

1. **Base Operations**
   - `uint256_ops.cu` → `uint256_ops.o`
   - `secp256k1_params.cu` → `secp256k1_params.o`

2. **Core Functionality**
   - `point_ops_new.cu` → `point_ops_new.o`
   - `address_new.cu` → `address_new.o`

3. **Main Kernel**
   - `kernel.cu` → `kernel.o`

4. **Device Code Linking**
   - All object files → `gpucode.o`

5. **Static Library Creation**
   - All object files + `gpucode.o` → `libgpubtc.lib`

## Dependencies

### Required Software
- CUDA Toolkit 12.0+
- Visual Studio 2022
- Python 3.8+ with PyCUDA

### Environment Setup
1. Install CUDA Toolkit
2. Install Visual Studio with C++ support
3. Set up environment variables:
   - CUDA_PATH
   - VS_PATH
   - PATH includes CUDA bin directory

## Common Issues and Solutions

### Linking Errors
- **Issue**: Multiple definition errors
  - **Solution**: Use proper extern declarations
  - **Files**: Check header guards

- **Issue**: Undefined references
  - **Solution**: Ensure all functions are implemented
  - **Files**: Verify function declarations match definitions

### Compilation Warnings
- **Warning**: Register pressure
  - **Impact**: May reduce occupancy
  - **Solution**: Optimize register usage

- **Warning**: Precision loss
  - **Impact**: Expected for some conversions
  - **Solution**: Verify if precision loss is acceptable

## Performance Considerations

### Compilation Flags Impact
- `-O3`: Maximum optimization, may increase compilation time
- `--use_fast_math`: Faster math, slightly reduced precision
- `-maxrregcount`: Affects occupancy vs register usage trade-off

### Memory Management
- Shared memory allocation is static
- Register usage is optimized for occupancy
- Memory access patterns are coalesced

## Testing the Build

### Verification Steps
1. Run `update_all10.bat`
2. Check for compilation errors
3. Verify `libgpubtc.lib` is created
4. Run basic functionality tests

### Common Test Cases
- Point operations correctness
- Address generation verification
- Basic key search functionality
- Memory leak detection

## Maintenance Notes

### Regular Tasks
- Update CUDA toolkit when new versions release
- Check for compiler warning regressions
- Monitor build times and optimization levels
- Review and update suppressed warnings

### Version Control
- Tag stable builds
- Document major changes
- Track performance regressions
- Maintain build scripts
