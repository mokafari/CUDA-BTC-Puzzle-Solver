cmake_minimum_required(VERSION 3.10)
project(BitcoinPuzzleSolver CUDA CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find CUDA
find_package(CUDA REQUIRED)

# Set CUDA architectures
set(CMAKE_CUDA_ARCHITECTURES 60 61 70 75 80 86)
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -O3")

# Source files
set(SOURCES
    src/kernel.cu
    src/address_optimized.cu
    src/point_ops_new.cu
    src/distinguished_points.cu
    src/sha256_optimized.cu
    src/ripemd-160cuda-main/ripemd160_cuda.cu
)

# Test source files
set(TEST_SOURCES
    src/test_kernel.cu
    src/test_case_gen.cu
)

# Create main executable
cuda_add_executable(puzzle_solver ${SOURCES})
target_include_directories(puzzle_solver PRIVATE src)

# Create test executable
cuda_add_executable(test_suite ${TEST_SOURCES} ${SOURCES})
target_include_directories(test_suite PRIVATE src)
target_compile_definitions(test_suite PRIVATE -DTEST_BUILD)

# Create performance test executable
cuda_add_executable(perf_test src/perf_test.cu ${SOURCES})
target_include_directories(perf_test PRIVATE src)
target_compile_definitions(perf_test PRIVATE -DPERF_TEST)

# Set warning level
if(MSVC)
    target_compile_options(puzzle_solver PRIVATE /W4)
    target_compile_options(test_suite PRIVATE /W4)
    target_compile_options(perf_test PRIVATE /W4)
else()
    target_compile_options(puzzle_solver PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(test_suite PRIVATE -Wall -Wextra -Wpedantic)
    target_compile_options(perf_test PRIVATE -Wall -Wextra -Wpedantic)
endif()

# Install targets
install(TARGETS puzzle_solver test_suite perf_test
    RUNTIME DESTINATION bin
)
