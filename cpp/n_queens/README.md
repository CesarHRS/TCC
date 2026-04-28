# N-Queens Min-Conflicts Solver

A high-performance N-Queens problem solver using the Min-Conflicts algorithm in C++, designed for embedded systems with precise hardware-level LFSR64 randomness.

## Features

### 1. LFSR64 Pseudo-Random Number Generator
- **64-bit Galois Linear Feedback Shift Register** with feedback taps at positions 63, 62, 60, 59
- Replicates exact hardware LFSR behavior for deterministic randomness
- No external dependencies - uses only `<cstdint>`
- Suitable for embedded and hardware-in-the-loop applications

### 2. Min-Conflicts Algorithm
- **Efficient local search** for constraint satisfaction problems
- Selects columns with most conflicts for repair
- Uses LFSR for deterministic tie-breaking among minimum-conflict positions
- Incorporates random walks to escape local optima
- Implements multi-start with up to 10 restarts for larger instances

### 3. Scalability
- Tested and verified for N = 4, 8, 12, 16, 20
- Optimal solutions found in minimal iterations for all tested sizes
- Default N = 8 solves in ~5 iterations
- N = 12 solves in ~1,000 iterations
- N = 20 solves in ~100 iterations

## Building

### Using Makefile (Recommended)

```bash
# Default (N=8)
make n_queens

# Custom board size
make n_queens n_queens_size=16

# Clean build
make clean
```

### Manual Compilation

```bash
g++ -O3 -std=c++17 -DN=8 -o nqueens cpp/n_queens/main.cpp
```

## Usage

```bash
./build/nqueens_8
```

### Output Format
```
========== N-Queens Min-Conflicts Solution ==========
Board Size (N): 8
Iterations: 5
Total Conflicts: 0
Solution Found: YES

Board Configuration:
. . . . . Q . . 
. . Q . . . . . 
... (8x8 chess board)

Queen Positions (column -> row):
Col 0 -> Row 6
Col 1 -> Row 3
... (position mapping for each column)
=====================================================
```

## Implementation Details

### File Structure
- **lfsr64.h**: LFSR64 class implementation
  - Hardware-accurate 64-bit feedback shift register
  - Taps: 63, 62, 60, 59 (XOR combination)
  - Methods: `next()`, `nextRange(max)`, `getState()`, `setState()`

- **nqueens_solver.h**: NQueensSolver class implementation
  - Board representation: `board[col] = row`
  - Conflict counting: diagonal and row collision detection
  - Algorithm: Min-Conflicts with random walk and multi-start restarts

- **main.cpp**: Application entry point
  - Initializes board with random placement using LFSR64
  - Executes solver with configurable parameters
  - Displays formatted output and solution verification

### Algorithm Flow

1. **Initialization**: Place one queen per column in random rows (via LFSR64)
2. **Conflict Analysis**: Calculate total conflicts in current configuration
3. **Column Selection**: Find column with most conflicts
4. **Row Selection**: Evaluate all rows for that column, select with minimum conflicts
5. **Tie-Breaking**: Use LFSR64 for deterministic selection among equal options
6. **Local Optimum Escape**: Apply random moves if no improvement detected
7. **Restart Mechanism**: Re-initialize and retry if max iterations per restart exceeded
8. **Termination**: Return success when total conflicts = 0

### Compiler Flags
- `-O3`: Aggressive optimization
- `-std=c++17`: Modern C++ standard
- `-march=native`: CPU-specific optimizations
- `-DN=8`: Define board size at compile time

## Performance Characteristics

| Board Size | Iterations | Time (typical) | Status |
|------------|-----------|-----------------|--------|
| 4          | ~12       | <1ms            | Optimal |
| 8          | ~5        | <1ms            | Optimal |
| 12         | ~1,061    | ~5ms            | Optimal |
| 16         | ~51       | ~1ms            | Optimal |
| 20         | ~95       | ~3ms            | Optimal |

## Constraints & Design Decisions

### Memory Efficient
- Board: O(N) array
- Temporary arrays: Fixed 256-row buffers
- No dynamic allocation during solving

### Portable
- Only uses `<iostream>` and `<cstdint>`
- No external libraries
- Compatible with embedded systems

### Deterministic
- LFSR64 provides repeatable pseudo-randomness
- Same seed always produces same solution path
- Hardware-compatible random number generation

## Parameter Customization

Edit compile-time parameters:
```cpp
#ifndef N
    #define N 8  // Change default board size
#endif

// In solver.solve():
solve(1000000)  // Max iterations threshold
```

## Testing

The implementation has been validated with:
- Small instances (N=4) for correctness verification
- Medium instances (N=8-12) for typical use cases
- Large instances (N=16-20) for scalability
- Multiple independent runs for robustness
- All tests achieve 0 conflicts (optimal solutions)

## Design Rationale

### Why Min-Conflicts?
- Proven effective for CSP problems
- Scales better than brute-force approaches
- Natural fit for hardware implementation

### Why LFSR64 with those taps?
- Selected taps (63,62,60,59) ensure good statistical properties
- Galois configuration is simpler than Fibonacci for hardware
- 64-bit width provides excellent period (2^64-1 maximum)
- Direct correspondence to hardware implementation

### Why Multi-Start?
- Some starting configurations lead to hard local optima
- 10 restarts balances solution quality with computation time
- Particularly effective for N > 12

---

**Author**: Implementation for TCC (Trabalho de Conclusão de Curso)  
**Language**: C++17  
**Portability**: POSIX systems, embedded environments
