# Usage Guide

Comprehensive guide for integrating `lean-zig` into your Lean 4 project with practical examples.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Build Configuration](#build-configuration)
3. [Basic Examples](#basic-examples)
4. [Advanced Examples](#advanced-examples)
5. [Common Patterns](#common-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Quick Start

### 1. Add Dependency

Add `lean-zig` to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/YOUR_USERNAME/lean-zig" @ "main"
```

### 2. Configure Build Target

Define a target that builds your Zig library:

```lean
target zigLib pkg : FilePath := do
  -- 1. Locate the lean-zig package
  let ws ← getWorkspace
  let some leanZig := ws.findPackage? "lean-zig"
    | error "lean-zig not found"
  
  -- 2. Get the path to lean.zig
  let leanZigSrc := leanZig.dir / "Zig" / "lean.zig"

  -- 3. Define your source files
  let srcFile := pkg.dir / "zig" / "your_code.zig"
  let libFile := pkg.dir / "build" / "libyour_code.a"

  -- 4. Build using the Zig compiler
  Job.async do
    proc {
      cmd := "zig"
      args := #[
        "build-lib",
        "--dep", "lean",                -- Declare dependency name
        "-Mroot=" ++ srcFile.toString,  -- Your root file
        "-Mlean=" ++ leanZigSrc.toString, -- Map 'lean' import to lean.zig
        "-O", "ReleaseFast",            -- Optimization level
        "-femit-bin=" ++ libFile.toString,
        "-fno-emit-h",
        "-fPIC"                         -- Position Independent Code
      ]
      cwd := pkg.dir
    }
    return libFile
```

### 3. Link the Library

```lean
extern_lib libyour_code pkg := do
  fetch (pkg.target ``zigLib)

@[default_target]
lean_exe run where
  moreLinkArgs := #["-L./build", "-lyour_code"]
```

---

## Basic Examples

### Example 1: String Processing

**Zig code** (`zig/strings.zig`):

```zig
const lean = @import("lean");

/// Reverse a string by processing bytes
export fn reverse_string(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get string data
    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1; // Exclude null terminator
    
    // Allocate buffer for reversed string
    var buffer: [256]u8 = undefined;
    if (len > 256) {
        const err = lean.lean_mk_string_from_bytes("string too long", 15);
        lean.lean_dec_ref(str); // Release input
        return lean.ioResultMkError(err);
    }
    
    // Reverse
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buffer[len - 1 - i] = cstr[i];
    }
    
    // Create result
    const result = lean.lean_mk_string_from_bytes(&buffer, len);
    lean.lean_dec_ref(str); // Release input
    return lean.ioResultMkOk(result);
}
```

**Lean code**:

```lean
@[extern "reverse_string"]
opaque reverseString (s : String) : IO String

#eval reverseString "Hello, Lean!"  -- "!naeL ,olleH"
```

### Example 2: Array Operations

**Zig code** (`zig/arrays.zig`):

```zig
const lean = @import("lean");

/// Sum all natural numbers in an array
export fn sum_array(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const size = lean.arraySize(arr);
    var sum: usize = 0;
    
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        if (lean.isScalar(elem)) {
            sum += lean.unboxUsize(elem);
        }
    }
    
    const result = lean.boxUsize(sum);
    lean.lean_dec_ref(arr);
    return lean.ioResultMkOk(result);
}

/// Filter array keeping only even numbers
export fn filter_even(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const size = lean.arraySize(arr);
    const result_arr = lean.allocArray(size) orelse {
        lean.lean_dec_ref(arr);
        const err = lean.lean_mk_string_from_bytes("allocation failed", 17);
        return lean.ioResultMkError(err);
    };
    
    var count: usize = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        if (lean.isScalar(elem)) {
            const n = lean.unboxUsize(elem);
            if (n % 2 == 0) {
                lean.arrayUset(result_arr, count, lean.boxUsize(n));
                count += 1;
            }
        }
    }
    
    lean.arraySetSize(result_arr, count);
    lean.lean_dec_ref(arr);
    return lean.ioResultMkOk(result_arr);
}
```

**Lean code**:

```lean
@[extern "sum_array"]
opaque sumArray (arr : Array Nat) : IO Nat

@[extern "filter_even"]
opaque filterEven (arr : Array Nat) : IO (Array Nat)

#eval sumArray #[1, 2, 3, 4, 5]  -- 15
#eval filterEven #[1, 2, 3, 4, 5, 6]  -- #[2, 4, 6]
```

### Example 3: Constructor Manipulation

**Zig code** (`zig/tuples.zig`):

```zig
const lean = @import("lean");

/// Create a tuple (String, Nat, Float)
export fn make_triple(world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Allocate constructor with 2 object fields + float scalar
    const triple = lean.allocCtor(0, 2, @sizeOf(f64)) orelse {
        const err = lean.lean_mk_string_from_bytes("allocation failed", 17);
        return lean.ioResultMkError(err);
    };
    
    // Set string field
    const str = lean.lean_mk_string_from_bytes("Hello", 5);
    lean.ctorSet(triple, 0, str);
    
    // Set nat field
    lean.ctorSet(triple, 1, lean.boxUsize(42));
    
    // Set float scalar
    lean.ctorSetFloat(triple, 0, 3.14159);
    
    return lean.ioResultMkOk(triple);
}

/// Extract fields from triple
export fn triple_sum(triple: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get nat field
    const nat_obj = lean.ctorGet(triple, 1);
    const nat_val = lean.unboxUsize(nat_obj);
    
    // Get float field
    const float_val = lean.ctorGetFloat(triple, 0);
    
    // Compute sum
    const sum = @as(f64, @floatFromInt(nat_val)) + float_val;
    
    const result = lean.boxFloat(sum);
    lean.lean_dec_ref(triple);
    return lean.ioResultMkOk(result);
}
```

---

## Advanced Examples

### Example 4: ByteArray Processing

**Zig code** (`zig/bytes.zig`):

```zig
const lean = @import("lean");

/// XOR all bytes in a ByteArray with a key
export fn xor_bytes(byte_array: lean.obj_arg, key_byte: lean.obj_arg, 
                     world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    if (!lean.isSarray(byte_array)) {
        lean.lean_dec_ref(byte_array);
        lean.lean_dec_ref(key_byte);
        const err = lean.lean_mk_string_from_bytes("expected ByteArray", 18);
        return lean.ioResultMkError(err);
    }
    
    const key = @as(u8, @intCast(lean.unboxUsize(key_byte)));
    lean.lean_dec_ref(key_byte);
    
    const data = lean.sarrayCptr(byte_array);
    const size = lean.sarraySize(byte_array);
    const bytes: [*]u8 = @ptrCast(data);
    
    var i: usize = 0;
    while (i < size) : (i += 1) {
        bytes[i] ^= key;
    }
    
    return lean.ioResultMkOk(byte_array);
}
```

### Example 5: Type Inspection

**Zig code** (`zig/inspect.zig`):

```zig
const lean = @import("lean");

/// Get a string describing the object type
export fn describe_object(obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const description = if (lean.isScalar(obj))
        "Scalar (tagged pointer)"
    else if (lean.isString(obj))
        "String"
    else if (lean.isArray(obj))
        "Array"
    else if (lean.isSarray(obj))
        "Scalar Array"
    else if (lean.isClosure(obj))
        "Closure"
    else if (lean.isThunk(obj))
        "Thunk"
    else if (lean.isTask(obj))
        "Task"
    else if (lean.isCtor(obj))
        "Constructor"
    else
        "Unknown";
    
    const result = lean.lean_mk_string_from_bytes(
        description.ptr,
        description.len
    );
    
    lean.lean_dec_ref(obj);
    return lean.ioResultMkOk(result);
}
```

---

## Common Patterns

### Pattern 1: Reference Counting

Always manage ownership correctly:

```zig
// Taking ownership (obj_arg)
export fn consume_object(obj: lean.obj_arg) void {
    // Use the object...
    
    // Must dec_ref when done
    lean.lean_dec_ref(obj);
}

// Borrowing (b_obj_arg)
fn inspect_object(obj: lean.b_obj_arg) usize {
    // Can read but not store
    return lean.arraySize(obj);
}

// Returning ownership (obj_res)
fn create_object() lean.obj_res {
    const obj = lean.allocCtor(0, 0, 0);
    // Caller becomes responsible for dec_ref
    return obj;
}
```

### Pattern 2: Error Handling

Always handle allocation failures:

```zig
export fn safe_allocate(world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const obj = lean.allocCtor(0, 1, 0) orelse {
        const err = lean.lean_mk_string_from_bytes("out of memory", 13);
        return lean.ioResultMkError(err);
    };
    
    // Use obj...
    
    return lean.ioResultMkOk(obj);
}
```

### Pattern 3: In-Place Mutation

Check exclusivity before mutating:

```zig
fn maybe_mutate_array(arr: lean.obj_arg, i: usize, v: lean.obj_arg) lean.obj_res {
    if (lean.isExclusive(arr)) {
        // Can mutate in-place
        lean.arraySet(arr, i, v);
        return arr;
    } else {
        // Must copy first
        const new_arr = copy_array(arr);
        lean.lean_dec_ref(arr);
        lean.arraySet(new_arr, i, v);
        return new_arr;
    }
}
```

### Pattern 4: Working with Scalars

```zig
// Always check before unboxing
fn process_value(obj: lean.obj_arg) void {
    if (lean.isScalar(obj)) {
        const n = lean.unboxUsize(obj);
        // Process n...
    } else {
        // It's a heap object
        const tag = lean.objTag(obj);
        // Handle based on tag...
    }
}
```

---

## Troubleshooting

### "lean-zig not found"
**Solution**: Run `lake update` to fetch dependencies.

### Linker Errors
**Problem**: Undefined reference to Lean runtime functions.

**Solution**: Ensure you're using `-fPIC` and linking against the Lean runtime:
```lean
moreLinkArgs := #["-L./build", "-lyour_code", "-L.lake/build/lib", "-lleancpp"]
```

### Runtime Crashes

**Common causes**:

1. **Reference counting error**:
   ```zig
   // ❌ Bad: double-free
   lean.lean_dec_ref(obj);
   lean.lean_dec_ref(obj);  // Crash!
   
   // ✅ Good: track ownership
   lean.lean_dec_ref(obj);  // Only once
   ```

2. **Using freed object**:
   ```zig
   // ❌ Bad: use after free
   lean.lean_dec_ref(obj);
   const size = lean.arraySize(obj);  // Crash!
   
   // ✅ Good: check first, or don't dec_ref yet
   const size = lean.arraySize(obj);
   lean.lean_dec_ref(obj);
   ```

3. **Wrong type assumption**:
   ```zig
   // ❌ Bad: assuming type
   const n = lean.unboxUsize(obj);  // Crash if obj is heap object!
   
   // ✅ Good: check type first
   if (lean.isScalar(obj)) {
       const n = lean.unboxUsize(obj);
   }
   ```

### Debugging Tips

1. **Use Lean's debug build**:
   ```bash
   lake build --mode=debug
   ```

2. **Enable Zig safety checks**:
   ```zig
   zig build-lib -O Debug ...
   ```

3. **Print debugging**:
   ```zig
   const std = @import("std");
   std.debug.print("Object tag: {}\n", .{lean.objTag(obj)});
   ```

4. **Valgrind for memory errors**:
   ```bash
   valgrind --leak-check=full ./build/bin/run
   ```

### Performance Issues

1. **Too many reference count operations**: Batch operations when possible.
2. **Unnecessary copies**: Check `isExclusive()` before copying.
3. **Boxing overhead**: Use scalar arrays for bulk primitive data.

---

## Next Steps

- See [API Reference](api.md) for complete function documentation
- See [Design](design.md) for architectural details
- Check the test suite in `Zig/lean_test.zig` for more examples
