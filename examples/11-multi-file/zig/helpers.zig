// Helper module - not directly exposed to Lean
// These functions are used by ffi.zig
const lean = @import("lean");

/// Helper: Convert Lean array of Nats to Zig slice
pub fn leanArrayToSlice(arr: lean.b_obj_arg, allocator: std.mem.Allocator) ![]usize {
    const size = lean.arraySize(arr);
    const slice = try allocator.alloc(usize, size);

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        if (lean.isScalar(elem)) {
            slice[i] = lean.unboxUsize(elem);
        } else {
            slice[i] = 0; // Fallback for large Nats
        }
    }

    return slice;
}

/// Helper: Create Lean array from Zig slice
pub fn sliceToLeanArray(slice: []const usize) !lean.obj_res {
    const arr = lean.allocArray(slice.len) orelse return error.AllocationFailed;

    for (slice, 0..) |val, i| {
        const boxed = lean.boxUsize(val);
        lean.arraySet(arr, i, boxed);
    }

    return arr;
}

const std = @import("std");
