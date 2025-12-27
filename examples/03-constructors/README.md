# Example 03: Constructors and Algebraic Types

**Difficulty:** Intermediate  
**Concepts:** Inductive types, pattern matching, constructor manipulation

## What You'll Learn

- How Lean algebraic types map to Zig constructors
- Working with `Option` and `Result` types
- Constructor tags and field access
- Memory management for composite types

## Code Overview

This example demonstrates working with Lean's algebraic data types in Zig:

1. **Option handling** - Check if Option is Some or None, extract value
2. **Result creation** - Create Ok and Err results
3. **Custom types** - Work with user-defined inductive types

### Lean Types

```lean
-- Option α : None (tag 0) | Some (tag 1)
-- Except ε α : error (tag 0) | ok (tag 1)
```

### Constructor Memory Layout

```
[Object header (8 bytes)]
[Object fields (pointers)]
[Scalar fields (raw bytes)]
```

## Building and Running

```bash
lake build
lake exe constructors-demo
```

Expected output:
```
Processing Some(42): value is 42
Processing None: no value
Safe divide 84 / 2: Ok 42
Safe divide 42 / 0: Error: division by zero
```

## Key Concepts

### Constructor Tags

Each variant of an inductive type has a numeric tag:

```lean
inductive Option (α : Type)
  | none  -- tag = 0
  | some  -- tag = 1
```

In Zig, check tags with `lean.objectTag()`:

```zig
const tag = lean.objectTag(option);
if (tag == 0) {
    // None case
} else if (tag == 1) {
    // Some case
}
```

### Creating Constructors

```zig
// Option.none (no fields)
const none = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;

// Option.some with one field
const some = lean.allocCtor(1, 1, 0) orelse return error.AllocationFailed;
lean.ctorSet(some, 0, value);
```

### Accessing Fields

```zig
// Get field 0 (borrowed reference)
const value = lean.ctorGet(constructor, 0);

// For scalar fields (stored after object fields)
const id = lean.ctorGetUint64(constructor, offset);
```

### Reference Counting

**Critical:** Always manage reference counts properly:

```zig
const ctor = lean.allocCtor(1, 1, 0) orelse return error.AllocationFailed;
defer lean.lean_dec_ref(ctor);  // Ensure cleanup

lean.ctorSet(ctor, 0, value);  // Takes ownership of value
```

### Result Types (Except)

Lean's `Except` type (used for `IO` error handling):

```zig
// Create Ok result
const ok_value = lean.boxUsize(42);
const result = lean.allocCtor(1, 1, 0) orelse return error.AllocationFailed;
lean.ctorSet(result, 0, ok_value);

// Create Error result
const err_msg = lean.lean_mk_string("error message");
const error = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
lean.ctorSet(error, 0, err_msg);
```

## Memory Safety

### Ownership Rules

1. `ctorSet` takes ownership - don't dec_ref the value after setting
2. `ctorGet` returns borrowed reference - don't dec_ref unless you inc_ref first
3. Always dec_ref constructors you allocate

### Safe Pattern

```zig
const ctor = lean.allocCtor(tag, num_objs, scalar_sz) orelse {
    // Handle allocation failure
    return lean.ioResultMkError(error_msg);
};
defer lean.lean_dec_ref(ctor);  // Cleanup on all paths

// Set fields...
lean.ctorSet(ctor, 0, field_value);

// Return transfers ownership, don't dec_ref
return lean.ioResultMkOk(ctor);
```

## Performance Notes

- Constructor allocation: **~10-50ns** depending on size
- Field access: **~2-3ns** (just pointer arithmetic)
- Tagged pointer fields: no allocation needed

## Next Steps

→ [Example 04: Arrays](../04-arrays) - Learn how to work with collections.
