# Usage Guide

Comprehensive guide for integrating `lean-zig` into your Lean 4 project.

## Quick Start

### 1. Add Dependency

```lean
require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"
```

### 2. Automatic Binding Generation

The library uses `build.zig` which automatically:
- Detects your Lean installation via `lean --print-prefix`
- Generates FFI bindings from `lean.h` using `translateC`
- Links against Lean runtime

**No manual configuration needed.** Bindings always match your installed Lean version.

### 3. Use in Your Zig Code

```zig
const lean = @import("lean");

export fn my_function(obj: lean.obj_arg) lean.obj_res {
    defer lean.lean_dec_ref(obj);
    // ... use lean.* functions ...
}
```

## Build Integration

### Option A: Invoke via Lake

```lean
target zigBuild pkg : Unit := do
  let ws ← getWorkspace
  let some leanZig := ws.findPackage? "lean-zig"
    | error "lean-zig not found"
  
  Job.async do
    let out ← IO.Process.output {
      cmd := "zig"
      args := #["build", "test"]
      cwd := leanZig.dir
    }
    if out.exitCode != 0 then
      error "zig build failed"
```

### Option B: Depend on lean-zig Module

In your `build.zig.zon`:

```zig
.dependencies = .{
    .@"lean-zig" = .{
        .url = "https://github.com/unlifted/lean-zig/archive/main.tar.gz",
        // Add actual hash
    },
},
```

Then in your `build.zig`:

```zig
const lean_zig = b.dependency("lean-zig", .{
    .target = target,
    .optimize = optimize,
});

const lean_module = lean_zig.module("lean-zig");
your_lib.root_module.addImport("lean", lean_module);
```

## Performance Considerations

### Hot-Path Functions (Inlined)

These compile to **1-5 CPU instructions**:

- `boxUsize` / `unboxUsize` - 1 shift + 1 bitwise op
- `lean_inc_ref` / `lean_dec_ref` - 1 compare + 1 increment  
- `objectTag`, `objectRc` - 1 pointer cast + 1 load
- `arrayUget`, `arrayGet` - pointer arithmetic + load
- `ctorGet`, `ctorSet` - pointer arithmetic + load/store
- `stringCstr`, `stringSize` - pointer arithmetic + load

### Cold-Path Functions (Forwarded)

These call into Lean runtime (still fast):

- `allocCtor`, `allocArray` - heap allocation
- `lean_mk_string` - string creation
- `lean_dec_ref_cold` - object finalization (MT-safe)

### Performance Guidelines

1. **Use unchecked access in hot loops**: `arrayUget` over `arrayGet`
2. **Leverage tagged pointers**: Small integers (<2^63) have zero overhead
3. **Check exclusivity**: `isExclusive` enables in-place mutation
4. **Batch refcounts**: Group operations before inc/dec calls
5. **Profile first**: Use `std.time.Timer` to measure critical paths

Expected performance on modern x86_64:
- Boxing/unboxing: **1-2ns** per round-trip
- Refcount fast path: **0.5ns** per operation
- Array element access: **2-3ns**
- Field access: **1-2ns**

## Common Patterns

### Pattern 1: Ownership Transfer

```zig
export fn process(obj: lean.obj_arg) lean.obj_res {
    defer lean.lean_dec_ref(obj);  // Takes ownership, must clean up
    // ... use obj ...
    return lean.ioResultMkOk(result);
}
```

### Pattern 2: Borrowing

```zig
export fn inspect(obj: lean.b_obj_arg) lean.obj_res {
    // Borrows - no dec_ref!
    const tag = lean.objectTag(obj);
    return lean.ioResultMkOk(lean.boxUsize(@intCast(tag)));
}
```

### Pattern 3: Sharing References

```zig
export fn duplicate(obj: lean.obj_arg) lean.obj_res {
    lean.lean_inc_ref(obj);  // Need two references
    
    const pair = lean.allocCtor(0, 2, 0) orelse {
        lean.lean_dec_ref(obj);
        return lean.ioResultMkError(lean.lean_mk_string("alloc failed"));
    };
    
    lean.ctorSet(pair, 0, obj);
    lean.ctorSet(pair, 1, obj);  // Both fields share the object
    return lean.ioResultMkOk(pair);
}
```

### Pattern 4: In-Place Mutation

```zig
export fn mutate(arr: lean.obj_arg, idx: usize, val: lean.obj_arg) lean.obj_res {
    if (lean.isExclusive(arr)) {
        // Exclusive access - mutate in place (fast path)
        const old = lean.arrayUget(arr, idx);
        lean.lean_dec_ref(old);
        lean.arraySet(arr, idx, val);
        return lean.ioResultMkOk(arr);
    } else {
        // Shared - must copy (slow path)
        const new_arr = lean.arrayCopy(arr);
        lean.lean_dec_ref(arr);
        lean.arraySet(new_arr, idx, val);
        return lean.ioResultMkOk(new_arr);
    }
}
```

## Complete End-to-End Example

This example demonstrates the full workflow: Lean code calling Zig, passing data both directions.

### Step 1: Define Lean Interface

In your Lean project, create `lib/ZigFFI.lean`:

```lean
-- FFI declaration for Zig function
@[extern "zig_process_numbers"]
opaque zigProcessNumbers (arr : Array Nat) : IO (Array Nat)

-- Lean wrapper with type safety
def processWithZig (numbers : Array Nat) : IO (Array Nat) := do
  if numbers.isEmpty then
    return #[]
  zigProcessNumbers numbers
```

### Step 2: Implement in Zig

Create `zig/process.zig`:

```zig
const lean = @import("lean");
const std = @import("std");

/// Takes array of Lean Nat (boxed usize), doubles each element
export fn zig_process_numbers(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;  // IO world token (unused)
    defer lean.lean_dec_ref(arr);
    
    const size = lean.arraySize(arr);
    const result = lean.allocArray(size) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        
        // Check if it's a tagged pointer (small nat)
        if (lean.isScalar(elem)) {
            const val = lean.unboxUsize(elem);
            const doubled = lean.boxUsize(val * 2);
            lean.arraySet(result, i, doubled);
        } else {
            // Large Nat - just pass through
            lean.lean_inc_ref(elem);
            lean.arraySet(result, i, elem);
        }
    }
    
    return lean.ioResultMkOk(result);
}
```

### Step 3: Configure Build

Update your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"

@[default_target]
lean_lib «MyLib» where
  roots := #[`ZigFFI]

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  -- Link against Lean runtime
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
```

Add to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Import lean-zig bindings
    const lean_zig_dep = b.dependency("lean-zig", .{
        .target = target,
        .optimize = optimize,
    });
    const lean_module = lean_zig_dep.module("lean-zig");
    
    // Build your FFI library
    const lib = b.addStaticLibrary(.{
        .name = "leanzig",
        .root_source_file = .{ .path = "zig/process.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    lib.root_module.addImport("lean", lean_module);
    lib.linkLibC();
    b.installArtifact(lib);
}
```

### Step 4: Use in Lean

In `Main.lean`:

```lean
import MyLib.ZigFFI

def main : IO Unit := do
  let numbers := #[1, 2, 3, 4, 5]
  IO.println s!"Input: {numbers}"
  
  let doubled ← processWithZig numbers
  IO.println s!"Output: {doubled}"
  -- Expected: Output: #[2, 4, 6, 8, 10]
```

### Step 5: Build and Run

```bash
lake build
lake exe my_project
# Input: #[1, 2, 3, 4, 5]
# Output: #[2, 4, 6, 8, 10]
```

This example demonstrates:
- ✅ Passing arrays between Lean and Zig
- ✅ Proper reference counting with `defer`
- ✅ Boxing/unboxing scalar values
- ✅ Error handling with IO results
- ✅ Build system integration

---

## Examples

### String Processing

```zig
const lean = @import("lean");

export fn reverse_string(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(str);
    
    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;
    
    var buffer: [256]u8 = undefined;
    if (len > 256) {
        return lean.ioResultMkError(lean.lean_mk_string("string too long"));
    }
    
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buffer[len - 1 - i] = cstr[i];
    }
    
    const result = lean.lean_mk_string_from_bytes(&buffer, len);
    return lean.ioResultMkOk(result);
}
```

### Array Operations

```zig
export fn sum_array(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);
    
    const size = lean.arraySize(arr);
    var sum: usize = 0;
    
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);  // Unchecked for speed
        // Check if tagged pointer (bit 0 set)
        if (@intFromPtr(elem) & 1 == 1) {
            sum += lean.unboxUsize(elem);
        }
    }
    
    return lean.ioResultMkOk(lean.boxUsize(sum));
}
```

### Lazy Evaluation with Thunks

```zig
/// Create a pure thunk (already evaluated)
export fn createPureThunk(value: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Wrap value in thunk for lazy semantics
    const thunk = lean.lean_thunk_pure(value) orelse {
        lean.lean_dec_ref(value);
        const err = lean.lean_mk_string("thunk allocation failed");
        return lean.ioResultMkError(err);
    };
    
    return lean.ioResultMkOk(thunk);
}

/// Force evaluation of a thunk (borrowed access)
export fn forceThunk(thunk: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get cached value (borrowed reference)
    const value = lean.thunkGet(thunk);
    
    // Increment refcount to return owned reference
    lean.lean_inc_ref(value);
    
    return lean.ioResultMkOk(value);
}

/// Process thunk with ownership transfer
export fn consumeThunk(thunk: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get value with ownership (thunk consumed)
    const value = lean.lean_thunk_get_own(thunk);
    defer lean.lean_dec_ref(value);
    
    // Process the value
    if (lean.isScalar(value)) {
        const n = lean.unboxUsize(value);
        const doubled = lean.boxUsize(n * 2);
        return lean.ioResultMkOk(doubled);
    }
    
    // Return original for non-scalar
    lean.lean_inc_ref(value);
    return lean.ioResultMkOk(value);
}
```

**Lean side:**
```lean
-- Pure thunk creation
@[extern "createPureThunk"]
opaque createPureThunk (value : Nat) : IO (Thunk Nat)

-- Force evaluation
@[extern "forceThunk"]  
opaque forceThunk (t : @& Thunk Nat) : IO Nat

def example : IO Unit := do
  let thunk ← createPureThunk 42
  let value ← forceThunk thunk
  IO.println s!"Value: {value}"
```

### Asynchronous Tasks

```zig
/// Note: Full task spawning requires Lean IO runtime initialization.
/// This example shows the API structure for task operations.

/// Spawn an async computation (requires Lean-created closure)
export fn spawnComputation(closure: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Spawn with default priority and async mode
    const task = lean.taskSpawn(closure) orelse {
        lean.lean_dec_ref(closure);
        const err = lean.lean_mk_string("task spawn failed");
        return lean.ioResultMkError(err);
    };
    
    return lean.ioResultMkOk(task);
}

/// Map a function over a task result
export fn mapTask(task: lean.obj_arg, transform: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Chain transformation
    const mapped = lean.taskMap(task, transform) orelse {
        lean.lean_dec_ref(task);
        lean.lean_dec_ref(transform);
        const err = lean.lean_mk_string("task map failed");
        return lean.ioResultMkError(err);
    };
    
    return lean.ioResultMkOk(mapped);
}

/// Wait for task completion
export fn awaitTask(task: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Blocks until task completes
    const result = lean.lean_task_get_own(task);
    
    return lean.ioResultMkOk(result);
}
```

**Lean side:**
```lean
-- Task operations
@[extern "spawnComputation"]
opaque spawnComputation (f : Unit → Nat) : IO (Task Nat)

@[extern "mapTask"]
opaque mapTask (t : Task Nat) (f : Nat → Nat) : IO (Task Nat)

@[extern "awaitTask"]
opaque awaitTask (t : Task Nat) : IO Nat

def asyncExample : IO Unit := do
  let task ← spawnComputation (fun () => 42)
  let mapped ← mapTask task (· * 2)
  let result ← awaitTask mapped
  IO.println s!"Async result: {result}"
```

### Mutable References (ST Monad)

```zig
/// Increment a counter stored in a reference
export fn incrementCounter(ref: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get current value
    const current = lean.refGet(ref);
    const n = if (current) |val| 
        lean.unboxUsize(val)
    else 
        0;
    
    // Increment and store
    const new_value = lean.boxUsize(n + 1);
    lean.refSet(ref, new_value);
    
    // Return unit
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    return lean.ioResultMkOk(unit);
}

/// Swap values between two references
export fn swapRefs(ref1: lean.b_obj_arg, ref2: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get both values
    const val1 = lean.refGet(ref1);
    const val2 = lean.refGet(ref2);
    
    // Increment refcounts for swap
    if (val1) |v| lean.lean_inc_ref(v);
    if (val2) |v| lean.lean_inc_ref(v);
    
    // Swap (refSet automatically dec_refs old values)
    lean.refSet(ref1, val2);
    lean.refSet(ref2, val1);
    
    // Return unit
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    return lean.ioResultMkOk(unit);
}

/// Accumulate values in a reference
export fn accumulateInRef(ref: lean.b_obj_arg, value: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(value);
    
    const current = lean.refGet(ref);
    const current_val = if (current) |v| lean.unboxUsize(v) else 0;
    const new_val = lean.unboxUsize(value);
    
    const sum = lean.boxUsize(current_val + new_val);
    lean.refSet(ref, sum);
    
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    return lean.ioResultMkOk(unit);
}
```

**Lean side:**
```lean
-- ST monad reference operations
@[extern "incrementCounter"]
opaque incrementCounter (ref : @& STRef RealWorld Nat) : ST RealWorld Unit

@[extern "swapRefs"]
opaque swapRefs (r1 r2 : @& STRef RealWorld Nat) : ST RealWorld Unit

@[extern "accumulateInRef"]
opaque accumulateInRef (ref : @& STRef RealWorld Nat) (value : Nat) : ST RealWorld Unit

def stExample : IO Unit := do
  let result := (do
    let r ← ST.mkRef 10
    incrementCounter r
    incrementCounter r
    r.get
  )
  IO.println s!"Counter: {result}"  -- Prints 12
```

### Complete End-to-End: Lazy Counter with Persistence

Combining thunks and references for lazy initialization:

```zig
/// Lazy initialize a reference with computed value
export fn lazyInitRef(ref: lean.b_obj_arg, thunk: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Check if already initialized
    const current = lean.refGet(ref);
    if (current != null) {
        lean.lean_dec_ref(thunk);
        const unit = lean.allocCtor(0, 0, 0) orelse {
            const err = lean.lean_mk_string("allocation failed");
            return lean.ioResultMkError(err);
        };
        return lean.ioResultMkOk(unit);
    }
    
    // Force thunk evaluation
    const value = lean.lean_thunk_get_own(thunk);
    
    // Store in reference
    lean.refSet(ref, value);
    
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    return lean.ioResultMkOk(unit);
}
```

**Lean side:**
```lean
@[extern "lazyInitRef"]
opaque lazyInitRef (ref : @& STRef RealWorld (Option Nat)) (thunk : Thunk Nat) : ST RealWorld Unit

def lazyCounterExample : IO Unit := do
  let result := (do
    let ref ← ST.mkRef none
    let expensive := Thunk.pure (do
      -- Simulate expensive computation
      42
    )
    lazyInitRef ref expensive
    ref.get
  )
  IO.println s!"Lazy result: {result}"
```

## Troubleshooting

### Bindings Don't Match Lean Version

Clean and rebuild:
```bash
rm -rf .zig-cache zig-out
lake clean && lake build
```

### Segfault in Reference Counting

**Checklist:**
1. Don't `dec_ref` borrowed objects (`b_obj_arg`)
2. Don't forget to `inc_ref` when sharing
3. Don't use after `dec_ref`

**Debug:**
```bash
LEAN_DEBUG_RC=1 ./your_program
```

### Memory Leak

**Checklist:**
1. Every `obj_arg` must be `dec_ref`'d exactly once
2. Every `inc_ref` must have matching `dec_ref`
3. Every allocation must eventually be freed

**Debug:**
```bash
LEAN_CHECK_LEAKS=1 ./your_program
```

### Build Fails to Find Lean

Ensure `lean` is in PATH:
```bash
which lean
lean --print-prefix
```

## Version Synchronization

**The bindings always match your installed Lean version.** When you upgrade Lean:

```bash
elan update
lake build  # Automatically regenerates bindings
```

No manual updates to lean-zig needed!

## See Also

- **[API Reference](api.md)**: Complete function documentation
- **[Design](design.md)**: Architecture and implementation details
- **[Contributing](../CONTRIBUTING.md)**: Maintainer guide for handling Lean updates
