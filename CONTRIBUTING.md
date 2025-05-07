# Contributing to CUDA Bitcoin Puzzle Solver

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/CUDA_PUZZLE_BREAK.git
   cd CUDA_PUZZLE_BREAK
   ```
3. Set up the development environment:
   - Install CUDA Toolkit 11.0 or higher
   - Install CMake 3.10 or higher
   - Install a C++14 compatible compiler
   - (Optional) Set up Python environment with required packages

## Development Workflow

1. Create a new branch for your feature/fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the coding standards:
   - Use consistent formatting
   - Add comments for complex logic
   - Update documentation as needed
   - Add tests for new features

3. Build and test your changes:
   ```bash
   mkdir build && cd build
   cmake ..
   cmake --build . --config Release
   ./test_suite
   ```

4. Commit your changes:
   ```bash
   git commit -m "Description of changes"
   ```

5. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

6. Create a Pull Request from your fork to the main repository

## Coding Standards

- Follow the existing code style
- Use meaningful variable and function names
- Add comments for complex algorithms
- Keep functions focused and small
- Write unit tests for new features
- Update documentation when changing functionality

## Testing

- Run all tests before submitting changes
- Add new tests for new features
- Ensure all tests pass in both Debug and Release builds
- Test on different GPU architectures if possible

## Documentation

- Update README.md if adding new features
- Document new functions and classes
- Update architecture.md for structural changes
- Add comments for complex algorithms

## Pull Request Process

1. Update the README.md with details of changes if needed
2. Update the documentation with details of any new features
3. The PR will be merged once you have the sign-off of at least one maintainer

## Areas for Contribution

- Performance optimizations
- Multi-GPU support
- Additional test vectors
- Documentation improvements
- Bug fixes
- Feature enhancements

## Questions?

Feel free to open an issue for any questions about contributing. 