# Example 06: IO Results

**Difficulty:** Intermediate  
**Concepts:** Error handling, IO monad, result types, error propagation

## What You'll Learn

- Creating IO success and error results
- Checking result status
- Extracting values from results
- Error propagation patterns

## Building and Running

```bash
lake build
lake exe io-results-demo
```

Expected output:
```
Divide 10 / 2 = ok: 5
Divide 10 / 0 = error: division by zero
Parse '42' = ok: 42
Parse 'xyz' = error: invalid number format
Chain success: 200
Chain failure: caught error: bad input
```

## Key Concepts

### IO Result Structure

Lean's `IO α` is actually `EStateM.Result IO.Error α`, a tagged union:
- **Tag 0**: `ok α` - Success with value
- **Tag 1**: `error IO.Error` - Failure with error

### Creating Results

```zig
// Success
const value = lean.boxUsize(42);
return lean.ioResultMkOk(value);

// Error
const err = lean.lean_mk_string("something went wrong");
return lean.ioResultMkError(err);
```

### Checking Results

```zig
if (lean.ioResultIsOk(result)) {
    const value = lean.ioResultGetValue(result);
    // Use value...
} else {
    // Handle error...
}

// Or equivalently
if (lean.ioResultIsError(result)) {
    // Handle error...
}
```

### Extracting Values

```zig
// Get value (assumes result is ok)
const value = lean.ioResultGetValue(result);

// IMPORTANT: Check before extracting!
if (lean.ioResultIsOk(result)) {
    const value = lean.ioResultGetValue(result);
    // Safe to use value
}
```

## Memory Management

### Result Ownership

Results are heap-allocated constructors:

```zig
export fn may_fail(input: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(input);
    
    if (is_valid(input)) {
        const result = compute(input);
        return lean.ioResultMkOk(result);  // Transfers ownership
    } else {
        const err = lean.lean_mk_string("invalid input");
        return lean.ioResultMkError(err);  // Transfers ownership
    }
}
```

### Error Propagation

When calling functions that return IO results from Zig:

```zig
// Call another IO function
const result1 = other_function(arg1, arg2);

// Check result
if (lean.ioResultIsError(result1)) {
    // Propagate error upward
    return result1;
}

// Extract value and continue
const value1 = lean.ioResultGetValue(result1);
lean.lean_inc_ref(value1);  // Need ownership
lean.lean_dec_ref(result1);  // Done with result wrapper

// Use value1...
```

## Performance Notes

- Result construction: **~10-20ns** (allocates constructor)
- Tag checking: **~1-2ns** (inline comparison)
- Value extraction: **~2-3ns** (field access)
- No overhead for successful computations (just wrapper allocation)

## Common Patterns

### Safe Division

```zig
export fn safe_divide(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(a);
    defer lean.lean_dec_ref(b);
    
    const dividend = lean.unboxUsize(a);
    const divisor = lean.unboxUsize(b);
    
    if (divisor == 0) {
        const err = lean.lean_mk_string("division by zero");
        return lean.ioResultMkError(err);
    }
    
    const result = lean.boxUsize(dividend / divisor);
    return lean.ioResultMkOk(result);
}
```

### Parse with Validation

```zig
export fn parse_number(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(str);
    
    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;
    
    var result: usize = 0;
    for (cstr[0..len]) |byte| {
        if (byte < '0' or byte > '9') {
            const err = lean.lean_mk_string("invalid number format");
            return lean.ioResultMkError(err);
        }
        result = result * 10 + (byte - '0');
    }
    
    return lean.ioResultMkOk(lean.boxUsize(result));
}
```

### Chaining Operations

```zig
export fn chain_ops(input: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(input);
    
    // Validate input
    if (!is_valid(input)) {
        const err = lean.lean_mk_string("bad input");
        return lean.ioResultMkError(err);
    }
    
    // First operation
    const result1 = operation1(input);
    if (lean.ioResultIsError(result1)) {
        return result1;  // Propagate error
    }
    
    const value1 = lean.ioResultGetValue(result1);
    lean.lean_inc_ref(value1);
    lean.lean_dec_ref(result1);
    
    // Second operation
    defer lean.lean_dec_ref(value1);
    const result2 = operation2(value1);
    if (lean.ioResultIsError(result2)) {
        return result2;  // Propagate error
    }
    
    // Both succeeded
    return result2;
}
```

### Try-Catch Pattern

```zig
export fn try_operation(input: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(input);
    
    const result = risky_operation(input);
    
    if (lean.ioResultIsError(result)) {
        // Log or transform error
        lean.lean_dec_ref(result);
        
        const new_err = lean.lean_mk_string("caught error: operation failed");
        return lean.ioResultMkError(new_err);
    }
    
    return result;  // Pass through success
}
```

## Error Handling Best Practices

1. **Always check before extracting**: Use `ioResultIsOk` before `ioResultGetValue`
2. **Propagate errors upward**: Don't swallow errors, let caller decide
3. **Use descriptive error messages**: Include context about what failed
4. **Clean up on error paths**: Use `defer` for automatic cleanup
5. **Don't panic**: Return IO errors instead of using unreachable/panic

## Next Steps

→ [Example 07: Closures](../07-closures) - Learn about higher-order functions and callbacks.
