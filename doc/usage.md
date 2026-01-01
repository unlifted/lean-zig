# Usage Guide

Comprehensive guide for integrating `lean-zig` into your Lean 4 project.

## Quick Start

**Two ways to get started:**

### Option 1: Automated Setup (Recommended for New Projects)

Use the initialization script for instant setup:

```bash
git clone https://github.com/unlifted/lean-zig
cd lean-zig
./scripts/init-project.sh my-zig-project
cd my-zig-project
lake build && lake exe my-zig-project
```

This creates a working project with everything configured. See [scripts/README.md](../scripts/README.md) for details.

### Option 2: Manual Setup (For Existing Projects)

Follow the setup checklist below to add lean-zig to an existing Lean project.

---

## Setup Checklist

**Important**: Using lean-zig requires **two setup steps** beyond adding a dependency:
1. Copy and customize a `build.zig` template
2. Add an `extern_lib` target to your lakefile

The library then automatically generates bindings matching your Lean installation.

Follow these steps in order for a smooth setup:

### ☐ Step 1: Add Dependency

Add to your `lakefile.lean`:

```lean
require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"
```

### ☐ Step 2: Download Dependency

Run `lake build` to download lean-zig:

```bash
lake build  # May fail with "zig: command not found" - that's expected!
```

**Why this step?** `lake build` (not `lake update`) downloads Lake dependencies and makes the lean-zig package available in `.lake/packages/`.

### ☐ Step 3: Copy Build Template

Copy the build template to your project root:

```bash
cp .lake/packages/lean-zig/template/build.zig ./
```

**What this does**: Provides the Zig build configuration that handles binding generation, linking, and platform detection.

### ☐ Step 4: Customize Build Template

Open `build.zig` and find the `ZIG_FFI_SOURCE` constant at the top:

```zig
// ═══════════════════════════════════════════════════════════════════════════
// 🔧 CUSTOMIZATION POINT - Change this to point to your Zig FFI code:
// ═══════════════════════════════════════════════════════════════════════════
const ZIG_FFI_SOURCE = "zig/CHANGE_ME.zig"; // ← TODO: Update this path!
```

Replace the path with YOUR Zig source file location:

```zig
const ZIG_FFI_SOURCE = "zig/my_ffi.zig"; // ← Your file here
```

**Multi-file projects?** Just point to your root file - Zig automatically compiles any files you `@import`.

### ☐ Step 5: Add extern_lib to Lakefile

Add this to your `lakefile.lean`:

```lean
extern_lib libleanzig pkg := do
  let name := nameToStaticLib "leanzig"
  let oFile := pkg.buildDir / name
  
  proc {
    cmd := "zig"
    args := #["build"]
    cwd := pkg.dir
  }
  
  let srcFile := pkg.dir / "zig-out" / "lib" / name
  IO.FS.writeBinFile oFile (← IO.FS.readBinFile srcFile)
  
  return Job.pure oFile
```

**What this does**: Tells Lake to invoke `zig build` and link the resulting static library.

**What this does**: Tells Lake to invoke `zig build` and link the resulting static library.

### ☐ Step 6: Create Your Zig FFI Code

Create your Zig source file (e.g., `zig/my_ffi.zig`):

```zig
const lean = @import("lean");

export fn my_function(obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(obj);
    
    const result = lean.boxUsize(42);
    return lean.ioResultMkOk(result);
}
```

**Key points:**
- Import lean-zig with `const lean = @import("lean");`
- Export functions with `export fn function_name(...)`
- Use `defer` for automatic cleanup of owned objects
- Return IO results with `ioResultMkOk` or `ioResultMkError`

### ☐ Step 7: Declare FFI Function in Lean

In your Lean code (e.g., `Main.lean`):

```lean
@[extern "my_function"]
opaque myFunction (value : Nat) : IO Nat

def main : IO Unit := do
  let result ← myFunction 42
  IO.println s!"Result: {result}"
```

**What this does**: The `@[extern "my_function"]` attribute links the Lean declaration to your Zig function.

### ☐ Step 8: Build

Run `lake build`:

```bash
lake build
```

**What happens:**
1. Lake invokes `zig build` via the `extern_lib` target
2. Zig generates bindings from your Lean installation's `lean.h`
3. Zig compiles your FFI code and links against Lean runtime
4. Lake compiles your Lean code and links the Zig static library
5. Final executable is produced in `.lake/build/bin/`

### ☐ Step 9: Run

```bash
lake exe your-project-name
```

**Troubleshooting:** See [Common Issues](#troubleshooting) below if you encounter errors.

---

## Detailed Setup Instructions

For more control and understanding, here's the detailed breakdown:

### 1. Add Dependency

### 5. Build and Run

```bash
lake build
```

The `build.zig` template automatically:
- Detects your Lean installation
- Generates FFI bindings from `lean.h` using `translateC`
- Links against Lean runtime
- Handles platform differences (Linux/macOS/Windows)
- Adapts to Lean/Zig version differences

**Bindings always match your installed Lean version.**

## Build Integration

When you add `lean-zig` as a dependency, Lake downloads it to `.lake/packages/lean-zig/`. The library provides a template `build.zig` you copy once to your project to set up the Zig build system.

### Step-by-Step Setup

#### 1. Copy the Template

After adding the dependency and running `lake update`, copy the template:

```bash
cp .lake/packages/lean-zig/template/build.zig ./
```

#### 2. Customize the Template

Open `build.zig` and update the `ZIG_FFI_SOURCE` constant at the top:

```zig
// ═══════════════════════════════════════════════════════════════════════════
// 🔧 CUSTOMIZATION POINT - Change this to point to your Zig FFI code:
// ═══════════════════════════════════════════════════════════════════════════
const ZIG_FFI_SOURCE = "zig/my_ffi.zig"; // ← Change this path
```

**Key customization points:**
- **ZIG_FFI_SOURCE** (top of file): Set to your main Zig file (e.g., `"zig/ffi.zig"`)
- **lib.name** (optional): Change library name from `"leanzig"` to match your project

The template automatically:
- Detects your Lean installation (`lean --print-prefix`)
- Generates FFI bindings from `lean.h` using `translateC`
- Links against Lean runtime libraries
- Sets up the `lean` module for imports
- Configures glibc 2.27 compatibility (for Zig 0.15+)

#### 3. Configure Your Lakefile

Add an `extern_lib` target that invokes Zig build:

```lean
extern_lib libleanzig pkg := do
  let name := nameToStaticLib "leanzig"
  let oFile := pkg.buildDir / name
  
  -- Invoke zig build
  proc {
    cmd := "zig"
    args := #["build"]
    cwd := pkg.dir
  }
  
  -- Copy result to Lake's expected location
  let srcFile := pkg.dir / "zig-out" / "lib" / name
  IO.FS.writeBinFile oFile (← IO.FS.readBinFile srcFile)
  
  return Job.pure oFile
```

**Important**: The library name must match:
- `nameToStaticLib "leanzig"` in lakefile
- `.name = "leanzig"` in build.zig (line 24)
- Your `extern_lib` declaration name (`libleanzig` above)

#### 4. Write Your Zig FFI Code

Create your Zig source file (e.g., `zig/my_ffi.zig`):

```zig
const lean = @import("lean");

export fn my_function(obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(obj);
    
    // Your logic here
    const result = lean.boxUsize(42);
    return lean.ioResultMkOk(result);
}
```

**For multi-file projects**, just point to the root file in `build.zig` - Zig automatically compiles imported files:

```
zig/
├── ffi.zig        ← Root (set as root_source_file in build.zig)
├── helpers.zig    ← Imported by ffi.zig via @import("helpers.zig")
└── math.zig       ← Imported by ffi.zig via @import("math.zig")
```

See [Example 11](../examples/11-multi-file/) for a complete multi-file demonstration.

#### 5. Build and Run

```bash
lake build
```

Zig will automatically:
- Generate bindings from your Lean installation's `lean.h`
- Compile your FFI code with the lean-zig module available
- Link against Lean runtime
- Produce a static library for Lake to consume

### Template Details

The template `build.zig` (~120 lines) handles:

**Version Detection and Compatibility:**
- **Tested Versions**: Lean 4.25.0-4.26.0, Zig 0.14.0-0.15.2
- **Auto-detection**: Runs `lean --print-prefix` at build time
- **Platform awareness**: Automatically handles Linux/macOS/Windows differences
- **glibc compatibility**: Sets glibc 2.27 target for Zig 0.15+ on Linux
- **Windows library linking**: Uses direct `.a` file linking for MinGW compatibility

**Automatic Configuration:**
- Lean installation detection via `lean --print-prefix`
- Binding generation from `lean.h` using `translateC`
- Runtime library linking (`-lleanrt`, `-lleanshared`, `-lgmp`)

**Platform Compatibility:**
- **Linux**: glibc 2.27 target (prevents Zig 0.15+ copy_file_range errors)
- **macOS**: Standard Unix library linking
- **Windows**: MinGW direct .a linking (6 required libraries)

**Module Setup:**
- Exposes `lean` module for `@import("lean")` in your code
- Manages dependencies automatically

**Build Artifacts:**
- Produces `zig-out/lib/libleanzig.a` (or platform equivalent)
- Lake copies this to its build directory

### Version Compatibility Notes

The template is **version-aware** and handles differences automatically:

1. **Zig 0.14 vs 0.15**: Automatically sets glibc 2.27 on Linux for 0.15+
2. **Lean 4.25 vs 4.26**: Same library names (libleanrt, libleanshared)
3. **Windows**: Uses direct .a linking instead of -l flags
4. **Binding Generation**: `translateC` ensures perfect match with your Lean version

**When upgrading Lean or Zig:**
- Just run `lake build` - the template adapts automatically
- If you see link errors, check the troubleshooting section below
- Report version-specific issues on GitHub

### Troubleshooting

**"Unknown identifier" errors in lakefile:**
- Ensure you're using Lake 5.0+ (Lean 4.26.0+)
- Use `extern_lib name pkg := do` syntax (not `where`)

**"lean: command not found" during build:**
- Ensure `lean` is in your PATH: `which lean`
- Check installation: `lean --version`

**"undefined reference to copy_file_range" on older Linux:**
- Zig 0.15 requires glibc 2.38 symbols
- Template includes compatibility shim - check glibc target in build.zig line 38

**Library name mismatch:**
- `nameToStaticLib "leanzig"` (lakefile) must match `.name = "leanzig"` (build.zig)
- `extern_lib libleanzig` just adds "lib" prefix per convention

**Bindings don't match Lean version:**
- Clean rebuild: `rm -rf .zig-cache zig-out && lake clean && lake build`
- Template regenerates bindings from your installed Lean each build

## Frequently Asked Questions

### Do I need different build.zig files for different Lean or Zig versions?

**No.** The template automatically adapts to your environment at build time:

- Detects your platform (Linux/macOS/Windows)
- Handles Zig version differences (0.14 vs 0.15 glibc compatibility)
- Works with Lean 4.25.0 through 4.26.0+ (same library structure)
- Uses `translateC` to generate bindings matching YOUR installed Lean

**When you upgrade:** Just run `lake build` - no template changes needed (within tested version ranges).

See [Version Compatibility Guide](version-compatibility.md) for details on tested combinations and future upgrade procedures.

### What if my Zig project has multiple files?

**You only specify the root file.** Zig's build system automatically compiles any files imported via `@import()`.

**Example structure:**
```
zig/
├── ffi.zig        ← Root file (set in build.zig)
├── helpers.zig    ← Imported by ffi.zig
└── math.zig       ← Imported by ffi.zig
```

**In build.zig:**
```zig
const ffi_module = b.createModule(.{
    .root_source_file = b.path("zig/ffi.zig"),  // ← Just the root!
    // ...
});
```

**In ffi.zig:**
```zig
const helpers = @import("helpers.zig");  // Auto-compiled
const math = @import("math.zig");        // Auto-compiled

export fn my_function(...) { ... }
```

See [Example 11 - Multi-File Projects](../examples/11-multi-file/) for a complete demonstration.

### When would I need to update build.zig?

**Rarely.** The template handles version differences automatically. You'd only update if:

1. **Lean major version change** (e.g., 5.0.0) changes library names or structure
2. **Zig breaking change** (e.g., 1.0.0) alters build system API
3. **New platform support** requires different linking strategy

lean-zig maintainers will publish updated templates when needed and document in [CHANGELOG](../CHANGELOG.md).

### Can I customize build.zig beyond the root source file?

**Yes!** Common customizations:

```zig
// Different library name
const lib = b.addLibrary(.{
    .name = "myffi",  // ← Custom name
    .root_module = ffi_module,
    .linkage = .static,
});

// Additional Zig dependencies
const my_dep = b.dependency("my-lib", .{});
ffi_module.addImport("mylib", my_dep.module("mylib"));

// Custom build options
const custom_feature = b.option(bool, "feature", "Enable feature") orelse false;
const options = b.addOptions();
options.addOption(bool, "feature_enabled", custom_feature);
ffi_module.addOptions("build_options", options);
```

The template is just a starting point - customize as needed for your project!

## Troubleshooting (Original Section)

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

### External Objects: Native Resource Management

External objects wrap native resources (files, sockets, database connections) with automatic cleanup.

```zig
const std = @import("std");
const lean = @import("lean-zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Native resource type
const FileHandle = struct {
    fd: std.fs.File,
    path: []const u8,
    bytes_read: usize,
};

// Finalizer: cleanup native resources
fn fileFinalize(data: *anyopaque) callconv(.c) void {
    const handle: *FileHandle = @ptrCast(@alignCast(data));
    handle.fd.close();
    allocator.free(handle.path);
    allocator.destroy(handle);
}

// Register class once at startup
var file_class: *lean.ExternalClass = undefined;

export fn initFileClass() void {
    file_class = lean.registerExternalClass(fileFinalize, null);
}

// Open file as external object
export fn openFile(path_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(path_obj);
    
    const path_str = lean.stringCstr(path_obj);
    const path_len = lean.stringSize(path_obj) - 1;
    
    // Allocate native handle
    const handle = allocator.create(FileHandle) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    // Open file
    handle.fd = std.fs.cwd().openFile(path_str[0..path_len], .{}) catch {
        allocator.destroy(handle);
        const err = lean.lean_mk_string("file open failed");
        return lean.ioResultMkError(err);
    };
    
    // Copy path
    handle.path = allocator.dupe(u8, path_str[0..path_len]) catch {
        handle.fd.close();
        allocator.destroy(handle);
        const err = lean.lean_mk_string("path copy failed");
        return lean.ioResultMkError(err);
    };
    
    handle.bytes_read = 0;
    
    // Wrap in external object
    const ext = lean.allocExternal(file_class, handle) orelse {
        handle.fd.close();
        allocator.free(handle.path);
        allocator.destroy(handle);
        const err = lean.lean_mk_string("external allocation failed");
        return lean.ioResultMkError(err);
    };
    
    return lean.ioResultMkOk(ext);
}

// Read from file
export fn readFile(file_obj: lean.obj_arg, n_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(file_obj);
    defer lean.lean_dec_ref(n_obj);
    
    // Extract native handle
    const handle: *FileHandle = @ptrCast(@alignCast(
        lean.getExternalData(file_obj)
    ));
    
    const n = lean.unboxUsize(n_obj);
    const buffer = allocator.alloc(u8, n) catch {
        const err = lean.lean_mk_string("buffer alloc failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(buffer);
    
    const bytes_read = handle.fd.read(buffer) catch {
        const err = lean.lean_mk_string("read failed");
        return lean.ioResultMkError(err);
    };
    
    handle.bytes_read += bytes_read;
    
    const result = lean.lean_mk_string_from_bytes(buffer.ptr, bytes_read);
    return lean.ioResultMkOk(result);
}

// Get stats
export fn getFileStats(file_obj: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const handle: *FileHandle = @ptrCast(@alignCast(
        lean.getExternalData(file_obj)
    ));
    
    // Create struct with stats
    const stats = lean.allocCtor(0, 0, @sizeOf(usize)) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    lean.ctorSetUsize(stats, 0, handle.bytes_read);
    return lean.ioResultMkOk(stats);
}
```

**Lean side:**
```lean
-- Initialize at startup
@[extern "initFileClass"]
opaque initFileClass : IO Unit

-- File handle type (opaque to Lean)
opaque FileHandle : Type

@[extern "openFile"]
opaque openFile (path : String) : IO FileHandle

@[extern "readFile"]
opaque readFile (file : FileHandle) (n : USize) : IO String

@[extern "getFileStats"]
opaque getFileStats (file : @& FileHandle) : IO USize

def fileExample : IO Unit := do
  initFileClass
  
  let file ← openFile "test.txt"
  let content ← readFile file 1024
  let stats ← getFileStats file
  
  IO.println s!"Read {stats} bytes"
  IO.println s!"Content: {content}"
  -- file automatically cleaned up when refcount reaches 0
```

**Key Benefits:**
- Automatic resource cleanup via finalizer
- Type-safe native data access
- Zero-copy native → Lean integration
- Proper error handling with IO results

---

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
