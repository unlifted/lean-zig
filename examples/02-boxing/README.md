# Example 02: Boxing and Unboxing

**Difficulty:** Beginner  
**Concepts:** Scalar types, boxing/unboxing, tagged pointers

## What You'll Learn

- How to pass different scalar types between Lean and Zig
- Boxing: converting Zig values to Lean objects
- Unboxing: extracting Zig values from Lean objects
- Tagged pointer optimization for small integers

## Code Overview

This example demonstrates passing and returning various scalar types:
- Natural numbers (Nat/USize)
- Unsigned integers (UInt32, UInt64)
- Floating-point numbers (Float)

### Operations

1. **Double a number** - Takes a Nat, doubles it in Zig, returns it
2. **Add two numbers** - Takes two Nat values, returns their sum
3. **Float math** - Takes two Float values, returns their product

## Building and Running

```bash
lake build
lake exe boxing-demo
```

Expected output:
```
Double 21: 42
Add 15 + 27: 42
Multiply 6.0 * 7.0: 42.0
```

## Key Concepts

### Tagged Pointers

Small integers (< 2^63) are encoded as tagged pointers:
- Odd addresses represent scalar values
- Value is `(n << 1) | 1`
- Zero-cost abstraction - no heap allocation

```zig
const value: usize = 42;
const boxed = lean.boxUsize(value);  // (42 << 1) | 1 = 85
const unboxed = lean.unboxUsize(boxed);  // 42
```

### Boxing Functions

| Function | Zig Type | Lean Type | Allocation |
|----------|----------|-----------|------------|
| `boxUsize(n)` | `usize` | `Nat` | Tagged (fast) |
| `boxUint32(n)` | `u32` | `UInt32` | Tagged |
| `boxUint64(n)` | `u64` | `UInt64` | Tagged |
| `boxFloat(f)` | `f64` | `Float` | Heap (slower) |

### Unboxing Functions

All unboxing functions require a precondition: the object must be a scalar.
Use `lean.isScalar(obj)` to check before unboxing.

```zig
if (lean.isScalar(obj)) {
    const n = lean.unboxUsize(obj);
    // safe to use n
}
```

### Multiple Arguments

When a function takes multiple arguments, they arrive as separate parameters:

```lean
-- Lean declaration
@[extern "zig_add"]
opaque zigAdd (a b : Nat) : IO Nat
```

```zig
// Zig implementation
export fn zig_add(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    const x = lean.unboxUsize(a);
    const y = lean.unboxUsize(b);
    return lean.ioResultMkOk(lean.boxUsize(x + y));
}
```

## Performance Notes

- Tagged pointer boxing/unboxing: **~1-2ns** per operation
- Float boxing requires heap allocation: **~10-20ns**
- Always prefer `boxUsize` for integers when possible

## Next Steps

→ [Example 03: Constructors](../03-constructors) - Learn how to work with algebraic data types.
