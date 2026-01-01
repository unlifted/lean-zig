//! Constructor object allocation and field access.
//!
//! Constructors represent values of inductive types in Lean.
//! Memory layout: [ObjectHeader][object_fields...][scalar_fields...]
//!
//! All field access functions are inline for zero-cost abstractions.

const types = @import("types.zig");
const memory = @import("memory.zig");
const lean_raw = @import("lean_raw");
const boxing = @import("boxing.zig");

pub const Object = types.Object;
pub const ObjectHeader = types.ObjectHeader;
pub const CtorObject = types.CtorObject;
pub const obj_arg = types.obj_arg;
pub const b_obj_arg = types.b_obj_arg;
pub const obj_res = types.obj_res;

// Re-export memory functions needed by constructors
pub const lean_dec_ref = memory.lean_dec_ref;
pub const objectOther = memory.objectOther;

// ============================================================================
// Constructor Allocation
// ============================================================================

/// Allocate a constructor object.
///
/// ## Parameters
/// - `tag`: Constructor variant (0 for first, 1 for second, etc.)
/// - `num_objs`: Number of object (pointer) fields
/// - `scalar_sz`: Total byte size of scalar fields
///
/// ## Returns
/// Allocated constructor with uninitialized fields, or null on failure.
///
/// ## Memory Layout
/// ```
/// [ObjectHeader][object_fields...][scalar_fields...]
/// ```
///
/// ## Example
/// ```zig
/// // Create Option.some with one field
/// const some = allocCtor(1, 1, 0) orelse return error.AllocationFailed;
/// ctorSet(some, 0, value);
///
/// // Create tuple (UInt32, Float)
/// const pair = allocCtor(0, 0, @sizeOf(u32) + @sizeOf(f64));
/// ctorSetUint32(pair, 0, 42);
/// ctorSetFloat(pair, @sizeOf(u32), 3.14);
/// ```
pub fn allocCtor(tag: u8, num_objs: u8, scalar_sz: usize) ?obj_res {
    const sz = @sizeOf(CtorObject) + @as(usize, num_objs) * @sizeOf(?*Object) + scalar_sz;
    const o = lean_raw.lean_alloc_object(sz) orelse return null;

    // Initialize header
    const hdr: *ObjectHeader = @ptrCast(@alignCast(o));
    hdr.m_rc = 1;
    hdr.m_tag = tag;
    hdr.m_other = num_objs;
    hdr.m_cs_sz = if (sz <= 0xFFFF) @intCast(sz) else 0;

    // CRITICAL: Initialize all object fields to boxed scalar 0
    // This is safe because tagged pointers don't have their reference
    // counts decremented. Using null or uninitialized values would crash
    // in lean_dec_ref_cold when the object is freed.
    if (num_objs > 0) {
        const objs = ctorObjCptr(o);
        const scalar_zero = boxing.boxUsize(0);
        var i: usize = 0;
        while (i < num_objs) : (i += 1) {
            objs[i] = scalar_zero;
        }
    }

    return o;
}

// ============================================================================
// Object Field Access
// ============================================================================

/// Get the number of object fields in a constructor.
///
/// Stored in the m_other field of the object header.
pub inline fn ctorNumObjs(o: b_obj_arg) u8 {
    return objectOther(o);
}

/// Get a pointer to the object fields array.
///
/// ## Precondition
/// `o` must be a non-null constructor object.
pub fn ctorObjCptr(o: b_obj_arg) [*]obj_arg {
    const obj = o orelse unreachable;
    const base: [*]u8 = @ptrCast(obj);
    return @ptrCast(@alignCast(base + @sizeOf(CtorObject)));
}

/// Get an object field at index.
///
/// ## Parameters
/// - `o`: Constructor object (borrowed)
/// - `i`: Field index (0-based)
///
/// ## Returns
/// Borrowed reference to the object at index (constructor retains ownership).
pub fn ctorGet(o: b_obj_arg, i: usize) obj_arg {
    const objs = ctorObjCptr(o);
    return objs[i];
}

/// Set an object field at index.
///
/// ## Parameters
/// - `o`: Constructor object
/// - `i`: Field index (0-based)
/// - `v`: Value to store (ownership transferred to constructor)
pub fn ctorSet(o: obj_res, i: usize, v: obj_arg) void {
    const objs = ctorObjCptr(o);
    objs[i] = v;
}

// ============================================================================
// Scalar Field Access
// ============================================================================

/// Get a pointer to the scalar field region.
///
/// Scalar fields begin after the object fields.
///
/// ## Precondition
/// `o` must be a non-null constructor object.
///
/// ## Safety
/// The returned pointer may not be properly aligned for larger types if preceded
/// by an odd number of object fields. Use typed accessors (ctorGetUint*, etc.)
/// which handle alignment correctly with @alignCast.
pub fn ctorScalarCptr(o: b_obj_arg) [*]u8 {
    const obj = o orelse @panic("ctorScalarCptr: null constructor object");
    const base: [*]u8 = @ptrCast(obj);
    const num_objs = ctorNumObjs(o);
    return base + @sizeOf(CtorObject) + @as(usize, num_objs) * @sizeOf(?*Object);
}

/// Get a uint8 scalar field at byte offset.
pub inline fn ctorGetUint8(o: b_obj_arg, offset: usize) u8 {
    const ptr = ctorScalarCptr(o);
    return ptr[offset];
}

/// Set a uint8 scalar field at byte offset.
pub inline fn ctorSetUint8(o: obj_res, offset: usize, val: u8) void {
    const ptr = ctorScalarCptr(o);
    ptr[offset] = val;
}

/// Get a uint16 scalar field at byte offset.
pub inline fn ctorGetUint16(o: b_obj_arg, offset: usize) u16 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u16 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint16 scalar field at byte offset.
pub inline fn ctorSetUint16(o: obj_res, offset: usize, val: u16) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u16 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a uint32 scalar field at byte offset.
pub inline fn ctorGetUint32(o: b_obj_arg, offset: usize) u32 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u32 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint32 scalar field at byte offset.
pub inline fn ctorSetUint32(o: obj_res, offset: usize, val: u32) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u32 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a uint64 scalar field at byte offset.
pub inline fn ctorGetUint64(o: b_obj_arg, offset: usize) u64 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const u64 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a uint64 scalar field at byte offset.
pub inline fn ctorSetUint64(o: obj_res, offset: usize, val: u64) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *u64 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a usize scalar field at byte offset.
pub inline fn ctorGetUsize(o: b_obj_arg, offset: usize) usize {
    const ptr = ctorScalarCptr(o);
    const aligned: *const usize = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a usize scalar field at byte offset.
pub inline fn ctorSetUsize(o: obj_res, offset: usize, val: usize) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *usize = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a float64 scalar field at byte offset.
pub inline fn ctorGetFloat(o: b_obj_arg, offset: usize) f64 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const f64 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a float64 scalar field at byte offset.
pub inline fn ctorSetFloat(o: obj_res, offset: usize, val: f64) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *f64 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

/// Get a float32 scalar field at byte offset.
pub inline fn ctorGetFloat32(o: b_obj_arg, offset: usize) f32 {
    const ptr = ctorScalarCptr(o);
    const aligned: *const f32 = @ptrCast(@alignCast(ptr + offset));
    return aligned.*;
}

/// Set a float32 scalar field at byte offset.
pub inline fn ctorSetFloat32(o: obj_res, offset: usize, val: f32) void {
    const ptr = ctorScalarCptr(o);
    const aligned: *f32 = @ptrCast(@alignCast(ptr + offset));
    aligned.* = val;
}

// ============================================================================
// Constructor Utilities
// ============================================================================

/// Change the tag of a constructor (change variant).
///
/// ## Precondition
/// `o` must be a non-null constructor object.
pub fn ctorSetTag(o: obj_res, tag: u8) void {
    const obj = o orelse @panic("ctorSetTag: null constructor object");
    const hdr: *ObjectHeader = @ptrCast(@alignCast(obj));
    hdr.m_tag = tag;
}

/// Release (decrement) all object field references without freeing the constructor.
///
/// Used when reusing a constructor or implementing custom deallocation.
pub fn ctorRelease(o: obj_res, num_objs: u8) void {
    const objs = ctorObjCptr(o);
    var i: usize = 0;
    while (i < num_objs) : (i += 1) {
        lean_dec_ref(objs[i]);
    }
}
