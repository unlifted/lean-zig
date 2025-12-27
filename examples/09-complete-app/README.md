# Example 09: Complete Application

**Difficulty:** Advanced  
**Concepts:** Integration, real-world patterns, data processing pipeline

## What You'll Learn

- Integrating multiple lean-zig concepts
- Building a data processing pipeline
- Error handling throughout a workflow
- Performance-conscious design

## Application Overview

This example implements a **CSV data processor** that:
1. Reads lines from input
2. Parses CSV records
3. Validates and filters data
4. Computes statistics
5. Formats output

It demonstrates:
- String processing (CSV parsing)
- Array operations (data storage)
- Constructor usage (result types)
- Error handling (validation)
- Memory management (cleanup patterns)

## Building and Running

```bash
lake build
lake exe complete-app
```

Expected output:
```
Processing CSV data...

Input records: 5
Valid records: 4
Invalid records: 1

Statistics:
  Total: 150
  Average: 37.5
  Min: 10
  Max: 80

Top records:
  Alice: 80
  David: 40
```

## Architecture

### Data Flow

```
CSV Input → Parse → Validate → Process → Output
   ↓         ↓        ↓          ↓        ↓
 Strings   Array   Filtered   Stats   Results
```

### Components

1. **Parser** (Zig): Fast CSV parsing with error handling
2. **Validator** (Zig): Data validation and filtering
3. **Aggregator** (Zig): Statistics computation
4. **Formatter** (Lean): Output formatting

## Key Implementation Patterns

### Pipeline Composition

```zig
export fn process_pipeline(input: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(input);
    
    // Stage 1: Parse
    const parsed = parse_csv(input);
    if (lean.ioResultIsError(parsed)) return parsed;
    
    const records = lean.ioResultGetValue(parsed);
    defer lean.lean_dec_ref(records);
    
    // Stage 2: Validate
    const validated = validate_records(records);
    if (lean.ioResultIsError(validated)) return validated;
    
    const clean = lean.ioResultGetValue(validated);
    defer lean.lean_dec_ref(clean);
    
    // Stage 3: Aggregate
    return compute_statistics(clean);
}
```

### Error Accumulation

```zig
// Track errors while processing
const errors = lean.allocArray(0) orelse return error;
defer lean.lean_dec_ref(errors);

for (records, 0..) |record, i| {
    const result = validate(record);
    if (lean.ioResultIsError(result)) {
        const err_msg = create_error_msg(i, result);
        array_push(errors, err_msg);
    }
}

// Return errors if any
if (lean.arraySize(errors) > 0) {
    return lean.ioResultMkError(format_errors(errors));
}
```

### Efficient Filtering

```zig
// Two-pass filter: count then allocate
var count: usize = 0;
for (0..lean.arraySize(arr)) |i| {
    if (predicate(lean.arrayUget(arr, i))) count += 1;
}

const result = lean.allocArray(count) orelse return error;
var j: usize = 0;
for (0..lean.arraySize(arr)) |i| {
    const elem = lean.arrayUget(arr, i);
    if (predicate(elem)) {
        lean.lean_inc_ref(elem);
        lean.arraySet(result, j, elem);
        j += 1;
    }
}
```

## Code Structure

### CSV Record Type

```lean
structure Record where
  name : String
  value : Nat
  deriving Repr

-- Represented in Zig as constructor:
-- Tag 0, 2 object fields (name: String, value: Nat)
```

### Statistics Type

```lean
structure Statistics where
  count : Nat
  total : Nat
  average : Float
  min : Nat
  max : Nat
  deriving Repr
```

## Performance Optimizations

### 1. Minimize Allocations

```zig
// BAD: Allocate on every iteration
for (items) |item| {
    const str = lean.lean_mk_string("prefix");
    // ... use str ...
    lean.lean_dec_ref(str);
}

// GOOD: Allocate once
const prefix = lean.lean_mk_string("prefix");
defer lean.lean_dec_ref(prefix);
for (items) |item| {
    lean.lean_inc_ref(prefix);  // Cheap refcount
    // ... use prefix ...
}
```

### 2. Use Unchecked Access

```zig
// After validating bounds once
if (i >= lean.arraySize(arr)) return error.OutOfBounds;

// Use fast path
while (i < lean.arraySize(arr)) : (i += 1) {
    const elem = lean.arrayUget(arr, i);  // No bounds check
    // ...
}
```

### 3. Exclusive In-Place Updates

```zig
if (lean.isExclusive(arr)) {
    // Modify in-place (zero copy)
    for (0..lean.arraySize(arr)) |i| {
        const old = lean.arrayUget(arr, i);
        const new = transform(old);
        lean.lean_dec_ref(old);
        lean.arraySet(arr, i, new);
    }
} else {
    // Must copy (expensive)
    const new_arr = copy_and_modify(arr);
    // ...
}
```

## Error Handling Strategy

### Fail Fast

```zig
// Validate inputs immediately
if (!is_valid_input(input)) {
    const err = lean.lean_mk_string("invalid input");
    return lean.ioResultMkError(err);
}

// Continue with valid data
```

### Graceful Degradation

```zig
// Collect partial results even if some fail
var valid_count: usize = 0;
var error_count: usize = 0;

for (items) |item| {
    const result = process(item);
    if (lean.ioResultIsOk(result)) {
        valid_count += 1;
    } else {
        error_count += 1;
        // Log but continue
    }
}

// Return stats about processing
```

### Detailed Error Messages

```zig
const err_msg = std.fmt.allocPrint(
    allocator,
    "Failed to parse record {d}: invalid value '{s}'",
    .{record_index, field_value}
) catch "allocation failed";

const err = lean.lean_mk_string_from_bytes(err_msg.ptr, err_msg.len);
return lean.ioResultMkError(err);
```

## Testing Strategy

### Unit Tests (Zig)

```zig
test "parse_csv_line" {
    const input = lean.lean_mk_string("Alice,80");
    defer lean.lean_dec_ref(input);
    
    const result = parse_line(input);
    try testing.expect(lean.ioResultIsOk(result));
    
    const record = lean.ioResultGetValue(result);
    defer lean.lean_dec_ref(record);
    
    // Validate record structure
    const name = lean.ctorGet(record, 0);
    try testing.expect(lean.stringEq(name, expected_name));
}
```

### Integration Tests (Lean)

```lean
def testPipeline : IO Unit := do
  let input := ["Alice,80", "Bob,40", "Invalid"]
  let result ← processCsvData input
  
  match result with
  | .ok stats =>
    assert! stats.count == 2
    assert! stats.total == 120
  | .error msg =>
    throw (IO.userError s!"Unexpected error: {msg}")
```

## Real-World Considerations

### Scalability

- Process data in chunks for large files
- Use tasks for parallel processing
- Stream data instead of loading all into memory

### Robustness

- Validate all external inputs
- Handle all error cases explicitly
- Add logging/telemetry for debugging

### Maintainability

- Separate concerns (parsing, validation, processing)
- Document performance characteristics
- Write comprehensive tests

## Lessons Learned

1. **Start simple**: Get basic flow working first
2. **Profile first**: Don't optimize without measurements
3. **Test edge cases**: Empty inputs, malformed data, large datasets
4. **Document ownership**: Clear who owns what data
5. **Handle all errors**: Never ignore failure paths

## Next Steps

- Explore [lean-zig documentation](../../doc/api.md)
- Read [performance guide](../../doc/design.md)
- Check out [lean-zig test suite](../../Zig/tests/) for more patterns
- Build your own Lean+Zig application!

## Going Further

### Add Features

- CSV writing (output results)
- More complex aggregations (median, percentiles)
- Custom data types beyond strings and numbers
- Async processing with tasks

### Optimize

- Benchmark with real data
- Profile with `perf` or similar tools
- Experiment with different data structures
- Consider SIMD for bulk operations

### Integrate

- Connect to databases
- Add network I/O
- Build web APIs
- Create CLI tools

The lean-zig library provides the foundation - now it's your turn to build something amazing!
