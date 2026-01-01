// Main FFI file - exports functions to Lean
// Imports helper modules to organize code
const lean = @import("lean");
const std = @import("std");
const helpers = @import("helpers.zig");
const math = @import("math.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Sum array of Lean Nats
export fn zig_array_sum(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    // Use helper to convert to Zig slice
    const slice = helpers.leanArrayToSlice(arr, allocator) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(slice);

    // Use math module to compute
    const result = math.sum(slice);

    return lean.ioResultMkOk(lean.boxUsize(result));
}

/// Compute average of array
export fn zig_array_average(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const slice = helpers.leanArrayToSlice(arr, allocator) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(slice);

    const result = math.average(slice);

    return lean.ioResultMkOk(lean.boxUsize(result));
}

/// Find maximum value in array
export fn zig_array_max(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const slice = helpers.leanArrayToSlice(arr, allocator) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(slice);

    const result = math.max(slice);

    return lean.ioResultMkOk(lean.boxUsize(result));
}

/// Process array with all operations, return results as tuple
export fn zig_array_stats(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const slice = helpers.leanArrayToSlice(arr, allocator) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(slice);

    // Compute all stats
    const sum_val = math.sum(slice);
    const avg_val = math.average(slice);
    const max_val = math.max(slice);

    // Create constructor: (sum, average, max)
    const stats = lean.allocCtor(0, 0, 3 * @sizeOf(usize)) orelse {
        const err = lean.lean_mk_string("constructor allocation failed");
        return lean.ioResultMkError(err);
    };

    lean.ctorSetUsize(stats, 0, sum_val);
    lean.ctorSetUsize(stats, @sizeOf(usize), avg_val);
    lean.ctorSetUsize(stats, 2 * @sizeOf(usize), max_val);

    return lean.ioResultMkOk(stats);
}
