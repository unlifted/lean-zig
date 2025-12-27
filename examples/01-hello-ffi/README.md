# Example 01: Hello FFI

**Difficulty:** Beginner  
**Concepts:** Basic FFI function call, IO operations

## What You'll Learn

- How to declare an external Zig function in Lean
- How to call Zig code from Lean
- Basic IO in Lean
- Minimal project setup

## Code Overview

This example demonstrates the simplest possible Lean-Zig FFI integration:
- A Zig function that returns a constant value
- A Lean program that calls the Zig function and prints the result

### Lean Side (`Main.lean`)

```lean
@[extern "zig_get_magic_number"]
opaque zigGetMagicNumber : IO Nat

def main : IO Unit := do
  let num ← zigGetMagicNumber
  IO.println s!"Magic number from Zig: {num}"
```

### Zig Side (`hello.zig`)

```zig
export fn zig_get_magic_number(world: lean.obj_arg) lean.obj_res {
    _ = world;  // IO world token (unused)
    return lean.ioResultMkOk(lean.boxUsize(42));
}
```

## Building and Running

```bash
lake build
lake exe hello-ffi
```

Expected output:
```
Magic number from Zig: 42
```

## Key Concepts

### `@[extern "..."]`
Declares that a Lean function is implemented in a foreign language. The string must match the exported Zig function name.

### `opaque`
Indicates the function has no Lean implementation - it's defined externally.

### IO Monad
All FFI functions that interact with the outside world must return `IO` types.

### `obj_arg` and `obj_res`
Lean's C FFI convention uses these types for all function parameters and return values.

### `ioResultMkOk`
Wraps a successful value in Lean's IO result type.

### `boxUsize`
Converts a Zig `usize` into a Lean `Nat` (tagged pointer encoding).

## Next Steps

→ [Example 02: Boxing](../02-boxing) - Learn how to pass and return different scalar types.
