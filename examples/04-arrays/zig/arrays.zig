const lean = @import("lean-zig");

/// Create an array [1, 2, 3, 4, 5]
export fn zig_create_array(world: lean.obj_arg) lean.obj_res {
    _ = world;

    const values = [_]usize{ 1, 2, 3, 4, 5 };
    const arr = lean.allocArray(values.len) orelse {
        const err = lean.lean_mk_string("array allocation failed");
        return lean.ioResultMkError(err);
    };

    // Populate the array
    for (values, 0..) |val, i| {
        lean.arraySet(arr, i, lean.boxUsize(val));
    }

    return lean.ioResultMkOk(arr);
}

/// Sum all elements in an array
export fn zig_sum_array(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const size = lean.arraySize(arr);
    var sum: usize = 0;

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        sum += lean.unboxUsize(elem);
    }

    return lean.ioResultMkOk(lean.boxUsize(sum));
}

/// Map: double each element
export fn zig_map_double(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const size = lean.arraySize(arr);
    const result = lean.allocArray(size) orelse {
        const err = lean.lean_mk_string("array allocation failed");
        return lean.ioResultMkError(err);
    };

    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        const value = lean.unboxUsize(elem);
        const doubled = lean.boxUsize(value * 2);
        lean.arraySet(result, i, doubled);
    }

    return lean.ioResultMkOk(result);
}

/// Filter: keep only even numbers
export fn zig_filter_evens(arr: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(arr);

    const size = lean.arraySize(arr);

    // First pass: count evens
    var count: usize = 0;
    var i: usize = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        const value = lean.unboxUsize(elem);
        if (value % 2 == 0) count += 1;
    }

    // Second pass: build result
    const result = lean.allocArray(count) orelse {
        const err = lean.lean_mk_string("array allocation failed");
        return lean.ioResultMkError(err);
    };

    var j: usize = 0;
    i = 0;
    while (i < size) : (i += 1) {
        const elem = lean.arrayUget(arr, i);
        const value = lean.unboxUsize(elem);
        if (value % 2 == 0) {
            lean.lean_inc_ref(elem); // Need to inc ref when sharing
            lean.arraySet(result, j, elem);
            j += 1;
        }
    }

    return lean.ioResultMkOk(result);
}
