//! # Lean 4 Runtime FFI Bindings for Zig
//!
//! This module provides Zig definitions that match the Lean 4 runtime's C ABI,
//! allowing Zig code to interoperate with Lean without requiring a C shim.
//!
//! ## Compatibility
//!
//! - **Lean Version**: 4.26.0
//! - **Source Reference**: `lean/lean.h` from the Lean 4 toolchain
//!
//! ## Architecture
//!
//! Lean's runtime uses a uniform object representation where all heap objects
//! share a common 8-byte header containing reference count, size, and type tag.
//! This module reimplements the inline functions from `lean.h` since they are
//! not exported as symbols.
//!
//! ## Stability Warning
//!
//! The Lean team has **not committed to a stable C ABI**. These definitions may
//! require updates for future Lean versions. Best practices:
//!
//! 1. Pin your Lean version in `lean-toolchain`
//! 2. Test FFI code after any Lean upgrade
//! 3. Compare `lean/lean.h` if behavior changes
//!
//! ## Usage
//!
//! ```zig
//! const lean = @import("lean.zig");
//!
//! export fn my_function(str: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
//!     _ = world;
//!     const data = lean.stringCstr(str);
//!     const result = lean.lean_mk_string_from_bytes(data, 5);
//!     return lean.ioResultMkOk(result);
//! }
//! ```

// ============================================================================
// Core Object Types
// ============================================================================

/// Base header for all Lean heap objects.
///
/// Every Lean heap object starts with this 8-byte header. The fields are:
/// - `m_rc`: Reference count. Negative values indicate multi-threaded objects.
/// - `m_cs_sz`: Byte size for small objects (fits in 16 bits), 0 for large objects.
/// - `m_other`: Auxiliary data. For ctors, this is the number of object fields.
/// - `m_tag`: Object type tag. Values 0-243 are constructors, higher values are
///   special types (arrays, strings, closures, etc.).
///
/// Matches `lean_object` in `lean/lean.h`.
pub const Object = extern struct {
    m_rc: i32,
    m_cs_sz: u16,
    m_other: u8,
    m_tag: u8,
};

/// Lean string object layout.
///
/// Strings in Lean are UTF-8 encoded and null-terminated. The string data
/// follows immediately after this struct header (flexible array member pattern).
///
/// - `m_size`: Number of bytes including the null terminator
/// - `m_capacity`: Allocated buffer size (>= m_size)
/// - `m_length`: Number of Unicode code points (may differ from byte count)
///
/// Matches `lean_string_object` in `lean/lean.h`.
pub const StringObject = extern struct {
    m_header: Object,
    m_size: usize,
    m_capacity: usize,
    m_length: usize,
    // Actual string data follows (flexible array member)
};

/// Lean constructor (algebraic data type) object layout.
///
/// Constructors represent values of inductive types. The header's `m_tag` field
/// identifies which constructor variant this is (0 for first, 1 for second, etc.).
/// The header's `m_other` field stores the number of object fields.
///
/// Object fields follow immediately after the header, then any scalar fields.
///
/// Matches `lean_ctor_object` in `lean/lean.h`.
pub const CtorObject = extern struct {
    m_header: Object,
    // Object fields follow (flexible array member)
};

/// Lean array object layout.
///
/// Arrays are homogeneous, dynamically-sized collections. Elements are stored
/// contiguously following the header. For object arrays (the common case),
/// each element is a pointer to a Lean object.
///
/// - `m_size`: Current number of elements
/// - `m_capacity`: Maximum elements before reallocation
///
/// Matches `lean_array_object` in `lean/lean.h`.
pub const ArrayObject = extern struct {
    m_header: Object,
    m_size: usize,
    m_capacity: usize,
    // Element pointers follow (flexible array member)
};

// ============================================================================
// Type Aliases (Lean Ownership Conventions)
// ============================================================================

/// Owned object argument: caller transfers ownership to callee.
///
/// When a function takes `obj_arg`, it becomes responsible for the object's
/// reference count. The caller should not use the object after the call.
pub const obj_arg = ?*Object;

/// Borrowed object argument: caller retains ownership.
///
/// When a function takes `b_obj_arg`, it may read but not store the object.
/// The caller remains responsible for the object's lifetime.
pub const b_obj_arg = ?*Object;

/// Object result: callee transfers ownership to caller.
///
/// The returned object has a reference count of at least 1. The caller
/// becomes responsible for eventually decrementing the reference count.
pub const obj_res = ?*Object;

// ============================================================================
// Object Tag Constants
// ============================================================================

/// Object type tags stored in `Object.m_tag`.
///
/// Tags 0-243 are constructor variants of inductive types.
/// Tags >= 244 are special runtime types (closures, arrays, etc.).
///
/// Note: Not all tags are used by this module. They are included for
/// completeness and to match the Lean runtime's tag definitions.
pub const Tag = struct {
    pub const max_ctor: u8 = 243; // Constructors use tags 0..243
    pub const closure: u8 = 245; // Function closure
    pub const array: u8 = 246; // Array of objects
    pub const sarray: u8 = 247; // Scalar array (ByteArray, etc.)
    pub const string: u8 = 249; // UTF-8 string
    pub const mpz: u8 = 250; // Big integer (GMP)
    pub const thunk: u8 = 251; // Lazy computation
    pub const task: u8 = 252; // Async task
    pub const ref: u8 = 253; // Mutable reference
    pub const external: u8 = 254; // Foreign object
};

// ============================================================================
// External Lean Runtime Functions
// ============================================================================

// These are the only Lean runtime functions available as exported symbols.
// Most Lean runtime functions are `static inline` in lean.h and must be
// reimplemented (see Inline Function Reimplementations section below).

/// Allocate a raw Lean object of the given byte size.
///
/// The returned object has uninitialized fields. Caller must initialize
/// the header fields (m_rc, m_tag, etc.) before use.
pub extern fn lean_alloc_object(sz: usize) obj_res;

/// Create a Lean string from a byte buffer.
///
/// The bytes are copied into a newly allocated string object. The input
/// does not need to be null-terminated; the runtime adds the terminator.
///
/// ## Parameters
/// - `s`: Pointer to UTF-8 encoded bytes
/// - `sz`: Number of bytes (not including any null terminator)
pub extern fn lean_mk_string_from_bytes(s: [*]const u8, sz: usize) obj_res;

/// Create a Lean string from a null-terminated C string.
pub extern fn lean_mk_string(s: [*:0]const u8) obj_res;

/// Increment an object's reference count.
///
/// Call when storing an additional reference to a borrowed object.
pub extern fn lean_inc_ref(o: obj_arg) void;

/// Decrement an object's reference count.
///
/// May free the object if the count reaches zero. Do not use the object
/// after calling this unless you hold another reference.
pub extern fn lean_dec_ref(o: obj_arg) void;

// ============================================================================
// String Functions (reimplemented from lean.h inline functions)
// ============================================================================

/// Get a pointer to the raw UTF-8 bytes of a Lean string.
///
/// The returned pointer points to the string data immediately following
/// the StringObject header. The string is null-terminated.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
///
/// ## Example
/// ```zig
/// const cstr = lean.stringCstr(lean_string);
/// const len = lean.stringSize(lean_string) - 1;  // exclude null
/// const slice = cstr[0..len];
/// ```
pub fn stringCstr(o: b_obj_arg) [*]const u8 {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    const base: [*]const u8 = @ptrCast(strObj);
    return base + @sizeOf(StringObject);
}

/// Get the byte size of a Lean string, including the null terminator.
///
/// To get the actual content length, subtract 1 from this value.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
pub fn stringSize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    return strObj.m_size;
}

/// Get the Unicode code point length of a Lean string.
///
/// This may differ from byte size for strings containing multi-byte characters.
///
/// ## Precondition
/// The input must be a valid, non-null Lean string object.
pub fn stringLen(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const strObj: *StringObject = @ptrCast(@alignCast(obj));
    return strObj.m_length;
}

// ============================================================================
// Constructor Functions (reimplemented from lean.h inline functions)
// ============================================================================

/// Allocate a constructor object.
///
/// Constructors represent values of inductive (algebraic) data types.
/// The layout is: [header][object_fields...][scalar_fields...]
///
/// ## Parameters
/// - `tag`: Constructor variant (0 for first constructor, 1 for second, etc.)
/// - `numObjs`: Number of object (pointer) fields
/// - `scalarSize`: Total size in bytes of scalar fields
///
/// ## Example: Creating `IO.ok result`
/// ```zig
/// const ok = lean.allocCtor(0, 1, 0);  // tag 0, 1 object field, 0 scalars
/// lean.ctorSet(ok, 0, result_value);
/// ```
pub fn allocCtor(tag: u8, numObjs: u8, scalarSize: usize) obj_res {
    const size = @sizeOf(CtorObject) + @as(usize, numObjs) * @sizeOf(?*Object) + scalarSize;
    const o = lean_alloc_object(size) orelse return null;
    o.m_rc = 1;
    o.m_cs_sz = @intCast(size);
    o.m_other = numObjs;
    o.m_tag = tag;
    return o;
}

/// Set an object field in a constructor.
///
/// ## Parameters
/// - `o`: Constructor object
/// - `i`: Field index (0-based)
/// - `v`: Value to store (ownership transferred to constructor)
pub fn ctorSet(o: obj_res, i: usize, v: obj_arg) void {
    const objs = ctorObjCptr(o);
    objs[i] = v;
}

/// Get a pointer to the object fields array of a constructor.
///
/// The returned pointer can be indexed to access individual fields.
///
/// ## Precondition
/// The input must be a valid, non-null constructor object.
pub fn ctorObjCptr(o: obj_res) [*]obj_arg {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(obj);
    return @ptrCast(@alignCast(base + @sizeOf(CtorObject)));
}

/// Get an object field from a constructor.
///
/// ## Parameters
/// - `o`: Constructor object (borrowed)
/// - `i`: Field index (0-based)
///
/// ## Returns
/// The object at the given field index. The constructor retains ownership.
pub fn ctorGet(o: b_obj_arg, i: usize) obj_arg {
    const objs = ctorObjCptr(o);
    return objs[i];
}

// ============================================================================
// IO Result Helpers
// ============================================================================

// Lean IO functions return `EStateM.Result` which is an inductive type:
//   - `ok` (tag 0): Contains the success value
//   - `error` (tag 1): Contains the error value
//
// These functions construct and inspect IO results.

/// Create an IO success result.
///
/// Equivalent to `EStateM.Result.ok` in Lean. The resulting object owns
/// the provided value.
///
/// ## Example
/// ```zig
/// const str = lean.lean_mk_string_from_bytes("hello", 5);
/// return lean.ioResultMkOk(str);
/// ```
pub fn ioResultMkOk(a: obj_arg) obj_res {
    const r = allocCtor(0, 1, 0) orelse return null;
    ctorSet(r, 0, a);
    return r;
}

/// Create an IO error result.
///
/// Equivalent to `EStateM.Result.error` in Lean. Typically the error
/// value is a string describing the failure.
///
/// ## Example
/// ```zig
/// const msg = lean.lean_mk_string_from_bytes("allocation failed", 17);
/// return lean.ioResultMkError(msg);
/// ```
pub fn ioResultMkError(e: obj_arg) obj_res {
    const r = allocCtor(1, 1, 0) orelse return null;
    ctorSet(r, 0, e);
    return r;
}

/// Check if an IO result represents success.
///
/// ## Precondition
/// The input must be a valid, non-null IO result object.
pub fn ioResultIsOk(r: b_obj_arg) bool {
    const obj: *Object = @ptrCast(@alignCast(r orelse unreachable));
    return obj.m_tag == 0;
}

/// Check if an IO result represents an error.
///
/// ## Precondition
/// The input must be a valid, non-null IO result object.
pub fn ioResultIsError(r: b_obj_arg) bool {
    const obj: *Object = @ptrCast(@alignCast(r orelse unreachable));
    return obj.m_tag == 1;
}

/// Extract the value from a successful IO result.
///
/// Precondition: `ioResultIsOk(r)` must be true.
pub fn ioResultGetValue(r: b_obj_arg) obj_arg {
    return ctorGet(r, 0);
}

// ============================================================================
// Array Functions (reimplemented from lean.h inline functions)
// ============================================================================

/// Get the number of elements in a Lean array.
///
/// ## Precondition
/// The input must be a valid, non-null Lean array object.
pub fn arraySize(o: b_obj_arg) usize {
    const obj = o orelse unreachable;
    const arr: *ArrayObject = @ptrCast(@alignCast(obj));
    return arr.m_size;
}

/// Get a pointer to the array's element storage.
///
/// For object arrays, this is an array of object pointers.
///
/// ## Precondition
/// The input must be a valid, non-null Lean array object.
pub fn arrayCptr(o: b_obj_arg) [*]obj_arg {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(@alignCast(obj));
    return @ptrCast(@alignCast(base + @sizeOf(ArrayObject)));
}

/// Get an element from a Lean array by index.
///
/// The array retains ownership of the element.
pub fn arrayGet(o: b_obj_arg, i: usize) obj_arg {
    return arrayCptr(o)[i];
}

/// Set an element in a Lean array by index.
///
/// Ownership of the value transfers to the array.
pub fn arraySet(o: obj_res, i: usize, v: obj_arg) void {
    arrayCptr(o)[i] = v;
}

/// Allocate a new Lean array with the given capacity.
///
/// The array is initialized with size 0. Use `arraySet` and update
/// the size field, or use `mkArrayWithSize` for pre-sized arrays.
pub fn allocArray(capacity: usize) obj_res {
    const size = @sizeOf(ArrayObject) + capacity * @sizeOf(?*Object);
    const o = lean_alloc_object(size) orelse return null;
    o.m_rc = 1;
    o.m_cs_sz = 0; // 0 indicates large object
    o.m_other = 0;
    o.m_tag = Tag.array;

    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    arr.m_size = 0;
    arr.m_capacity = capacity;

    return o;
}

/// Create a Lean array with a pre-set size.
///
/// The array is allocated with the given capacity and size is set to
/// `initialSize`. The caller must populate all elements via `arraySet`
/// before the array is used by Lean code.
///
/// ## Example
/// ```zig
/// const arr = lean.mkArrayWithSize(3, 3) orelse return error;
/// lean.arraySet(arr, 0, elem0);
/// lean.arraySet(arr, 1, elem1);
/// lean.arraySet(arr, 2, elem2);
/// ```
pub fn mkArrayWithSize(capacity: usize, initialSize: usize) obj_res {
    const o = allocArray(capacity) orelse return null;
    const arr: *ArrayObject = @ptrCast(@alignCast(o));
    arr.m_size = initialSize;
    return o;
}

// ============================================================================
// Scalar Boxing (reimplemented from lean.h inline functions)
// ============================================================================

// Lean uses tagged pointers for small scalar values. On 64-bit systems,
// values that fit in 63 bits are encoded as (value << 1) | 1, using the
// odd address to distinguish from heap pointers (always even/aligned).

/// Box a usize value as a Lean object.
///
/// Small values (< 2^63) use tagged pointer encoding without allocation.
/// This is how Lean efficiently represents `Nat` and other numeric types.
///
/// ## Panics
/// Panics if the value is too large for tagged pointer representation.
/// This is rare on 64-bit systems.
pub fn boxUsize(n: usize) obj_res {
    if (n < (@as(usize, 1) << 63)) {
        return @ptrFromInt((n << 1) | 1);
    }
    @panic("boxUsize: value too large for tagged pointer");
}

/// Unbox a Lean object to a usize.
///
/// ## Panics
/// Panics if the object is not a tagged pointer (i.e., it's a heap object).
pub fn unboxUsize(o: b_obj_arg) usize {
    const ptr = @intFromPtr(o);
    if (ptr & 1 == 1) {
        return ptr >> 1;
    }
    @panic("unboxUsize: expected tagged pointer");
}
