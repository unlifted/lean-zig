//! Boxing and unboxing for Lean scalar types.
//!
//! Lean uses tagged pointers for small integers: (value << 1) | 1
//! Larger values and floats require heap allocation.
//!
//! All boxing/unboxing functions are inline for zero-cost abstractions.

const types = @import("types.zig");
const lean_raw = @import("lean_raw");
const constructors = @import("constructors.zig");

pub const obj_arg = types.obj_arg;
pub const b_obj_arg = types.b_obj_arg;
pub const obj_res = types.obj_res;

// External Lean runtime functions for heap-allocated scalars
extern fn lean_box_uint32(n: u32) obj_res;
extern fn lean_unbox_uint32(o: b_obj_arg) u32;
extern fn lean_box_uint64(n: u64) obj_res;
extern fn lean_unbox_uint64(o: b_obj_arg) u64;

// ============================================================================
// Integer Boxing/Unboxing (Tagged Pointers)
// ============================================================================

/// Box a `usize` as a Lean `Nat` or `USize`.
///
/// Uses tagged pointer encoding: `(n << 1) | 1`
///
/// ## Panics
/// Panics if `n >= 2^63` (value too large for tagged pointer).
///
/// ## Performance
/// **1-2 CPU instructions**: 1 shift + 1 OR
pub inline fn boxUsize(n: usize) obj_res {
    if (n >= (1 << 63)) {
        @panic("boxUsize: value exceeds 63-bit maximum");
    }
    const tagged = (n << 1) | 1;
    return @ptrFromInt(tagged);
}

/// Unbox a Lean `Nat`/`USize` to `usize`.
///
/// ## Preconditions
/// - `o` must be a scalar (check with `isScalar`)
///
/// ## Performance
/// **1-2 CPU instructions**: 1 shift + 1 AND
pub inline fn unboxUsize(o: b_obj_arg) usize {
    const tagged = @intFromPtr(o);
    return tagged >> 1;
}

/// Box a `u32` as a Lean `UInt32`.
pub inline fn boxUint32(n: u32) obj_res {
    return lean_box_uint32(n);
}

/// Unbox a Lean `UInt32` to `u32`.
pub inline fn unboxUint32(o: b_obj_arg) u32 {
    return lean_unbox_uint32(o);
}

/// Box a `u64` as a Lean `UInt64`.
///
/// ## Panics
/// Panics if `n >= 2^63` (value too large for tagged pointer).
pub inline fn boxUint64(n: u64) obj_res {
    return lean_box_uint64(n);
}

/// Unbox a Lean `UInt64` to `u64`.
pub inline fn unboxUint64(o: b_obj_arg) u64 {
    return lean_unbox_uint64(o);
}

// ============================================================================
// Float Boxing/Unboxing (Heap-Allocated)
// ============================================================================

/// Box a `f64` as a Lean `Float`.
///
/// Floats cannot use tagged pointers and require heap allocation.
/// The result is a constructor with one scalar field.
///
/// ## Returns
/// Heap-allocated object or null on allocation failure.
pub fn boxFloat(f: f64) ?obj_res {
    const obj = constructors.allocCtor(0, 0, @sizeOf(f64)) orelse return null;
    constructors.ctorSetFloat(obj, 0, f);
    return obj;
}

/// Unbox a Lean `Float` to `f64`.
///
/// ## Preconditions
/// - `o` must be a float constructor
pub fn unboxFloat(o: b_obj_arg) f64 {
    return constructors.ctorGetFloat(o, 0);
}

/// Box a `f32` as a Lean 32-bit float.
pub fn boxFloat32(f: f32) ?obj_res {
    const obj = constructors.allocCtor(0, 0, @sizeOf(f32)) orelse return null;
    constructors.ctorSetFloat32(obj, 0, f);
    return obj;
}

/// Unbox a Lean 32-bit float to `f32`.
pub fn unboxFloat32(o: b_obj_arg) f32 {
    return constructors.ctorGetFloat32(o, 0);
}
