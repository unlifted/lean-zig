const lean = @import("lean-zig");
const std = @import("std");

/// Parse CSV line "name,value" into Record constructor
/// Record has tag 0, 2 object fields (name: String, value: Nat)
export fn zig_parse_csv_line(line: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(line);

    const cstr = lean.stringCstr(line);
    const len = lean.stringSize(line) - 1;

    // Find comma
    var comma_pos: ?usize = null;
    for (cstr[0..len], 0..) |byte, i| {
        if (byte == ',') {
            comma_pos = i;
            break;
        }
    }

    const pos = comma_pos orelse {
        const err = lean.lean_mk_string("invalid CSV format: no comma");
        return lean.ioResultMkError(err);
    };

    // Extract name
    const name = lean.lean_mk_string_from_bytes(cstr, pos);

    // Parse value
    var value: usize = 0;
    for (cstr[pos + 1 .. len]) |byte| {
        if (byte < '0' or byte > '9') {
            lean.lean_dec_ref(name);
            const err = lean.lean_mk_string("invalid number in CSV");
            return lean.ioResultMkError(err);
        }
        value = value * 10 + (byte - '0');
    }

    // Create Record constructor
    const record = lean.allocCtor(0, 2, 0) orelse {
        lean.lean_dec_ref(name);
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    lean.ctorSet(record, 0, name);
    lean.ctorSet(record, 1, lean.boxUsize(value));

    return lean.ioResultMkOk(record);
}

/// Filter records by minimum value
export fn zig_filter_records(records: lean.obj_arg, min_value: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(records);
    defer lean.lean_dec_ref(min_value);

    const min = lean.unboxUsize(min_value);
    const size = lean.arraySize(records);

    // Count matching records
    var count: usize = 0;
    for (0..size) |i| {
        const record = lean.arrayUget(records, i);
        const value_obj = lean.ctorGet(record, 1);
        const value = lean.unboxUsize(value_obj);
        if (value >= min) count += 1;
    }

    // Build filtered array
    const result = lean.allocArray(count) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    var j: usize = 0;
    for (0..size) |i| {
        const record = lean.arrayUget(records, i);
        const value_obj = lean.ctorGet(record, 1);
        const value = lean.unboxUsize(value_obj);
        if (value >= min) {
            lean.lean_inc_ref(record);
            lean.arraySet(result, j, record);
            j += 1;
        }
    }

    return lean.ioResultMkOk(result);
}

/// Compute statistics from records
/// Statistics has tag 0, 0 object fields, 5 scalar fields (count, total, average, min, max)
export fn zig_compute_statistics(records: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(records);

    const size = lean.arraySize(records);
    if (size == 0) {
        const err = lean.lean_mk_string("empty record set");
        return lean.ioResultMkError(err);
    }

    var total: usize = 0;
    var min: usize = std.math.maxInt(usize);
    var max: usize = 0;

    for (0..size) |i| {
        const record = lean.arrayUget(records, i);
        const value_obj = lean.ctorGet(record, 1);
        const value = lean.unboxUsize(value_obj);

        total += value;
        if (value < min) min = value;
        if (value > max) max = value;
    }

    const average = @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(size));

    // Create Statistics constructor
    const stats = lean.allocCtor(0, 0, @sizeOf(usize) * 4 + @sizeOf(f64)) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    lean.ctorSetUsize(stats, 0, size);
    lean.ctorSetUsize(stats, @sizeOf(usize), total);
    lean.ctorSetFloat(stats, @sizeOf(usize) * 2, average);
    lean.ctorSetUsize(stats, @sizeOf(usize) * 2 + @sizeOf(f64), min);
    lean.ctorSetUsize(stats, @sizeOf(usize) * 3 + @sizeOf(f64), max);

    return lean.ioResultMkOk(stats);
}

/// Get top N records by value (simple bubble sort for small N)
export fn zig_top_records(records: lean.obj_arg, n: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(records);
    defer lean.lean_dec_ref(n);

    const size = lean.arraySize(records);
    const top_count = @min(lean.unboxUsize(n), size);

    // Copy records to sort
    const sorted = lean.allocArray(size) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    for (0..size) |i| {
        const record = lean.arrayUget(records, i);
        lean.lean_inc_ref(record);
        lean.arraySet(sorted, i, record);
    }

    // Simple bubble sort descending
    var i: usize = 0;
    while (i < size) : (i += 1) {
        var j: usize = 0;
        while (j < size - i - 1) : (j += 1) {
            const rec1 = lean.arrayUget(sorted, j);
            const rec2 = lean.arrayUget(sorted, j + 1);

            const val1 = lean.unboxUsize(lean.ctorGet(rec1, 1));
            const val2 = lean.unboxUsize(lean.ctorGet(rec2, 1));

            if (val1 < val2) {
                lean.arraySwap(sorted, j, j + 1);
            }
        }
    }

    // Take top N
    const result = lean.allocArray(top_count) orelse {
        lean.lean_dec_ref(sorted);
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    for (0..top_count) |k| {
        const record = lean.arrayUget(sorted, k);
        lean.lean_inc_ref(record);
        lean.arraySet(result, k, record);
    }

    lean.lean_dec_ref(sorted);
    return lean.ioResultMkOk(result);
}
