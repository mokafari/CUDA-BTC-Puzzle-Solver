#!/usr/bin/env python3
import pycuda.driver as cuda
from pycuda.compiler import SourceModule
import numpy as np
import time
import sys
import os
import signal
import psutil
import threading
from datetime import datetime, timedelta
import base58
import hashlib
import logging
from typing import Tuple, List, Dict, Optional
import json
import contextlib
import atexit

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,  # Change to DEBUG for more verbose output
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('solver.log')
    ]
)
logger = logging.getLogger(__name__)

class GPUResourceError(Exception):
    """Exception raised for GPU resource allocation/deallocation errors."""
    pass

class CUDAError(Exception):
    """Exception raised for CUDA-specific errors."""
    pass

class GPUInfo:
    def __init__(self):
        try:
            # Initialize CUDA first
            cuda.init()
            self.device = cuda.Device(0)  # Use first GPU
            self.properties = {
                'name': self.device.name(),
                'compute_capability': self.device.compute_capability(),
                'total_memory': self.device.total_memory(),
                'max_threads_per_block': self.device.get_attribute(cuda.device_attribute.MAX_THREADS_PER_BLOCK),
                'max_block_dims': self.device.get_attribute(cuda.device_attribute.MAX_BLOCK_DIM_X),
                'max_grid_dims': self.device.get_attribute(cuda.device_attribute.MAX_GRID_DIM_X),
                'max_shared_memory': self.device.get_attribute(cuda.device_attribute.MAX_SHARED_MEMORY_PER_BLOCK),
                'warp_size': self.device.get_attribute(cuda.device_attribute.WARP_SIZE),
                'max_registers_per_block': self.device.get_attribute(cuda.device_attribute.MAX_REGISTERS_PER_BLOCK),
                'multiprocessor_count': self.device.get_attribute(cuda.device_attribute.MULTIPROCESSOR_COUNT)
            }
            logger.debug(f"GPU Properties: {self.properties}")
        except cuda.Error as e:
            logger.error(f"Failed to initialize CUDA: {e}")
            raise

    def optimize_grid_block(self) -> Tuple[Tuple[int, int, int], Tuple[int, int, int]]:
        warp_size = self.properties['warp_size']
        max_threads_per_sm = 1024  # Reduced from 1536
        multiprocessor_count = self.properties['multiprocessor_count']
        
        # Calculate optimal block size (multiple of warp size)
        block_size = 64  # Reduced from 128 to lower resource usage
        
        # Calculate grid size based on SM count and occupancy
        blocks_per_sm = max_threads_per_sm // block_size
        total_blocks = blocks_per_sm * multiprocessor_count
        
        # Limit grid size to avoid excessive resource usage
        grid_size = min(4096, total_blocks)
        
        logger.debug(f"Optimized grid size: {grid_size}, block size: {block_size}")
        logger.debug(f"Total threads: {grid_size * block_size}")
        
        return ((grid_size, 1, 1), (block_size, 1, 1))

class PerformanceMonitor:
    def __init__(self, start_k: int, target_address: str):
        self.start_time = time.time()
        self.start_k = int(start_k)  # Convert to regular int
        self.target_address = target_address
        self.iterations = 0
        self.last_update = self.start_time
        self.update_interval = 1.0
        self.running = True
        self.stats: Dict[str, float] = {
            'keys_per_second': 0.0,
            'total_keys': 0,
            'memory_usage': 0.0,
            'gpu_utilization': 0.0,
            'estimated_time_remaining': float('inf')
        }
        self.lock = threading.Lock()
        self._save_stats_timer = None
        self._setup_stats_saving()

    def _setup_stats_saving(self):
        def save_stats():
            if self.running:
                with self.lock:
                    with open('solver_stats.json', 'w') as f:
                        json.dump(self.stats, f)
                self._save_stats_timer = threading.Timer(5.0, save_stats)
                self._save_stats_timer.daemon = True
                self._save_stats_timer.start()

        save_stats()

    def update(self, current_k: int):
        current_time = time.time()
        if current_time - self.last_update >= self.update_interval:
            self._update_stats(current_k, current_time)
            self._print_status()
            self.last_update = current_time

    def _update_stats(self, current_k: int, current_time: float):
        elapsed_time = current_time - self.start_time
        total_keys = current_k - self.start_k
        
        with self.lock:
            self.stats['total_keys'] = total_keys
            if elapsed_time > 0:
                self.stats['keys_per_second'] = total_keys / elapsed_time
                if self.stats['keys_per_second'] > 0:
                    remaining_keys = 0xFFFFFFFFFFFFFFFF - current_k
                    self.stats['estimated_time_remaining'] = remaining_keys / self.stats['keys_per_second']
                else:
                    self.stats['estimated_time_remaining'] = float('inf')

    def _print_status(self):
        with self.lock:
            logger.info(
                f"Progress: {self.stats['total_keys']:,} keys checked "
                f"({self.stats['keys_per_second']:,.2f} keys/s) "
                f"Est. remaining: {timedelta(seconds=int(self.stats['estimated_time_remaining']))}"
            )

    def start_monitoring(self):
        def monitor_gpu():
            try:
                while self.running:
                    process = psutil.Process(os.getpid())
                    with self.lock:
                        self.stats['memory_usage'] = process.memory_info().rss / 1024 / 1024  # MB
                    time.sleep(1)
            except Exception as e:
                logger.error(f"Error in GPU monitoring thread: {e}")

        monitor_thread = threading.Thread(target=monitor_gpu)
        monitor_thread.daemon = True
        monitor_thread.start()

    def stop(self):
        self.running = False
        if self._save_stats_timer:
            self._save_stats_timer.cancel()

class PuzzleSolver:
    def __init__(self, target_address: str = "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH"):  # Puzzle #1
        try:
            # Initialize CUDA and get GPU info first
            self.gpu_info = GPUInfo()
            self.grid_dim, self.block_dim = self.gpu_info.optimize_grid_block()
            
            # Create CUDA context
            self.context = self.gpu_info.device.make_context()
            
            self.target_address = target_address
            logger.info(f"Initialized solver with grid={self.grid_dim}, block={self.block_dim}")
            logger.info(f"GPU: {self.gpu_info.properties['name']}")
            logger.info(f"Starting search for private key of address: {target_address}")
            logger.info(f"This is puzzle #1 with key range: 1 to 1")
            
            # Initialize CUDA kernel
            self._initialize_cuda()
            
            # Decode target address
            self.decoded_address = self._decode_address(target_address)
            logger.debug(f"Decoded address bytes (len={len(self.decoded_address)}): {self.decoded_address.hex()}")
            
            # Pad address to 25 bytes (version + hash + checksum)
            self.padded_address = bytes([0] * (25 - len(self.decoded_address))) + self.decoded_address
            logger.debug(f"Padded address bytes (len={len(self.padded_address)}): {self.padded_address.hex()}")
            
            # Allocate GPU memory
            self.d_address = cuda.mem_alloc(25)  # 25 bytes for full Bitcoin address
            self.d_result_k = cuda.mem_alloc(32)  # 256-bit key
            self.d_found = cuda.mem_alloc(4)  # int for found flag
            
            # Copy address to GPU
            cuda.memcpy_htod(self.d_address, self.padded_address)
            cuda.memcpy_htod(self.d_found, np.array([0], dtype=np.int32))
            
        except cuda.Error as e:
            logger.error(f"Failed to initialize solver: {e}")
            self.cleanup()
            raise
        except Exception as e:
            logger.error(f"Unexpected error during initialization: {e}")
            self.cleanup()
            raise

    def solve(self, start_k: int = 0x1, batch_size: int = None):  # Start from 1 for puzzle #1
        """
        Solve the puzzle using batched processing to avoid timeouts
        """
        try:
            # Calculate total threads if batch_size not specified
            if batch_size is None:
                grid_x = self.grid_dim[0]
                block_x = self.block_dim[0]
                batch_size = min(grid_x * block_x, 0x100000)  # Limit batch size to prevent overflow
                logger.info(f"Using batch size: {batch_size}")

            # Create performance monitor
            monitor = PerformanceMonitor(start_k, self.target_address)
            monitor.start_monitoring()
            
            # Initialize result arrays
            result_k = np.zeros(4, dtype=np.uint64)
            found = np.array([0], dtype=np.int32)
            
            try:
                while not found[0]:
                    # Reset found flag on GPU
                    cuda.memcpy_htod(self.d_found, found)
                    
                    # Log current key being checked
                    logger.debug(f"Checking key range: {start_k} to {start_k + batch_size}")
                    
                    # Launch kernel
                    self.kernel.prepared_call(
                        self.grid_dim,
                        self.block_dim,
                        self.d_result_k,
                        self.d_address,
                        self.d_found,
                        np.uint64(start_k),
                        np.uint64(batch_size)
                    )
                    
                    # Check if key found
                    cuda.memcpy_dtoh(found, self.d_found)
                    if found[0]:
                        cuda.memcpy_dtoh(result_k, self.d_result_k)
                        logger.info(f"Found private key: {result_k.tobytes().hex()}")
                        return result_k.tobytes().hex()
                    
                    # Update start_k for next batch
                    try:
                        start_k += batch_size
                        if start_k >= 0x2:  # Stop after reaching end of puzzle #1 range
                            logger.info("Reached end of key range for puzzle #1")
                            break
                    except OverflowError:
                        logger.info("Overflow detected, resetting to 0")
                        start_k = 0
                    monitor.update(start_k)
                    
            except cuda.Error as e:
                logger.error(f"CUDA error during kernel execution: {e}")
                raise
                
        except Exception as e:
            logger.error(f"Error during solve: {e}")
            raise
        finally:
            monitor.stop()
            self.cleanup()

    def cleanup(self):
        """Clean up GPU resources"""
        try:
            if hasattr(self, 'context'):
                self.context.pop()
                del self.context
        except cuda.Error as e:
            logger.error(f"Error during cleanup: {e}")

    def _initialize_cuda(self):
        try:
            # Load the PTX file
            current_dir = os.path.dirname(os.path.dirname(__file__))
            ptx_path = os.path.join(current_dir, 'build', 'solver.ptx')
            
            logger.debug(f"Attempting to load PTX from: {ptx_path}")
            
            if not os.path.exists(ptx_path):
                # Try to generate PTX if it doesn't exist
                logger.debug("PTX file not found. Attempting to generate it...")
                update_script = os.path.join(current_dir, 'update_consolidated.bat')
                if os.path.exists(update_script):
                    logger.debug("Running update_consolidated.bat to generate PTX...")
                    os.system(update_script)
                    if not os.path.exists(ptx_path):
                        raise CUDAError(f"Failed to generate PTX file at {ptx_path}")
                else:
                    raise CUDAError(f"PTX file not found at {ptx_path} and update_consolidated.bat not found")
            
            # Check PTX file size and content
            ptx_size = os.path.getsize(ptx_path)
            logger.debug(f"PTX file size: {ptx_size} bytes")
            
            with open(ptx_path, 'r') as f:
                ptx_content = f.read(1000)  # Read first 1000 bytes for debug
                logger.debug(f"PTX file starts with:\n{ptx_content[:500]}...")
                
                # Verify PTX version and target
                if '.version 8.5' not in ptx_content or '.target sm_89' not in ptx_content:
                    logger.warning("PTX file may have incorrect version or target. Regenerating...")
                    os.system(os.path.join(current_dir, 'update_consolidated.bat'))
            
            # Load the PTX module
            logger.debug("Attempting to load PTX module...")
            
            try:
                # Try loading with PyCUDA's module_from_file first
                self.module = cuda.module_from_file(ptx_path)
                logger.debug("PTX module loaded successfully using module_from_file")
            except Exception as e1:
                logger.debug(f"Failed to load PTX with module_from_file: {e1}")
                try:
                    # If that fails, try loading with SourceModule
                    from pycuda.compiler import SourceModule
                    with open(ptx_path, 'r') as f:
                        ptx_source = f.read()
                    self.module = SourceModule(ptx_source, no_extern_c=True, options=['-arch=sm_89'])
                    logger.debug("PTX module loaded successfully using SourceModule")
                except Exception as e2:
                    logger.error(f"Failed to load PTX with SourceModule: {e2}")
                    # Try one last time with direct compilation
                    try:
                        logger.debug("Attempting direct compilation of combined_kernel.cu...")
                        combined_kernel_path = os.path.join(current_dir, 'combined_kernel.cu')
                        if os.path.exists(combined_kernel_path):
                            with open(combined_kernel_path, 'r') as f:
                                cuda_source = f.read()
                            self.module = SourceModule(cuda_source, no_extern_c=True, 
                                                    options=['-arch=sm_89', '--use_fast_math', '-maxrregcount=64'])
                            logger.debug("Successfully compiled combined_kernel.cu directly")
                        else:
                            raise CUDAError("Could not find combined_kernel.cu for direct compilation")
                    except Exception as e3:
                        logger.error(f"All PTX/CUDA loading methods failed: {e3}")
                        raise
            
            # Get the kernel function
            logger.debug("Getting kernel function...")
            self.kernel = self.module.get_function("solve_puzzle")
            logger.debug("Kernel function retrieved successfully")
            
            # Set L1 cache preference
            logger.debug("Setting cache config...")
            self.context.set_cache_config(cuda.func_cache.PREFER_L1)
            logger.debug("Cache config set successfully")
            
            # Prepare kernel
            logger.debug("Preparing kernel...")
            self.kernel.prepare("PPPLL")  # result_k, address, found, start_k, batch_size
            logger.debug("Kernel prepared successfully")
            
        except Exception as e:
            logger.error(f"Error during CUDA initialization: {e}")
            logger.error(f"Error type: {type(e)}")
            logger.error(f"Error details: {e.__dict__ if hasattr(e, '__dict__') else 'No details available'}")
            raise

    def _decode_address(self, address: str) -> bytes:
        try:
            return base58.b58decode_check(address)
        except Exception as e:
            logger.error(f"Failed to decode address: {e}")
            raise

def main():
    if len(sys.argv) > 1:
        target_address = sys.argv[1]
    else:
        target_address = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    
    try:
        solver = PuzzleSolver(target_address)
        solver.solve()
    except Exception as e:
        logger.error(f"Error in main: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()