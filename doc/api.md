# Lean-Zig API Reference

Complete API documentation for the `lean.zig` module, organized by functional category.

## Table of Contents

1. [Core Types](#core-types)
2. [Memory Management](#memory-management)
3. [Type Inspection](#type-inspection)
4. [Boxing/Unboxing](#boxingunboxing)
5. [Constructors](#constructors)
6. [Strings](#strings)
7. [Arrays](#arrays)
8. [Scalar Arrays](#scalar-arrays)
9. [Closures](#closures)
10. [Thunks](#thunks)
11. [Tasks](#tasks)
12. [References](#references)
13. [External Objects](#external-objects)
14. [IO Results](#io-results)

---

## Core Types

### Object Structures

#### `Object`
Base header for all Lean heap objects (8 bytes).

**Fields:**
- `m_rc: i32` - Reference count (negative for multi-threaded objects)
- `m_cs_sz: u16` - Byte size for small objects, 0 for large objects
- `m_other: u8` - Auxiliary data (e.g., number of object fields for constructors)
- `m_tag: u8` - Type tag (0-243 for constructors, higher values for special types)

#### `StringObject`
UTF-8 encoded string with null terminator.

**Fields:**
- `m_header: Object`
- `m_size: usize` - Byte count including null terminator
- `m_capacity: usize` - Allocated buffer size
- `m_length: usize` - Unicode code point count

#### `ArrayObject`
Dynamically-sized object array.

**Fields:**
- `m_header: Object`
- `m_size: usize` - Current element count
- `m_capacity: usize` - Maximum elements before reallocation

#### `ScalarArrayObject`
Homogeneous primitive array (ByteArray, FloatArray, etc.).

**Fields:**
- `m_header: Object`
- `m_size: usize` - Element count
- `m_capacity: usize` - Maximum elements
- `m_elem_size: usize` - Bytes per element

#### `ThunkObject`
Lazy computation with cached result.

**Fields:**
- `m_header: Object`
- `m_value: ?*anyopaque` - Cached result (null until first evaluation, atomic in C)
- `m_closure: ?*anyopaque` - Closure to evaluate (atomic in C)

**Thread Safety:** Value and closure fields use atomic operations in the Lean runtime for concurrent evaluation.

#### `RefObject`
Mutable reference for ST (state thread) monad.

**Fields:**
- `m_header: Object`
- `m_value: obj_arg` - Current value

**Usage:** References provide mutable cells in the ST monad for single-threaded local mutation.

#### `ObjectHeader`
**Visibility:** Public (as of Phase 5) for advanced memory management.

Direct access to the object header allows manual initialization of specialized object types (e.g., RefObject in tests). Use with caution - improper header initialization can cause runtime crashes.

#### `ExternalClass`
External class descriptor for managing native resources.

**Fields:**
- `m_finalize: ?*const fn(*anyopaque) callconv(.c) void` - Called when object freed
- `m_foreach: ?*const fn(*anyopaque, b_obj_arg) callconv(.c) void` - GC visitor for held Lean objects

**Usage:** Registered once per native type at startup. Finalizer cleans up resources when object's refcount reaches zero.

#### `ExternalObject`
Wrapper for arbitrary native data structures.

**Fields:**
- `m_header: Object` - Standard Lean object header
- `m_class: *ExternalClass` - Class descriptor with finalizer
- `m_data: *anyopaque` - Pointer to native data

**Usage:** Wraps file handles, database connections, GPU buffers, or any native resource needing lifetime management.

### Ownership Types

- **`obj_arg`** - Owned pointer, caller transfers ownership
- **`b_obj_arg`** - Borrowed pointer, caller retains ownership
- **`obj_res`** - Result pointer, callee transfers ownership

### Tag Constants

```zig
Tag.max_ctor: u8 = 243    // Constructors use tags 0..243
Tag.closure: u8 = 245     // Function closure
Tag.array: u8 = 246       // Object array
Tag.sarray: u8 = 247      // Scalar array
Tag.string: u8 = 249      // UTF-8 string
Tag.thunk: u8 = 251       // Lazy computation
Tag.task: u8 = 252        // Async task
Tag.ref: u8 = 253         // Mutable reference
Tag.external: u8 = 254    // Foreign object
```

---

## Memory Management

### Reference Counting

#### `lean_inc_ref(o: obj_arg) void`
Increment object's reference count. Call when storing an additional reference.

#### `lean_dec_ref(o: obj_arg) void`
Decrement object's reference count. May free the object if count reaches zero.

**Example:**
```zig
const obj = lean.allocCtor(0, 0, 0);
lean.lean_inc_ref(obj);  // Now rc = 2
lean.lean_dec_ref(obj);  // Now rc = 1
lean.lean_dec_ref(obj);  // Freed
```

### Multi-Threading Support

Lean objects support two refcounting modes:
- **Single-threaded (ST)**: Fast, non-atomic refcount operations (refcount > 0)
- **Multi-threaded (MT)**: Atomic refcount operations for thread safety (refcount < 0)

#### `lean_inc_ref_n(o: obj_arg, n: usize) void`
Bulk increment reference count by N.

**When to use:**
- Sharing objects across multiple threads
- Bulk reference increments for performance
- Creating N copies of a reference

**Performance:** 2-4 CPU instructions depending on ST/MT status:
- ST objects: Simple addition
- MT objects: Atomic subtraction (MT refcounts are negative in Lean's model)

**Safety:**
- NULL pointers safely ignored
- Tagged pointers (scalars) safely ignored
- Uses atomic operations automatically for MT objects

**Example:**
```zig
// Sharing object across 3 threads
const obj = lean.allocCtor(0, 1, 0);
lean.markMt(obj);  // Convert to MT before sharing

// Increment refcount by 3 (one for each thread)
lean.lean_inc_ref_n(obj, 3);

// Each thread can now safely use the object
// Each thread calls lean_dec_ref when done
```

#### `isMt(o: b_obj_arg) bool`
Check if object uses multi-threaded reference counting.

**Returns:** `true` if MT (refcount < 0), `false` if ST

**Notes:**
- Scalars are never MT (no refcount)
- MT objects have atomic operation overhead
- Check before assuming in-place mutation is safe

**Example:**
```zig
if (lean.isMt(obj)) {
    // Object is shared, must use thread-safe operations
    lean.lean_inc_ref(obj);  // Uses atomics internally
} else {
    // Object is exclusive, can mutate directly
    lean.ctorSet(obj, 0, new_value);
}
```

#### `markMt(o: obj_arg) void`
Convert single-threaded object to multi-threaded mode.

**Preconditions:**
- Must have exclusive access (refcount == 1)
- Must be called BEFORE sharing across threads

**Effect:**
- Converts refcount to negative (MT mode)
- All subsequent refcount operations use atomics
- Conversion is permanent (cannot convert back to ST)

**Example:**
```zig
const obj = lean.allocCtor(0, 1, 0);

// Before sharing with other threads, mark as MT
lean.markMt(obj);

// Now safe to share across threads
spawn_thread_with_object(obj);
```

**Important:** Failure to call `markMt` before sharing will cause data races and memory corruption!

---

## Type Inspection

All inspection functions take `b_obj_arg` (borrowed) and return `bool`.

### Runtime Type Checks

- **`isScalar(o)`** - True if object is a tagged scalar (not heap-allocated)
- **`isCtor(o)`** - True if object is a constructor (includes scalars)
- **`isString(o)`** - True if object is a Lean string
- **`isArray(o)`** - True if object is an object array
- **`isSarray(o)`** - True if object is a scalar array
- **`isClosure(o)`** - True if object is a closure
- **`isThunk(o)`** - True if object is a thunk
- **`isTask(o)`** - True if object is a task
- **`isRef(o)`** - True if object is a mutable reference
- **`isExternal(o)`** - True if object is external (foreign)
- **`isMpz(o)`** - True if object is a big integer

### Sharing and Exclusivity

- **`isExclusive(o)`** - True if reference count == 1 (can mutate in-place)
- **`isShared(o)`** - True if reference count > 1 (must copy to mutate)

### Meta Functions

- **`objTag(o)`** - Returns the tag byte (type identifier)
- **`ptrTag(o)`** - Returns low bit (0 for heap, 1 for scalar)

**Example:**
```zig
if (lean.isExclusive(array)) {
    // Can mutate in-place
    lean.arraySet(array, i, new_value);
} else {
    // Must copy first
    const new_array = copy_array(array);
    lean.arraySet(new_array, i, new_value);
}
```

---

## Boxing/Unboxing

Lean uses tagged pointers for small scalars: `(value << 1) | 1`.

### Integer Boxing

| Function | Type | Notes |
|----------|------|-------|
| `boxUsize(n: usize)` → `obj_res` | USize/Nat | Panics if n ≥ 2^63 |
| `unboxUsize(o)` → `usize` | USize/Nat | Precondition: `isScalar(o)` |
| `boxUint32(n: u32)` → `obj_res` | UInt32 | - |
| `unboxUint32(o)` → `u32` | UInt32 | - |
| `boxUint64(n: u64)` → `obj_res` | UInt64 | Panics if n ≥ 2^63 |
| `unboxUint64(o)` → `u64` | UInt64 | - |

### Float Boxing

Floats require heap allocation (can't use tagged pointers).

| Function | Type | Allocation |
|----------|------|------------|
| `boxFloat(f: f64)` → `obj_res` | Float | Heap (ctor + scalar) |
| `unboxFloat(o)` → `f64` | Float | - |
| `boxFloat32(f: f32)` → `obj_res` | - | Heap (ctor + scalar) |
| `unboxFloat32(o)` → `f32` | - | - |

**Example:**
```zig
const nat_value = lean.boxUsize(42);
const float_value = lean.boxFloat(3.14159);

if (lean.isScalar(nat_value)) {
    const n = lean.unboxUsize(nat_value);
}
```

---

## Constructors

Constructors represent values of inductive types. Memory layout:
```
[Object header][object_fields...][scalar_fields...]
```

### Allocation

#### `allocCtor(tag: u8, num_objs: u8, scalar_sz: usize) obj_res`
Allocate a constructor.

**Parameters:**
- `tag` - Constructor variant (0 for first, 1 for second, etc.)
- `num_objs` - Number of object (pointer) fields
- `scalar_sz` - Total byte size of scalar fields

**Example:**
```zig
// Create Option.some with one field
const some = lean.allocCtor(1, 1, 0);
lean.ctorSet(some, 0, value);

// Create tuple (UInt32, Float)
const pair = lean.allocCtor(0, 0, @sizeOf(u32) + @sizeOf(f64));
lean.ctorSetUint32(pair, 0, 42);
lean.ctorSetFloat(pair, @sizeOf(u32), 3.14);
```

### Object Field Access

| Function | Description |
|----------|-------------|
| `ctorNumObjs(o)` → `u8` | Get number of object fields |
| `ctorGet(o, i)` → `obj_arg` | Get object field at index (borrowed) |
| `ctorSet(o, i, v)` | Set object field at index (transfers ownership) |
| `ctorObjCptr(o)` → `[*]obj_arg` | Get pointer to object fields array |

### Scalar Field Access

All scalar accessors take a byte `offset` parameter.

| Getters | Setters |
|---------|---------|
| `ctorGetUint8(o, offset)` → `u8` | `ctorSetUint8(o, offset, v)` |
| `ctorGetUint16(o, offset)` → `u16` | `ctorSetUint16(o, offset, v)` |
| `ctorGetUint32(o, offset)` → `u32` | `ctorSetUint32(o, offset, v)` |
| `ctorGetUint64(o, offset)` → `u64` | `ctorSetUint64(o, offset, v)` |
| `ctorGetUsize(o, offset)` → `usize` | `ctorSetUsize(o, offset, v)` |
| `ctorGetFloat(o, offset)` → `f64` | `ctorSetFloat(o, offset, v)` |
| `ctorGetFloat32(o, offset)` → `f32` | `ctorSetFloat32(o, offset, v)` |

### Utilities

- **`ctorScalarCptr(o)`** → `[*]u8` - Get pointer to scalar field region
- **`ctorSetTag(o, tag)`** - Change constructor variant
- **`ctorRelease(o, num_objs)`** - Dec_ref all fields without freeing

**Example:**
```zig
// Access complex constructor
const ctor = get_some_ctor();
const num_objs = lean.ctorNumObjs(ctor);

// Get object fields
const first_obj = lean.ctorGet(ctor, 0);

// Get scalar at offset 0
const id = lean.ctorGetUint64(ctor, 0);
const score = lean.ctorGetFloat(ctor, 8);
```

---

## Strings

Lean strings are UTF-8 encoded with null terminator.

### Creation

- **`lean_mk_string(s: [*:0]const u8)`** → `obj_res` - From C string
- **`lean_mk_string_from_bytes(s: [*]const u8, sz: usize)`** → `obj_res` - From bytes

### Access

| Function | Returns | Description |
|----------|---------|-------------|
| `stringCstr(o)` | `[*]const u8` | Pointer to UTF-8 data |
| `stringSize(o)` | `usize` | Byte size (includes null terminator) |
| `stringLen(o)` | `usize` | Unicode code point length |
| `stringCapacity(o)` | `usize` | Allocated buffer size |
| `stringGetByteFast(o, i)` | `u8` | Get byte (no bounds check) |

### Comparison

| Function | Returns | Description |
|----------|---------|-------------|
| `stringEq(a, b)` | `bool` | Bytewise equality |
| `stringNe(a, b)` | `bool` | Bytewise inequality |
| `stringLt(a, b)` | `bool` | Lexicographic less-than |

**Example:**
```zig
const str = lean.lean_mk_string_from_bytes("Hello", 5);
defer lean.lean_dec_ref(str);

const cstr = lean.stringCstr(str);
const len = lean.stringSize(str) - 1; // Exclude null
const slice: []const u8 = cstr[0..len];

if (lean.stringEq(str, other)) {
    // Strings are equal
}
```

---

## Arrays

Object arrays store pointers to Lean objects.

### Creation

| Function | Description |
|----------|-------------|
| `allocArray(capacity)` → `obj_res` | Allocate with size=0 |
| `mkArrayWithSize(cap, size)` → `obj_res` | Allocate with initial size |

### Access

| Function | Description |
|----------|-------------|
| `arraySize(o)` → `usize` | Current element count |
| `arrayCapacity(o)` → `usize` | Maximum before reallocation |
| `arrayGet(o, i)` → `obj_arg` | Get element (borrowed) |
| `arrayGetBorrowed(o, i)` → `obj_arg` | Alias of `arrayGet` |
| `arraySet(o, i, v)` | Set element (transfers ownership) |
| `arrayCptr(o)` → `[*]obj_arg` | Pointer to elements |

### Unchecked Access (Fast)

No bounds checking - **use with caution**.

- **`arrayUget(o, i)`** → `obj_arg` - Unchecked get
- **`arrayUset(o, i, v)`** - Unchecked set

### Mutation

| Function | Description |
|----------|-------------|
| `arraySetSize(o, new_size)` | Directly modify size field |
| `arraySwap(o, i, j)` | Swap two elements |

**Example:**
```zig
const arr = lean.mkArrayWithSize(10, 3) orelse return error;
defer lean.lean_dec_ref(arr);

// Set elements
lean.arraySet(arr, 0, lean.boxUsize(100));
lean.arraySet(arr, 1, lean.boxUsize(200));
lean.arraySet(arr, 2, lean.boxUsize(300));

// Iterate
const size = lean.arraySize(arr);
var i: usize = 0;
while (i < size) : (i += 1) {
    const elem = lean.arrayUget(arr, i);
    // Process elem...
}
```

---

## Scalar Arrays

ByteArray, FloatArray, etc. Store raw values without indirection.

### Access

| Function | Returns | Description |
|----------|---------|-------------|
| `sarraySize(o)` | `usize` | Element count |
| `sarrayCapacity(o)` | `usize` | Maximum elements |
| `sarrayElemSize(o)` | `usize` | Bytes per element |
| `sarrayCptr(o)` | `[*]u8` | Pointer to data |

### Mutation

- **`sarraySetSize(o, new_size)`** - Modify size field

**Example:**
```zig
// Assuming we have a ByteArray
const byte_array = get_byte_array();
const data = lean.sarrayCptr(byte_array);
const size = lean.sarraySize(byte_array);

const bytes: [*]u8 = @ptrCast(data);
for (bytes[0..size]) |byte| {
    // Process byte...
}
```

---

## Closures

Closures are partially-applied functions with captured environment.

### Creation

- **`lean_alloc_closure(fun, arity, num_fixed)`** → `obj_res` - Allocate closure

**Parameters:**
- `fun` - Function pointer
- `arity` - Total parameter count
- `num_fixed` - Number of captured arguments

### Access

| Function | Returns | Description |
|----------|---------|-------------|
| `closureArity(o)` | `u16` | Total parameters expected |
| `closureNumFixed(o)` | `u16` | Captured arguments |
| `closureFun(o)` | `*const anyopaque` | Function pointer |
| `closureGet(o, i)` | `obj_arg` | Get fixed arg at index |
| `closureSet(o, i, v)` | - | Set fixed arg at index |
| `closureArgCptr(o)` | `[*]obj_arg` | Pointer to fixed args |

**Example:**
```zig
// Create closure for partially applied function
const closure = lean.lean_alloc_closure(my_fn, 3, 1);
lean.closureSet(closure, 0, first_arg);
// Now closure waits for 2 more arguments
```

---

## Thunks

Thunks represent lazy computations evaluated on first access. Value is computed once and cached for subsequent calls.

### Object Structure

See [`ThunkObject`](#thunkobject) in Core Types.

### Creation

#### `lean_thunk_pure(v: obj_arg) obj_res`
Create a thunk with pre-evaluated value (no closure needed).

**Parameters:**
- `v` - Value to cache (takes ownership)

**Returns:**
- Thunk object with cached value, or null on allocation failure

**Performance:** Inline function, zero-cost abstraction.

**Example:**
```zig
const value = lean.boxUsize(42);
const thunk = lean.lean_thunk_pure(value) orelse return error.AllocationFailed;
defer lean.lean_dec_ref(thunk);
```

### Evaluation

#### `thunkGet(t: b_obj_arg) obj_arg`
Get cached value (borrowed reference).

**Preconditions:**
- Input must be non-null thunk object
- Passing null triggers unreachable panic

**Behavior:**
- **Fast path:** If value cached, returns immediately (inline)
- **Slow path:** If not evaluated, forwards to `lean_thunk_get_core` for thread-safe evaluation

**Returns:** Borrowed reference to cached value

**Performance:** Inline fast path, zero overhead for cached values.

**Example:**
```zig
const value = lean.thunkGet(thunk);
if (lean.isScalar(value)) {
    const n = lean.unboxUsize(value);
    // Use n...
}
```

#### `lean_thunk_get_own(t: obj_arg) obj_res`
Get cached value with ownership transfer.

**Parameters:**
- `t` - Thunk object (takes ownership)

**Returns:**
- Owned reference to cached value (increments refcount)

**Behavior:**
- Evaluates thunk if not cached
- Increments value refcount before returning
- Caller must `dec_ref` returned value

**Performance:** Inline implementation.

**Example:**
```zig
const value = lean.lean_thunk_get_own(thunk);
defer lean.lean_dec_ref(value);
// thunk was consumed, don't dec_ref it
```

#### `lean_thunk_get_core(t: b_obj_arg) obj_arg`
Forwarded to Lean runtime for thread-safe evaluation.

**Usage:** Called automatically by `thunkGet` when value not cached. Rarely called directly.

---

## Tasks

Tasks represent asynchronous computations managed by Lean's thread pool.

### Core Functions (Forwarded to Runtime)

All task functions require full Lean runtime initialization.

#### `lean_task_spawn_core(fn: obj_arg, prio: c_uint, async: u8) obj_res`
Spawn asynchronous task.

**Parameters:**
- `fn` - Closure to execute (takes ownership)
- `prio` - Priority (0 = normal, higher = more important)
- `async` - Keep-alive mode: 0=wait for result before exit, 1=background

**Returns:** Task object, or null on failure

**Thread Safety:** Fully thread-safe via Lean runtime.

#### `lean_task_get(t: b_obj_arg) obj_arg`
Wait for task result (borrowed).

**Blocks** until task completes.

**Returns:** Borrowed reference to result

#### `lean_task_get_own(t: obj_arg) obj_res`
Wait for task result (owned).

**Parameters:**
- `t` - Task object (takes ownership)

**Blocks** until task completes.

**Returns:** Owned reference to result (caller must `dec_ref`)

#### `lean_task_map_core(t: obj_arg, f: obj_arg, prio: c_uint, async: u8) obj_res`
Map function over task result.

**Parameters:**
- `t` - Task (takes ownership)
- `f` - Mapping function closure (takes ownership)
- `prio` - Priority for mapped task
- `async` - Keep-alive mode

**Returns:** New task computing `f(result of t)`

**Chaining:** Allows building computation pipelines.

#### `lean_task_bind_core(t: obj_arg, f: obj_arg, prio: c_uint, async: u8) obj_res`
Monadic bind for task sequencing.

**Parameters:**
- `t` - Task (takes ownership)
- `f` - Function returning task closure (takes ownership)
- `prio` - Priority
- `async` - Keep-alive mode

**Returns:** Task that waits for `t`, then spawns task from `f(result)`

**Usage:** Complex async workflows with dependent tasks.

### Convenience Wrappers

Default priority=0, async=true:

#### `taskSpawn(fn: obj_arg) obj_res`
Spawn task with default options.

**Equivalent to:** `lean_task_spawn_core(fn, 0, 1)`

#### `taskMap(t: obj_arg, f: obj_arg) obj_res`
Map function with default options.

**Equivalent to:** `lean_task_map_core(t, f, 0, 1)`

#### `taskBind(t: obj_arg, f: obj_arg) obj_res`
Bind with default options.

**Equivalent to:** `lean_task_bind_core(t, f, 0, 1)`

### Complete Example

```zig
// Spawn async computation
const task1 = lean.taskSpawn(computation_closure);

// Chain another task
const task2 = lean.taskMap(task1, transform_fn);

// Sequence dependent task
const task3 = lean.taskBind(task2, dependent_fn);

// Wait for final result
const result = lean.lean_task_get_own(task3);
defer lean.lean_dec_ref(result);

// Process result...
```

**Note:** Task testing requires full Lean IO runtime initialization. See test suite for API validation examples.

---

## References

Mutable references for the ST (state thread) monad. Provides single-threaded local mutation.

### Object Structure

See [`RefObject`](#refobject) in Core Types.

### Access Functions

#### `refGet(r: b_obj_arg) obj_arg`
Get current value (borrowed).

**Parameters:**
- `r` - Reference object (borrowed)

**Returns:** Borrowed reference to current value (may be null)

**Performance:** Inline function, direct pointer access.

**Preconditions:**
- Input must be valid RefObject

**Example:**
```zig
const ref = get_some_ref();
const current = lean.refGet(ref);

if (current) |value| {
    // Process non-null value
    if (lean.isScalar(value)) {
        const n = lean.unboxUsize(value);
    }
}
```

#### `refSet(r: b_obj_arg, v: obj_arg) void`
Set new value (with cleanup).

**Parameters:**
- `r` - Reference object (borrowed)
- `v` - New value (takes ownership, may be null)

**Behavior:**
1. Retrieves old value from reference
2. If old value non-null, calls `lean_dec_ref` on it
3. Stores new value in reference

**Memory Safety:** Automatically cleans up old value to prevent leaks.

**Performance:** Inline function.

**Example:**
```zig
// Initial value
lean.refSet(ref, lean.boxUsize(100));

// Update (old value automatically dec_ref'd)
lean.refSet(ref, lean.boxUsize(200));

// Set to null (valid for optional refs)
lean.refSet(ref, null);

// Restore value
lean.refSet(ref, lean.boxUsize(300));
```

### Complete Example: Counter

```zig
export fn incrementCounter(ref: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    // Get current value
    const current = lean.refGet(ref);
    const n = if (current) |val| 
        lean.unboxUsize(val) 
    else 
        0;
    
    // Increment and update
    const new_value = lean.boxUsize(n + 1);
    lean.refSet(ref, new_value);
    
    // Return unit
    const unit = lean.allocCtor(0, 0, 0) orelse {
        return lean.ioResultMkError(lean.lean_mk_string("alloc failed"));
    };
    return lean.ioResultMkOk(unit);
}
```

### ST Monad Integration

References are typically created and managed by Lean's ST monad:

```lean
def example : ST RealWorld Nat := do
  let r ← ST.mkRef 10  -- Creates RefObject internally
  r.modify (· + 5)     -- Calls refGet + refSet via FFI
  r.get                -- Calls refGet via FFI
```

The Zig FFI operates on the underlying `RefObject` pointers.

---

## External Objects

External objects wrap arbitrary native (Zig/C) data structures as Lean objects with custom finalization. Essential for FFI work with resources like file handles, database connections, sockets, and native data structures.

### Object Structure

See [`ExternalClass`](#externalclass) and [`ExternalObject`](#externalobject) in Core Types.

### Registration

#### `registerExternalClass(finalize: ?*const fn(*anyopaque) callconv(.c) void, foreach: ?*const fn(*anyopaque, b_obj_arg) callconv(.c) void) *ExternalClass`

Register an external class with the Lean runtime.

**Parameters:**
- `finalize` - Called when object's refcount reaches 0. Must free native resources. Can be null if no cleanup needed (rare).
- `foreach` - Called during GC marking. Must visit any Lean objects held by native data. Can be null if native data doesn't hold Lean objects (common case).

**Returns:** Pointer to registered external class. Store and reuse for all objects of this type.

**Thread Safety:** Registration is thread-safe, typically done at startup.

**Performance:** Called once per class at startup. Zero overhead after registration.

**Finalizer Signature Example:**
```zig
fn myFinalizer(data: *anyopaque) callconv(.c) void {
    const my_data: *MyType = @ptrCast(@alignCast(data));
    // Free native resources
    my_data.resource.close();
    // Dec_ref any Lean objects held
    if (my_data.lean_value) |val| {
        lean.lean_dec_ref(val);
    }
    // Free your structure
    allocator.destroy(my_data);
    // DON'T free Lean object header - runtime handles that!
}
```

**Foreach Signature Example (optional):**
```zig
fn myForeach(data: *anyopaque, visitor: lean.b_obj_arg) callconv(.c) void {
    const my_data: *MyType = @ptrCast(@alignCast(data));
    // Tell GC about Lean objects you're holding
    if (my_data.cached_result) |result| {
        lean.lean_apply_1(visitor, result);
    }
}
```

### Allocation

#### `allocExternal(class: *ExternalClass, data: *anyopaque) obj_res`

Allocate an external object wrapping native data.

**Preconditions:**
- `class` must be a registered external class
- `data` must be a valid pointer to your native structure
- `data` must remain valid until finalizer is called

**Parameters:**
- `class` - External class descriptor (from `registerExternalClass`)
- `data` - Pointer to your native data

**Returns:** External object with refcount=1, or null on allocation failure. Return type is `obj_res` (which is `?*Object`), making this an optional pointer.

**Memory Ownership:**
- The returned object has refcount=1 (caller owns initial reference)
- Native data lifetime is managed by your finalizer
- Lean runtime manages the object header lifetime

**Performance:** Inline function. Allocation cost: ~same as allocCtor.

**Example:**
```zig
const handle = allocator.create(FileHandle) catch return null;
handle.* = FileHandle{ .fd = file, .path = path };

const ext = lean.allocExternal(file_class, handle) orelse {
    allocator.destroy(handle);
    return error.AllocationFailed;
};
defer lean.lean_dec_ref(ext);
```

### Data Access

#### `getExternalData(o: b_obj_arg) *anyopaque`

Get the native data pointer from an external object.

**Preconditions:**
- `o` must be a valid external object (check with `isExternal()`)
- Undefined behavior if called on non-external object

**Parameters:**
- `o` - External object (borrowed reference)

**Returns:** Pointer to native data (as passed to `allocExternal`).

**Performance:** **2 CPU instructions**: 1 cast + 1 load

**Example:**
```zig
const handle: *FileHandle = @ptrCast(@alignCast(
    lean.getExternalData(file_obj)
));
_ = handle.fd.read(buffer);
```

#### `getExternalClass(o: b_obj_arg) *ExternalClass`

Get the external class from an external object.

**Preconditions:**
- `o` must be a valid external object

**Parameters:**
- `o` - External object (borrowed reference)

**Returns:** External class descriptor.

**Performance:** **2 CPU instructions**: 1 cast + 1 load

**Usage:** Rarely needed in user code.

#### `setExternalData(o: obj_arg, data: *anyopaque) ?obj_res`

Set new native data for an external object.

**Note:** The old data is NOT freed by this function. Typically you'd free it in the class finalizer, or explicitly before calling this function.

**Preconditions:**
- `o` must be a valid external object

**Parameters:**
- `o` - External object (takes ownership)
- `data` - New data pointer

**Returns:** External object with updated data (transfers ownership).

**Behavior:**
- If exclusive (refcount=1), modifies in-place
- If shared (refcount>1), allocates new object

**Performance:** Inline function. Fast path if exclusive.

**Example:**
```zig
// Typically you'd free old data first
const old_data: *MyData = @ptrCast(@alignCast(lean.getExternalData(obj)));
allocator.destroy(old_data);

const new_data = allocator.create(MyData);
const updated = lean.setExternalData(obj, new_data) orelse {
    allocator.destroy(new_data);
    return error.AllocationFailed;
};
```

### Complete Example: File Handle

```zig
const FileHandle = struct {
    fd: std.fs.File,
    path: []const u8,
};

fn fileFinalize(data: *anyopaque) callconv(.c) void {
    const handle: *FileHandle = @ptrCast(@alignCast(data));
    handle.fd.close();
    allocator.free(handle.path);
    allocator.destroy(handle);
}

// Register once at startup
const file_class = lean.registerExternalClass(fileFinalize, null);

// Create external object
export fn openFile(path_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const path_str = lean.stringCstr(path_obj);
    const path_len = lean.stringSize(path_obj) - 1;
    
    const handle = allocator.create(FileHandle) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    handle.fd = std.fs.cwd().openFile(path_str[0..path_len], .{}) catch {
        allocator.destroy(handle);
        const err = lean.lean_mk_string("file open failed");
        return lean.ioResultMkError(err);
    };
    
    handle.path = allocator.dupe(u8, path_str[0..path_len]) catch {
        handle.fd.close();
        allocator.destroy(handle);
        const err = lean.lean_mk_string("path copy failed");
        return lean.ioResultMkError(err);
    };
    
    const ext = lean.allocExternal(file_class, handle) orelse {
        handle.fd.close();
        allocator.free(handle.path);
        allocator.destroy(handle);
        const err = lean.lean_mk_string("external object allocation failed");
        return lean.ioResultMkError(err);
    };
    
    return lean.ioResultMkOk(ext);
}

// Use in operations
export fn readBytes(file_obj: lean.obj_arg, n_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(file_obj);
    defer lean.lean_dec_ref(n_obj);
    
    const handle: *FileHandle = @ptrCast(@alignCast(
        lean.getExternalData(file_obj)
    ));
    
    const n = lean.unboxUsize(n_obj);
    const buffer = allocator.alloc(u8, n) catch {
        const err = lean.lean_mk_string("buffer allocation failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(buffer);
    
    const bytes_read = handle.fd.read(buffer) catch {
        const err = lean.lean_mk_string("read failed");
        return lean.ioResultMkError(err);
    };
    
    const result = lean.lean_mk_string_from_bytes(buffer.ptr, bytes_read);
    return lean.ioResultMkOk(result);
}
```

---

## IO Results

Lean's `EStateM.Result` type for IO operations.

### Constructor Tags

- Tag 0: `IO.ok` - Success
- Tag 1: `IO.error` - Failure

### Creation

| Function | Description |
|----------|-------------|
| `ioResultMkOk(a)` → `obj_res` | Wrap success value |
| `ioResultMkError(e)` → `obj_res` | Wrap error value |

### Inspection

| Function | Returns | Description |
|----------|---------|-------------|
| `ioResultIsOk(r)` | `bool` | Check if success |
| `ioResultIsError(r)` | `bool` | Check if error |
| `ioResultGetValue(r)` | `obj_arg` | Extract value (borrowed) |

**Example:**
```zig
export fn my_io_function(world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const result = perform_operation();
    if (result) |value| {
        return lean.ioResultMkOk(value);
    } else {
        const err = lean.lean_mk_string_from_bytes("failed", 6);
        return lean.ioResultMkError(err);
    }
}
```

---

## Performance Notes

### Inline Functions

All constructor accessors, array accessors, and type checks are inline functions
matching Lean's `static inline` C definitions. This provides zero-cost abstractions
with no function call overhead.

### Tagged Pointers

Small integers (<2^63) use tagged pointer encoding, avoiding heap allocation:
- Odd address → scalar value (bits >> 1)
- Even address → heap object pointer

### Reference Counting

- Always `inc_ref` before storing additional references
- Always `dec_ref` when done with an object
- Use `defer` for cleanup in Zig

### Exclusive Objects

Check `isExclusive()` before mutation. Exclusive objects (rc=1) can be mutated
in-place, avoiding costly copies.

---

## Safety and Preconditions

Many functions have preconditions documented in their doc comments:

- **Pointer validity**: Most functions assume non-null pointers
- **Type correctness**: String functions assume string objects, etc.
- **Bounds checking**: `_fast` and `_u*` variants skip bounds checks
- **Reference counting**: Caller responsible for lifetime management

Violating preconditions results in undefined behavior (crashes, corruption).

---

## Version Compatibility

This API targets **Lean 4.25.0-4.26.0**. The Lean team does not guarantee
C ABI stability between versions. Always:

1. Pin your Lean version in `lean-toolchain`
2. Test after upgrading Lean
3. Compare struct layouts if behavior changes

See `Zig/lean.zig` header comments for detailed stability notes.
