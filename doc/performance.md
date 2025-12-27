# Performance Guide

Comprehensive guide to writing high-performance Lean+Zig code with lean-zig FFI bindings.

## Table of Contents

1. [Performance Philosophy](#performance-philosophy)
2. [Hot-Path Identification](#hot-path-identification)
3. [Profiling Techniques](#profiling-techniques)
4. [Optimization Patterns](#optimization-patterns)
5. [Benchmarking Methodology](#benchmarking-methodology)
6. [Architecture Considerations](#architecture-considerations)
7. [Common Performance Pitfalls](#common-performance-pitfalls)

---

## Performance Philosophy

### Zero-Cost Abstractions

lean-zig aims for **zero-cost abstractions** where possible:

- **Tagged pointers**: Small integers (<2^63) stored inline, no heap allocation
- **Inline functions**: Hot-path operations compile to 1-5 CPU instructions
- **Direct memory access**: No unnecessary indirection or copying

### When to Optimize

**Profile first, optimize second.** Don't assume bottlenecks - measure them.

1. **Get it working** - Correct code first
2. **Get it tested** - Validated behavior
3. **Get it profiled** - Find actual bottlenecks
4. **Get it optimized** - Targeted improvements

### Performance Targets

Based on modern x86_64 hardware (2020+):

| Operation | Expected Performance | Notes |
|-----------|---------------------|-------|
| Boxing/unboxing | 1-2ns per round-trip | Tagged pointer ops |
| Reference counting | 0.5-1ns per operation | Fast path (ST objects) |
| Array element access | 2-3ns | Unchecked access |
| Constructor field access | 1-2ns | Direct pointer arithmetic |
| String byte access | 1-2ns | No validation |
| Heap allocation | 20-50ns | Via Lean runtime |

---

## Hot-Path Identification

### What is a Hot Path?

Code executed **frequently** or in **tight loops**:

- Array/string iteration over large datasets
- Repeated field access in complex data structures
- Boxing/unboxing in computation loops
- Reference counting for frequently shared objects

### Finding Hot Paths

#### Static Analysis

Look for:

```zig
// High iteration counts
for (0..1_000_000) |i| {
    // This code runs 1M times!
    const elem = lean.arrayUget(arr, i);
    process(elem);
}

// Nested loops (N*M iterations)
for (outer_items) |item| {
    for (inner_items) |inner| {
        // This runs outer_count * inner_count times
    }
}

// Recursive calls with large depth
fn recursive(n: usize) void {
    if (n == 0) return;
    // Work here...
    recursive(n - 1); // Called N times
}
```

#### Dynamic Analysis (Profiling)

Use profiling tools to find actual hot paths (see [Profiling Techniques](#profiling-techniques)).

### Inline vs. Forwarded Functions

lean-zig distinguishes between **inline** (hot-path) and **forwarded** (cold-path) functions:

#### Inline Functions (Zero Overhead)

Manually implemented in `Zig/lean.zig` for maximum performance:

```zig
// Examples from lean.zig
pub inline fn boxUsize(n: usize) obj_res {
    return @ptrFromInt((n << 1) | 1);  // 1-2 instructions
}

pub inline fn arrayUget(o: b_obj_arg, i: usize) obj_arg {
    const arr_ptr: [*]obj_arg = @ptrCast(@alignCast(o + 1));
    return arr_ptr[@sizeOf(ArrayObject) / @sizeOf(obj_arg) + i];  // 2-3 instructions
}
```

**Characteristics:**
- Called millions of times in typical workloads
- Pure pointer arithmetic or bitwise operations
- No heap allocation or complex logic
- Compile to 1-5 CPU instructions

#### Forwarded Functions (Acceptable Overhead)

Delegated to Lean runtime via `lean_raw`:

```zig
// From lean.zig
pub const allocCtor = lean_raw.lean_alloc_ctor;
pub const allocArray = lean_raw.lean_alloc_array;
```

**Characteristics:**
- Called infrequently (once per operation, not per element)
- Require heap allocation or complex state
- Use platform-specific features (atomics, TLS)
- Overhead acceptable due to low frequency

---

## Profiling Techniques

### Built-in Zig Timer

For microbenchmarks and quick profiling:

```zig
const std = @import("std");
const lean = @import("lean");

test "profile boxing operations" {
    var timer = try std.time.Timer.start();
    
    const iterations = 10_000_000;
    var sum: usize = 0;
    
    const start_time = timer.read();
    
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        sum += lean.unboxUsize(boxed);
    }
    
    const elapsed_ns = timer.read() - start_time;
    const ns_per_op = elapsed_ns / iterations;
    
    std.debug.print("\nBoxing: {d}ns per operation\n", .{ns_per_op});
    std.debug.print("Total: {d}μs for {d} iterations\n", .{elapsed_ns / 1000, iterations});
    
    // Prevent compiler from optimizing away sum
    try std.testing.expect(sum > 0);
}
```

**Pros:**
- No external tools required
- Precise nanosecond measurements
- Cross-platform

**Cons:**
- No call stack information
- Manual instrumentation required
- Can't identify hidden bottlenecks

### Linux perf (Production Profiling)

For system-wide performance analysis:

```bash
# Compile with debug symbols for better perf output
zig build-exe -O ReleaseFast -femit-bin=my_app \
    -fno-strip \
    -rdynamic \
    my_app.zig

# Profile with perf
perf record -g ./my_app

# Analyze results
perf report

# Generate flamegraph
perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
```

**Key metrics:**
- **CPU cycles**: Time spent in each function
- **Cache misses**: Memory access patterns
- **Branch mispredictions**: Control flow efficiency

**Interpreting results:**

```
# perf report output
   Overhead  Command   Shared Object     Symbol
     45.23%  my_app    my_app            [.] process_array
     23.45%  my_app    libleanshared.so  [.] lean_alloc_array
     15.67%  my_app    my_app            [.] arrayUget
      8.90%  my_app    libleanshared.so  [.] lean_inc_ref
```

Hot functions show high overhead percentage.

### Flamegraphs

Visual representation of call stacks over time:

```bash
# Install tools (once)
git clone https://github.com/brendangregg/FlameGraph
export PATH="$PATH:/path/to/FlameGraph"

# Generate flamegraph
perf record -F 99 -g ./my_app
perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg

# Open in browser
firefox flame.svg
```

**Reading flamegraphs:**
- **Width**: Time spent (wider = more CPU time)
- **Height**: Call stack depth
- **Color**: Random (for visual distinction)

### Cachegrind (Cache Analysis)

For detailed cache behavior:

```bash
# Run with valgrind cachegrind
valgrind --tool=cachegrind \
    --cache-sim=yes \
    --branch-sim=yes \
    ./my_app

# Analyze results
cg_annotate cachegrind.out.12345
```

**Key metrics:**
- **L1 cache misses**: Indicates poor data locality
- **L2/L3 cache misses**: Indicates working set too large
- **Branch mispredictions**: Indicates unpredictable control flow

### CI-Aware Performance Testing

Account for virtualized/shared CI environments:

```zig
test "performance baseline with CI awareness" {
    // Detect CI environment
    const is_ci = std.process.getEnvVarOwned(
        std.testing.allocator,
        "CI"
    ) catch null;
    defer if (is_ci) |val| std.testing.allocator.free(val);
    
    // Adjust thresholds for CI
    const threshold_ns: u64 = if (is_ci != null) 10 else 5;
    
    var timer = try std.time.Timer.start();
    const iterations = 10_000_000;
    
    // ... benchmark code ...
    
    const ns_per_op = elapsed / iterations;
    
    if (ns_per_op > threshold_ns) {
        std.debug.print("\nWARNING: Performance degraded\n", .{});
        std.debug.print("  Expected: <{d}ns per op\n", .{threshold_ns});
        std.debug.print("  Actual: {d}ns per op\n", .{ns_per_op});
        
        // Fail only if dramatically worse
        if (ns_per_op > threshold_ns * 3) {
            return error.PerformanceDegraded;
        }
    }
}
```

**CI environment considerations:**
- Shared CPU resources
- Variable load
- Different architectures
- Virtualization overhead

---

## Optimization Patterns

### 1. Tagged Pointer Optimization

Small integers use inline storage (no heap allocation):

```zig
// FAST: Tagged pointer (no allocation)
const small = lean.boxUsize(42);  // Stored as (42 << 1) | 1
const value = lean.unboxUsize(small);  // Just bitshift

// SLOW: Heap-allocated big integer
const large = create_big_nat(@as(u128, 1) << 64);  // 2^64: heap object
```

**Rule of thumb:** Keep integers < 2^63 to avoid heap allocation.

**Example optimization:**

```zig
// BAD: May allocate for large numbers
fn sum_range(start: usize, end: usize) obj_res {
    var total: usize = 0;
    for (start..end) |i| {
        total += i;
    }
    return lean.boxUsize(total);  // May overflow to BigInt
}

// GOOD: Check for overflow
fn sum_range_safe(start: usize, end: usize) obj_res {
    var total: usize = 0;
    for (start..end) |i| {
        const new_total = total + i;
        if (new_total < total) {
            // Would overflow - use BigInt
            return compute_big_sum(start, end);
        }
        total = new_total;
    }
    return lean.boxUsize(total);
}
```

### 2. Exclusive Object In-Place Mutation

Avoid copying when reference count = 1:

```zig
export fn map_array(arr: lean.obj_arg, f: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(f);
    
    if (lean.isExclusive(arr)) {
        // FAST PATH: Mutate in-place (zero copy)
        const size = lean.arraySize(arr);
        var i: usize = 0;
        while (i < size) : (i += 1) {
            const old_elem = lean.arrayUget(arr, i);
            const new_elem = apply_function(f, old_elem);
            lean.lean_dec_ref(old_elem);
            lean.arraySet(arr, i, new_elem);
        }
        return lean.ioResultMkOk(arr);
    } else {
        // SLOW PATH: Must copy (array is shared)
        const new_arr = copy_and_map(arr, f);
        lean.lean_dec_ref(arr);
        return lean.ioResultMkOk(new_arr);
    }
}
```

**Performance impact:**
- **Exclusive**: O(n) time, O(1) space
- **Shared**: O(n) time, O(n) space

**Encouraging exclusive objects:**

```lean
-- In Lean, avoid unnecessary sharing
def processArray (arr : Array Nat) : IO (Array Nat) := do
  let mut result := arr  -- Copies if arr used elsewhere
  -- Mutations here will be in-place if result is exclusive
  return result

-- Better: Transfer ownership
def processArrayInPlace (arr : Array Nat) : IO (Array Nat) := do
  -- Don't reference arr after passing to FFI
  zigProcessArray arr  -- FFI takes ownership
```

### 3. Batch Reference Counting

Minimize inc_ref/dec_ref calls:

```zig
// BAD: Excessive refcounting
for (items) |item| {
    const processed = process(item);  // Creates new object
    lean.lean_inc_ref(processed);     // +1
    array_push(result, processed);    // +1
    lean.lean_dec_ref(processed);     // -1 (net: +1)
}

// GOOD: Direct transfer
for (items) |item| {
    const processed = process(item);  // Creates new object (rc=1)
    array_push(result, processed);    // Transfers ownership (still rc=1)
    // No extra inc_ref/dec_ref needed
}
```

**Pattern:** Transfer ownership when possible instead of inc/dec.

### 4. Unchecked Array Access

Skip bounds checking when safe:

```zig
export fn sum_array(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);
    
    const size = lean.arraySize(arr);
    // Bounds checked once here ^^^
    
    var sum: usize = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        // FAST: Unchecked access (bounds proven by loop invariant)
        const elem = lean.arrayUget(arr, i);
        sum += lean.unboxUsize(elem);
    }
    
    return lean.ioResultMkOk(lean.boxUsize(sum));
}
```

**Safety:** Unchecked access is safe when:
1. Index proven < size (loop invariant)
2. Array size immutable during iteration
3. No concurrent modification

### 5. Minimize Allocations

Allocate once, reuse:

```zig
// BAD: Allocate in hot loop
for (items) |item| {
    const prefix = lean.lean_mk_string("Item: ");  // Allocates every iteration
    const label = concat_strings(prefix, item.name);
    lean.lean_dec_ref(prefix);
    process(label);
    lean.lean_dec_ref(label);
}

// GOOD: Allocate once, share
const prefix = lean.lean_mk_string("Item: ");
defer lean.lean_dec_ref(prefix);

for (items) |item| {
    lean.lean_inc_ref(prefix);  // Cheap refcount increment
    const label = concat_strings(prefix, item.name);
    process(label);
    lean.lean_dec_ref(label);
}
```

**Performance impact:**
- Allocation: ~20-50ns
- Reference increment: ~0.5ns

### 6. Data Structure Selection

Choose the right structure for access patterns:

| Pattern | Good Choice | Avoid |
|---------|-------------|-------|
| Sequential access | Array | Hash table |
| Random access | Array with indices | Linked list |
| Frequent append | Array (pre-sized) | Repeated concatenation |
| Frequent insert/delete | Linked structure | Array (requires shifting) |
| Bulk primitives | Scalar array (ByteArray) | Array of boxed values |

**Example: Scalar arrays for bulk data**

```zig
// BAD: Array of boxed floats (8 bytes pointer + heap object per element)
const arr = lean.allocArray(1000);
for (0..1000) |i| {
    lean.arraySet(arr, i, lean.boxFloat(@floatFromInt(i)));
}

// GOOD: FloatArray (8 bytes per element, no indirection)
const farr = lean.lean_mk_float_array(1000);
const data: [*]f64 = @ptrCast(lean.sarrayCptr(farr));
for (0..1000) |i| {
    data[i] = @floatFromInt(i);
}
```

**Memory savings:** 24+ bytes per element (pointer + object header + data).

### 7. String Operations

Efficient string manipulation:

```zig
// BAD: Repeated allocation
var result = lean.lean_mk_string("");
for (parts) |part| {
    const temp = concat_strings(result, part);
    lean.lean_dec_ref(result);
    result = temp;
}

// GOOD: Pre-calculate size
var total_len: usize = 0;
for (parts) |part| {
    total_len += lean.stringSize(part) - 1;  // -1 for null terminator
}

// Allocate once
var buffer = allocate_buffer(total_len + 1);
var offset: usize = 0;
for (parts) |part| {
    const part_len = lean.stringSize(part) - 1;
    const part_data = lean.stringCstr(part);
    @memcpy(buffer[offset..offset+part_len], part_data[0..part_len]);
    offset += part_len;
}
buffer[offset] = 0;  // Null terminator

const result = lean.lean_mk_string_from_bytes(buffer.ptr, offset);
```

**Performance impact:**
- Repeated concatenation: O(n²) time
- Pre-sized buffer: O(n) time

### 8. Function Call Overhead

Reduce virtual dispatch:

```zig
// BAD: Function pointer call in hot loop
export fn apply_to_array(arr: lean.obj_arg, f: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    const size = lean.arraySize(arr);
    for (0..size) |i| {
        const elem = lean.arrayUget(arr, i);
        const result = call_closure(f, elem);  // Virtual call every iteration
        // ...
    }
}

// GOOD: Specialize common cases
export fn apply_to_array_optimized(arr: lean.obj_arg, f: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    // Check for known function types
    if (is_doubler_closure(f)) {
        // FAST PATH: Direct implementation
        for (0..size) |i| {
            const elem = lean.arrayUget(arr, i);
            const value = lean.unboxUsize(elem);
            lean.arraySet(arr, i, lean.boxUsize(value * 2));
        }
    } else {
        // SLOW PATH: Virtual call
        for (0..size) |i| {
            const result = call_closure(f, elem);
            // ...
        }
    }
}
```

---

## Benchmarking Methodology

### Writing Good Benchmarks

#### 1. Sufficient Iterations

Run enough iterations to amortize measurement overhead:

```zig
test "benchmark with sufficient iterations" {
    var timer = try std.time.Timer.start();
    
    // Too few: measurement noise dominates
    // const iterations = 100;  ❌
    
    // Good: 10M+ for nanosecond operations
    const iterations = 10_000_000;  // ✓
    
    const start = timer.read();
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        // Operation to benchmark
        const boxed = lean.boxUsize(i);
        _ = lean.unboxUsize(boxed);
    }
    const elapsed = timer.read() - start;
    
    const ns_per_op = elapsed / iterations;
    std.debug.print("\n{d}ns per operation\n", .{ns_per_op});
}
```

#### 2. Prevent Compiler Optimization

Ensure benchmarked code isn't optimized away:

```zig
// BAD: Compiler may optimize entire loop away
var sum: usize = 0;
for (0..iterations) |i| {
    const boxed = lean.boxUsize(i);
    sum += lean.unboxUsize(boxed);
}
// sum is never used - entire loop may disappear!

// GOOD: Use result
var sum: usize = 0;
for (0..iterations) |i| {
    const boxed = lean.boxUsize(i);
    sum += lean.unboxUsize(boxed);
}
try std.testing.expect(sum > 0);  // Forces sum to be computed

// BETTER: Return result
test "benchmark returns result" {
    const sum = benchmark_boxing(10_000_000);
    try std.testing.expect(sum > 0);
}

fn benchmark_boxing(iterations: usize) usize {
    var sum: usize = 0;
    for (0..iterations) |i| {
        const boxed = lean.boxUsize(i);
        sum += lean.unboxUsize(boxed);
    }
    return sum;
}
```

#### 3. Warm-Up Phase

Allow CPU to reach steady state:

```zig
test "benchmark with warm-up" {
    var timer = try std.time.Timer.start();
    
    // Warm-up: Prime caches, branch predictors
    const warmup_iterations = 1_000_000;
    var i: usize = 0;
    while (i < warmup_iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        _ = lean.unboxUsize(boxed);
    }
    
    // Actual benchmark
    const iterations = 10_000_000;
    const start = timer.read();
    
    i = 0;
    while (i < iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        _ = lean.unboxUsize(boxed);
    }
    
    const elapsed = timer.read() - start;
    // ... report results ...
}
```

#### 4. Realistic Data

Use representative inputs:

```zig
// BAD: Unrealistic - all same value
for (0..size) |i| {
    array[i] = lean.boxUsize(42);  // Branch predictors love this
}

// GOOD: Varied data
for (0..size) |i| {
    array[i] = lean.boxUsize(prng.random().int(usize));
}
```

### Statistical Analysis

#### Multiple Runs

Single measurements are noisy - use statistics:

```zig
test "benchmark with statistics" {
    const runs = 10;
    var measurements: [runs]u64 = undefined;
    
    for (0..runs) |run| {
        var timer = try std.time.Timer.start();
        const start = timer.read();
        
        // Benchmark code
        var sum: usize = 0;
        for (0..10_000_000) |i| {
            sum += i;
        }
        try std.testing.expect(sum > 0);
        
        measurements[run] = timer.read() - start;
    }
    
    // Compute statistics
    var sum: u64 = 0;
    var min: u64 = std.math.maxInt(u64);
    var max: u64 = 0;
    
    for (measurements) |m| {
        sum += m;
        if (m < min) min = m;
        if (m > max) max = m;
    }
    
    const mean = sum / runs;
    
    std.debug.print("\nResults over {d} runs:\n", .{runs});
    std.debug.print("  Mean: {d}ns\n", .{mean});
    std.debug.print("  Min: {d}ns\n", .{min});
    std.debug.print("  Max: {d}ns\n", .{max});
    std.debug.print("  Range: {d}ns ({d:.1}%)\n", .{
        max - min,
        @as(f64, @floatFromInt(max - min)) / @as(f64, @floatFromInt(mean)) * 100.0
    });
}
```

**Interpreting results:**
- **Low variance (<10%)**: Consistent performance, stable benchmark
- **High variance (>20%)**: Unstable, may need more warmup or iterations
- **Use minimum**: Represents best case (no interference)

### Regression Detection

Track performance over time:

```bash
# Run benchmarks, save results
zig build test --summary all 2>&1 | tee benchmark-results-$(date +%Y%m%d).txt

# Compare with baseline
BASELINE=benchmark-results-baseline.txt
CURRENT=benchmark-results-$(date +%Y%m%d).txt

# Extract timing, compare (requires parsing)
# Fail CI if >10% regression
```

**Example GitHub Actions workflow:**

```yaml
- name: Run performance tests
  run: zig build test | tee perf-results.txt

- name: Check for regressions
  run: |
    # Download baseline from previous successful run
    # Compare results
    # Fail if regression >10%
```

---

## Architecture Considerations

### CPU Architecture Differences

#### x86_64 vs ARM64

| Aspect | x86_64 | ARM64 | Impact |
|--------|--------|-------|--------|
| Pointer size | 8 bytes | 8 bytes | None |
| Alignment | Relaxed | Strict | ARM crashes on unaligned access |
| Cache line | 64 bytes | 64 bytes (typical) | None |
| Atomic operations | Strong ordering | Weak ordering | May need barriers |

#### Alignment on ARM

```zig
// x86_64: Often works even if misaligned
// ARM64: CRASHES on misaligned access

// BAD: Assumes no alignment requirements
const value_ptr: *u64 = @ptrCast(byte_array + 3);  // Misaligned!
const value_bad = value_ptr.*;  // CRASH on ARM

// GOOD (when input is already aligned):
// Precondition: `byte_array` has alignment >= @alignOf(u64)
const aligned_ptr: *align(@alignOf(u64)) const u64 =
    @ptrCast(@alignCast(byte_array));
const value_aligned = aligned_ptr.*;  // Works when precondition holds

// GOOD (robust for arbitrary byte data): copy through an aligned local
var tmp: u64 = undefined;
@memcpy(std.mem.asBytes(&tmp), byte_array + 3, @sizeOf(u64));
const value_safe = tmp;  // Safe on all architectures
```

**lean-zig's approach:** Uses `@alignCast` in all pointer casts to handle architecture differences.

### Cache Optimization

#### Cache Line Size (64 bytes typical)

**False sharing** - multiple threads modifying different data on same cache line:

```zig
// BAD: Adjacent fields cause cache line bouncing
const ThreadData = struct {
    count_thread1: usize,  // Same cache line
    count_thread2: usize,  // Same cache line
};

// GOOD: Pad to separate cache lines
const ThreadData = struct {
    count_thread1: usize,
    _padding1: [56]u8,  // Force to separate cache lines (64 - 8 = 56)
    count_thread2: usize,
    _padding2: [56]u8,
};
```

#### Prefetching

For predictable access patterns:

```zig
// Manual prefetch (advanced)
const builtin = @import("builtin");

if (builtin.cpu.arch == .x86_64) {
    // Prefetch next elements
    for (0..size) |i| {
        if (i + 8 < size) {
            const next_ptr = lean.arrayUget(arr, i + 8);
            asm volatile ("prefetcht0 %[ptr]"
                :
                : [ptr] "m" (next_ptr)
            );
        }
        
        const elem = lean.arrayUget(arr, i);
        process(elem);
    }
}
```

**Usually unnecessary:** Modern CPUs have sophisticated prefetchers.

### SIMD Opportunities

For bulk operations on scalar arrays:

```zig
// Process 4 floats at once with SIMD
const Vector4f = @Vector(4, f32);

fn process_float_array_simd(arr: lean.obj_arg) void {
    const size = lean.sarraySize(arr);
    const data: [*]f32 = @ptrCast(lean.sarrayCptr(arr));
    
    var i: usize = 0;
    // Process 4 at a time
    while (i + 4 <= size) : (i += 4) {
        const vec: Vector4f = data[i..][0..4].*;
        const result = vec * @as(Vector4f, @splat(2.0));
        data[i..][0..4].* = result;
    }
    
    // Handle remainder
    while (i < size) : (i += 1) {
        data[i] *= 2.0;
    }
}
```

**When to use SIMD:**
- Large arrays of primitive types
- Same operation on all elements
- Computationally intensive (multiplication, square root, etc.)

**When not to use:**
- Small arrays (<1000 elements)
- Branching logic per element
- Non-contiguous data

---

## Common Performance Pitfalls

### 1. Forgetting to Inline Critical Functions

```zig
// BAD: Function call overhead in hot loop
fn unbox_wrapper(obj: lean.obj_arg) usize {
    return lean.unboxUsize(obj);
}

for (array) |elem| {
    const val = unbox_wrapper(elem);  // Call overhead every iteration
    // ...
}

// GOOD: Inline critical wrapper
inline fn unbox_wrapper(obj: lean.obj_arg) usize {
    return lean.unboxUsize(obj);
}

// BETTER: Call directly
for (array) |elem| {
    const val = lean.unboxUsize(elem);
    // ...
}
```

### 2. Unnecessary Boxing/Unboxing

```zig
// BAD: Repeated boxing
fn compute_sum(arr: lean.obj_arg) lean.obj_res {
    var sum: usize = 0;
    for (0..lean.arraySize(arr)) |i| {
        const elem = lean.arrayUget(arr, i);
        const val = lean.unboxUsize(elem);
        sum += val;
        
        // Unnecessary boxing in loop
        const boxed = lean.boxUsize(sum);
        lean.lean_dec_ref(boxed);
    }
    return lean.boxUsize(sum);
}

// GOOD: Box only at end
fn compute_sum(arr: lean.obj_arg) lean.obj_res {
    var sum: usize = 0;
    for (0..lean.arraySize(arr)) |i| {
        const elem = lean.arrayUget(arr, i);
        sum += lean.unboxUsize(elem);
    }
    return lean.boxUsize(sum);  // Box once
}
```

### 3. Excessive Copying

```zig
// BAD: Copies on every operation
fn transform_pipeline(arr: lean.obj_arg) lean.obj_res {
    const step1 = copy_and_map(arr, op1);
    const step2 = copy_and_map(step1, op2);
    const step3 = copy_and_map(step2, op3);
    return step3;
}

// GOOD: Check exclusivity, mutate in-place when possible
fn transform_pipeline(arr: lean.obj_arg) lean.obj_res {
    var current = arr;
    
    if (lean.isExclusive(current)) {
        map_in_place(current, op1);
        map_in_place(current, op2);
        map_in_place(current, op3);
    } else {
        current = copy_and_map(current, op1);
        // After copy, we have exclusive access
        map_in_place(current, op2);
        map_in_place(current, op3);
    }
    
    return current;
}
```

### 4. Linear Search in Hot Loops

```zig
// BAD: O(n²) lookup
for (items) |item| {
    for (lookup_table) |entry| {
        if (entry.id == item.id) {
            // Found
            break;
        }
    }
}

// GOOD: O(n) with hash map (requires FFI to Lean data structures)
const hash_map = build_hash_map(lookup_table);
for (items) |item| {
    const entry = hash_map_get(hash_map, item.id);
    // ...
}
```

### 5. Not Using Unchecked Operations

```zig
// SLOW: Bounds check every iteration
for (0..size) |i| {
    const elem = lean.arrayGet(arr, i);  // Checks i < size
    // ...
}

// FAST: Check once, use unchecked access
const size = lean.arraySize(arr);  // Bounds known
for (0..size) |i| {
    const elem = lean.arrayUget(arr, i);  // No check (safe due to loop invariant)
    // ...
}
```

### 6. Ignoring Reference Count Overhead

```zig
// BAD: Excessive inc_ref/dec_ref
for (items) |item| {
    lean.lean_inc_ref(item);
    process(item);
    lean.lean_dec_ref(item);
    
    lean.lean_inc_ref(item);
    other_process(item);
    lean.lean_dec_ref(item);
}

// GOOD: Borrow when possible
for (items) |item| {
    // Don't inc/dec if functions just borrow
    process(item);      // Takes b_obj_arg
    other_process(item); // Takes b_obj_arg
}
```

### 7. String Concatenation in Loops

```zig
// BAD: O(n²) string building
var result = lean.lean_mk_string("");
for (parts) |part| {
    const temp = string_append(result, part);
    lean.lean_dec_ref(result);
    result = temp;
}

// GOOD: Build array, join once
const arr = lean.allocArray(parts.len);
for (parts, 0..) |part, i| {
    lean.lean_inc_ref(part);
    lean.arraySet(arr, i, part);
}
const result = string_join(arr, ",");
lean.lean_dec_ref(arr);
```

---

## Performance Checklist

Before shipping performance-critical code:

- [ ] **Profiled** with real workloads, not assumptions
- [ ] **Benchmarked** hot paths with sufficient iterations
- [ ] **Checked** reference counting (no leaks, minimal overhead)
- [ ] **Verified** inline functions used for hot paths
- [ ] **Tested** with both exclusive and shared objects
- [ ] **Validated** unchecked operations are safe
- [ ] **Confirmed** minimal allocations in loops
- [ ] **Ensured** data structures match access patterns
- [ ] **Measured** cache behavior (if relevant)
- [ ] **Tested** on target architecture (x86_64, ARM64)

---

## Further Resources

### Tools

- **Zig Standard Library**: `std.time.Timer`, `std.debug.print`
- **Linux perf**: System-wide profiling
- **Flamegraph**: Call stack visualization
- **Valgrind**: Memory and cache analysis
- **hyperfine**: Command-line benchmarking tool

### Reading

- [Lean 4 Runtime Documentation](https://github.com/leanprover/lean4/tree/master/src/runtime)
- [Zig Performance Guide](https://ziglang.org/documentation/master/#Performance)
- [What Every Programmer Should Know About Memory](https://people.freebsd.org/~lstewart/articles/cpumemory.pdf)
- [Software Optimization Resources](https://www.agner.org/optimize/)

### lean-zig Specific

- [API Reference](api.md): Function performance characteristics
- [Usage Guide](usage.md): Common patterns and examples
- [Design Document](design.md): Architecture decisions
- [Test Suite](../Zig/tests/): `performance_test.zig` for baselines

---

## Summary

**Key Takeaways:**

1. **Profile first**: Don't optimize without measurements
2. **Inline hot paths**: Boxing, array access, field access
3. **Minimize allocations**: Allocate once, reuse, batch operations
4. **Leverage exclusivity**: Mutate in-place when rc=1
5. **Use unchecked operations**: When safe (proven bounds)
6. **Choose right structures**: Scalar arrays for bulk primitives
7. **Account for CI**: Adjust thresholds for virtual environments
8. **Test on target**: Architecture differences matter (ARM alignment)

**When in doubt**: Run the test suite (`zig build test`) - it includes performance baselines to catch regressions.
