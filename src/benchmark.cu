#include <cuda_runtime.h>
#include <stdio.h>
#include <time.h>
#include "benchmark_config.h"
#include "point_ops_optimized.h"
#include "uint256_ops.h"
#include "secp256k1_device_params.h"
#include "secp256k1_params.h"

// Error checking macro
#define CHECK_CUDA_ERROR(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                    cudaGetErrorString(err)); \
            exit(EXIT_FAILURE); \
        } \
    } while(0)

extern "C" {

// Benchmark kernels
__global__ void benchmark_scalar_mul_kernel(JPoint* results, const uint64_t* scalars, int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    
    JPoint result;
    scalar_multiply_optimized(&result, &scalars[idx * 4]);
    results[idx] = result;
}

__global__ void benchmark_scalar_mul_endomorphism_kernel(JPoint* results, const uint64_t* scalars, int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    
    JPoint result;
    scalar_multiply_endomorphism(&result, &scalars[idx * 4]);
    results[idx] = result;
}

__global__ void benchmark_point_ops_kernel(JPoint* results, const JPoint* points1, const JPoint* points2, int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    
    JPoint result = points1[idx];
    point_double_optimized(&result);
    point_add_optimized(&result, &result, &points2[idx]);
    results[idx] = result;
}

__global__ void benchmark_arithmetic_kernel(uint64_t* results, const uint64_t* inputs1, const uint64_t* inputs2, int count) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    
    uint64_t result[4];
    add_mod_p_uint256(result, &inputs1[idx * 4], &inputs2[idx * 4], secp256k1_p);
    mul_mod_p_uint256(&results[idx * 4], result, &inputs2[idx * 4], secp256k1_p);
}

} // extern "C"

// Helper function to generate random test data
void generate_test_data(uint64_t* data, size_t count) {
    for (size_t i = 0; i < count; i++) {
        data[i] = ((uint64_t)rand() << 32) | rand();
    }
}

// Function to run a single benchmark
BenchmarkMetrics run_single_benchmark(const BenchmarkParams& params, 
                                    void (*kernel)(void*, const void*, const void*, int),
                                    size_t result_size,
                                    size_t input_size,
                                    const char* name) {
    BenchmarkMetrics metrics = {0};
    
    // Allocate device memory
    void *d_results, *d_inputs1, *d_inputs2;
    CHECK_CUDA_ERROR(cudaMalloc(&d_results, params.batch_size * result_size));
    CHECK_CUDA_ERROR(cudaMalloc(&d_inputs1, params.batch_size * input_size));
    CHECK_CUDA_ERROR(cudaMalloc(&d_inputs2, params.batch_size * input_size));
    
    // Generate and copy test data
    uint64_t* h_inputs1 = new uint64_t[params.batch_size * input_size / sizeof(uint64_t)];
    uint64_t* h_inputs2 = new uint64_t[params.batch_size * input_size / sizeof(uint64_t)];
    generate_test_data(h_inputs1, params.batch_size * input_size / sizeof(uint64_t));
    generate_test_data(h_inputs2, params.batch_size * input_size / sizeof(uint64_t));
    
    CHECK_CUDA_ERROR(cudaMemcpy(d_inputs1, h_inputs1, params.batch_size * input_size, cudaMemcpyHostToDevice));
    CHECK_CUDA_ERROR(cudaMemcpy(d_inputs2, h_inputs2, params.batch_size * input_size, cudaMemcpyHostToDevice));
    
    // Create CUDA events for timing
    cudaEvent_t start, stop;
    CHECK_CUDA_ERROR(cudaEventCreate(&start));
    CHECK_CUDA_ERROR(cudaEventCreate(&stop));
    
    // Warmup run
    kernel<<<params.grid, params.block>>>(d_results, d_inputs1, d_inputs2, params.batch_size);
    CHECK_CUDA_ERROR(cudaDeviceSynchronize());
    
    // Benchmark runs
    CHECK_CUDA_ERROR(cudaEventRecord(start));
    for (int i = 0; i < params.num_iterations; i++) {
        kernel<<<params.grid, params.block>>>(d_results, d_inputs1, d_inputs2, params.batch_size);
    }
    CHECK_CUDA_ERROR(cudaEventRecord(stop));
    CHECK_CUDA_ERROR(cudaEventSynchronize(stop));
    
    float elapsed_ms;
    CHECK_CUDA_ERROR(cudaEventElapsedTime(&elapsed_ms, start, stop));
    
    // Calculate metrics
    metrics.total_time = elapsed_ms / 1000.0;  // Convert to seconds
    metrics.avg_time = metrics.total_time / params.num_iterations;
    metrics.ops_per_second = (params.batch_size * params.num_iterations) / metrics.total_time;
    
    // Print results if verbose
    if (params.verbose) {
        printf("\nBenchmark: %s\n", name);
        printf("Total time: %.3f s\n", metrics.total_time);
        printf("Average time per iteration: %.3f ms\n", metrics.avg_time * 1000.0);
        printf("Operations per second: %.2f M\n", metrics.ops_per_second / 1e6);
    }
    
    // Cleanup
    CHECK_CUDA_ERROR(cudaEventDestroy(start));
    CHECK_CUDA_ERROR(cudaEventDestroy(stop));
    CHECK_CUDA_ERROR(cudaFree(d_results));
    CHECK_CUDA_ERROR(cudaFree(d_inputs1));
    CHECK_CUDA_ERROR(cudaFree(d_inputs2));
    delete[] h_inputs1;
    delete[] h_inputs2;
    
    return metrics;
}

// Function to write benchmark results to a file
void write_benchmark_report(const char* filename, const BenchmarkParams& params, 
                          const cudaDeviceProp& prop, const BenchmarkMetrics* metrics,
                          int num_metrics) {
    FILE* f = fopen(filename, "w");
    if (!f) {
        fprintf(stderr, "Error opening report file: %s\n", filename);
        return;
    }
    
    time_t now = time(NULL);
    fprintf(f, "=== Bitcoin Puzzle Solver Benchmark Report ===\n");
    fprintf(f, "Generated: %s\n", ctime(&now));
    
    // Device information
    fprintf(f, "\nGPU Information:\n");
    fprintf(f, "Device: %s\n", prop.name);
    fprintf(f, "Compute Capability: %d.%d\n", prop.major, prop.minor);
    fprintf(f, "Number of SMs: %d\n", prop.multiProcessorCount);
    fprintf(f, "Max Threads per Block: %d\n", prop.maxThreadsPerBlock);
    fprintf(f, "Max Shared Memory per Block: %zu bytes\n", prop.sharedMemPerBlock);
    
    // Benchmark parameters
    fprintf(f, "\nBenchmark Parameters:\n");
    fprintf(f, "Start Key: 0x%016llx\n", params.start_key);
    fprintf(f, "End Key: 0x%016llx\n", params.end_key);
    fprintf(f, "Chain Length: %d\n", params.chain_length);
    fprintf(f, "Distinguished Bits: %d\n", params.distinguished_bits);
    fprintf(f, "Table Size: %d\n", params.table_size);
    fprintf(f, "Window Size: %d\n", params.window_size);
    fprintf(f, "Batch Size: %d\n", params.batch_size);
    fprintf(f, "Grid Dimensions: (%d, %d, %d)\n", params.grid.x, params.grid.y, params.grid.z);
    fprintf(f, "Block Dimensions: (%d, %d, %d)\n", params.block.x, params.block.y, params.block.z);
    
    // Performance metrics
    const char* metric_names[] = {
        "Scalar Multiplication",
        "Endomorphism Scalar Multiplication",
        "Point Operations",
        "Modular Arithmetic"
    };
    
    fprintf(f, "\nPerformance Metrics:\n");
    for (int i = 0; i < num_metrics; i++) {
        fprintf(f, "\n%s:\n", metric_names[i]);
        fprintf(f, "  Total Time: %.3f s\n", metrics[i].total_time);
        fprintf(f, "  Average Time per Operation: %.3f ms\n", metrics[i].avg_time * 1000.0);
        fprintf(f, "  Operations per Second: %.2f M\n", metrics[i].ops_per_second / 1e6);
    }
    
    fclose(f);
}

int main(int argc, char** argv) {
    // Initialize CUDA
    int device = 0;
    CHECK_CUDA_ERROR(cudaSetDevice(device));
    
    // Get device properties
    cudaDeviceProp prop;
    CHECK_CUDA_ERROR(cudaGetDeviceProperties(&prop, device));
    
    printf("Running benchmarks on %s\n", prop.name);
    
    // Run benchmarks for each parameter set
    for (size_t param_set = 0; param_set < NUM_PARAM_SETS; param_set++) {
        const BenchmarkParams& params = BENCHMARK_PARAM_SETS[param_set];
        BenchmarkMetrics metrics[4];  // One for each benchmark type
        
        printf("\nRunning benchmark set %zu...\n", param_set);
        
        // Run scalar multiplication benchmark
        metrics[0] = run_single_benchmark(params,
            (void(*)(void*, const void*, const void*, int))benchmark_scalar_mul_kernel,
            sizeof(JPoint), sizeof(uint64_t) * 4, "Scalar Multiplication");
        
        // Run endomorphism scalar multiplication benchmark
        metrics[1] = run_single_benchmark(params,
            (void(*)(void*, const void*, const void*, int))benchmark_scalar_mul_endomorphism_kernel,
            sizeof(JPoint), sizeof(uint64_t) * 4, "Endomorphism Scalar Multiplication");
        
        // Run point operations benchmark
        metrics[2] = run_single_benchmark(params,
            (void(*)(void*, const void*, const void*, int))benchmark_point_ops_kernel,
            sizeof(JPoint), sizeof(JPoint), "Point Operations");
        
        // Run modular arithmetic benchmark
        metrics[3] = run_single_benchmark(params,
            (void(*)(void*, const void*, const void*, int))benchmark_arithmetic_kernel,
            sizeof(uint64_t) * 4, sizeof(uint64_t) * 4, "Modular Arithmetic");
        
        // Generate report filename with timestamp
        char filename[256];
        time_t now = time(NULL);
        sprintf(filename, "benchmark_report_%zu_%ld.txt", param_set, now);
        
        // Write benchmark report
        write_benchmark_report(filename, params, prop, metrics, 4);
        printf("Benchmark report written to %s\n", filename);
    }
    
    return 0;
}
