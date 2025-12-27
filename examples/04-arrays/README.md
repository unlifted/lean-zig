# Example 04: Arrays

**Difficulty:** Intermediate  
**Concepts:** Collections, array operations, iteration, memory management

## What You'll Learn

- Creating and populating Lean arrays in Zig
- Accessing and modifying array elements
- Array iteration patterns
- Performance considerations for collections

## Code Overview

This example demonstrates common array operations:
1. **Create array** - Allocate and populate an array from Zig
2. **Sum array** - Iterate over elements and compute sum
3. **Map array** - Transform each element
4. **Filter array** - Select elements matching a condition

## Building and Running

```bash
lake build
lake exe arrays-demo
```

Expected output:
```
Created array: #[1, 2, 3, 4, 5]
Sum of array: 15
Doubled array: #[2, 4, 6, 8, 10]
Evens only: #[2, 4]
```

## Key Concepts

### Array Allocation

```zig
// Allocate array with capacity
const arr = lean.allocArray(capacity) orelse return error.AllocationFailed;
defer lean.lean_dec_ref(arr);

// Or allocate with initial size
const arr = lean.mkArrayWithSize(capacity, size) orelse return error.AllocationFailed;
// IMPORTANT: Must populate all elements before cleanup!
```

### Setting Elements

```zig
// Set element at index (transfers ownership of value)
lean.arraySet(arr, 0, lean.boxUsize(42));

// Fast unchecked set (no bounds checking)
lean.arrayUset(arr, 0, value);
```

### Getting Elements

```zig
// Get element at index (returns borrowed reference)
const elem = lean.arrayGet(arr, 0);

// Fast unchecked get (no bounds checking)
const elem = lean.arrayUget(arr, 0);
```

### Array Size

```zig
const size = lean.arraySize(arr);
const capacity = lean.arrayCapacity(arr);
```

### Iteration Pattern

```zig
const size = lean.arraySize(arr);
var i: usize = 0;
while (i < size) : (i += 1) {
    const elem = lean.arrayUget(arr, i);  // Fast path
    // Process elem...
}
```

## Memory Management

### Reference Counting with Arrays

Arrays hold owned references to their elements. When you:
- **Set element**: Array takes ownership (increments refcount internally)
- **Get element**: Returns borrowed reference (don't dec_ref unless you inc_ref first)
- **Dec_ref array**: Automatically dec_refs all elements

```zig
const arr = lean.allocArray(3) orelse return error.AllocationFailed;
defer lean.lean_dec_ref(arr);  // Will dec_ref all 3 elements too

lean.arraySet(arr, 0, value1);  // Transfers ownership
lean.arraySet(arr, 1, value2);  // Transfers ownership
lean.arraySet(arr, 2, value3);  // Transfers ownership
```

### Modifying Arrays

Check exclusivity before in-place modification:

```zig
if (lean.isExclusive(arr)) {
    // Safe to modify in-place (rc == 1)
    lean.arraySet(arr, i, new_value);
} else {
    // Must copy first (rc > 1)
    const new_arr = copy_array(arr);
    lean.arraySet(new_arr, i, new_value);
}
```

## Performance Notes

- Array allocation: **~50-100ns** depending on size
- Element access: **~2-3ns** (unchecked), **~5-10ns** (checked)
- Iteration: **~1-2ns per element** with unchecked access
- Exclusive arrays can be modified in-place (zero copy)

## Common Patterns

### Build array from Zig values

```zig
const values = [_]usize{ 1, 2, 3, 4, 5 };
const arr = lean.allocArray(values.len) orelse return error.AllocationFailed;

for (values, 0..) |val, i| {
    lean.arraySet(arr, i, lean.boxUsize(val));
}
```

### Map operation

```zig
const size = lean.arraySize(input);
const result = lean.allocArray(size) orelse return error.AllocationFailed;

var i: usize = 0;
while (i < size) : (i += 1) {
    const elem = lean.arrayUget(input, i);
    const transformed = transform(elem);
    lean.arraySet(result, i, transformed);
}
```

### Filter operation

```zig
// First pass: count matching elements
var count: usize = 0;
for (0..lean.arraySize(input)) |i| {
    if (predicate(lean.arrayUget(input, i))) count += 1;
}

// Second pass: build result
const result = lean.allocArray(count) orelse return error.AllocationFailed;
var j: usize = 0;
for (0..lean.arraySize(input)) |i| {
    const elem = lean.arrayUget(input, i);
    if (predicate(elem)) {
        lean.lean_inc_ref(elem);  // Need to inc_ref when copying
        lean.arraySet(result, j, elem);
        j += 1;
    }
}
```

## Next Steps

→ [Example 05: Strings](../05-strings) - Learn how to work with text data.
