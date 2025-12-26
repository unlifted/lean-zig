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
13. [IO Results](#io-results)

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

Thunks represent lazy computations evaluated on first access.

### Creation

- **`lean_thunk_pure(v)`** → `obj_res` - Create already-evaluated thunk

### Evaluation

| Function | Description |
|----------|-------------|
| `lean_thunk_get_own(o)` → `obj_res` | Force evaluation (transfers ownership) |
| `thunkGet(o)` → `obj_arg` | Get value (borrowed) |

**Example:**
```zig
// Create lazy computation
const thunk = create_lazy_computation();

// Force evaluation
const result = lean.lean_thunk_get_own(thunk);
defer lean.lean_dec_ref(result);
```

---

## Tasks

Tasks represent asynchronous computations.

### Core Functions

| Function | Description |
|----------|-------------|
| `lean_task_spawn_core(fn, prio, async_mode)` | Spawn task with options |
| `lean_task_get_own(t)` → `obj_res` | Wait for result (blocks) |
| `lean_task_map_core(t, f, prio, async)` | Map function over result |
| `lean_task_bind_core(t, f, prio, async)` | Monadic bind (sequence) |

### Simplified Wrappers

Default priority=0, async=true:

- **`taskSpawn(fn_closure)`** → `obj_res` - Spawn async task
- **`taskMap(t, f)`** → `obj_res` - Map function over task
- **`taskBind(t, f)`** → `obj_res` - Bind/chain tasks

**Example:**
```zig
// Spawn async computation
const task = lean.taskSpawn(computation_closure);

// Map result
const mapped = lean.taskMap(task, transform_fn);

// Wait for result
const result = lean.lean_task_get_own(mapped);
defer lean.lean_dec_ref(result);
```

---

## References

Mutable references for the ST (state thread) monad.

### Access

| Function | Description |
|----------|-------------|
| `refGet(o)` → `obj_arg` | Get current value (borrowed) |
| `refSet(o, v)` | Set new value (dec_refs old value) |

**Example:**
```zig
// In ST context
const ref = get_some_ref();
const current = lean.refGet(ref);

// Mutate
const new_value = compute_new_value(current);
lean.refSet(ref, new_value);
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
