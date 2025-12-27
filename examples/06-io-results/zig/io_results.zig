const lean = @import("lean-zig");

/// Safe division with error handling
export fn zig_safe_divide(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(a);
    defer lean.lean_dec_ref(b);

    const dividend = lean.unboxUsize(a);
    const divisor = lean.unboxUsize(b);

    if (divisor == 0) {
        const err = lean.lean_mk_string("division by zero");
        return lean.ioResultMkError(err);
    }

    const result = lean.boxUsize(dividend / divisor);
    return lean.ioResultMkOk(result);
}

/// Parse number from string (digits only)
export fn zig_parse_number(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(str);

    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;

    if (len == 0) {
        const err = lean.lean_mk_string("empty string");
        return lean.ioResultMkError(err);
    }

    var result: usize = 0;
    for (cstr[0..len]) |byte| {
        if (byte < '0' or byte > '9') {
            const err = lean.lean_mk_string("invalid number format");
            return lean.ioResultMkError(err);
        }
        result = result * 10 + (byte - '0');
    }

    return lean.ioResultMkOk(lean.boxUsize(result));
}

/// Chain operations: validate, double, add 100
/// Fails if input is 0
export fn zig_chain_operations(n: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(n);

    const value = lean.unboxUsize(n);

    // Step 1: Validate input
    if (value == 0) {
        const err = lean.lean_mk_string("bad input");
        return lean.ioResultMkError(err);
    }

    // Step 2: Double it
    const doubled = value * 2;

    // Step 3: Add 100
    const final = doubled + 100;

    return lean.ioResultMkOk(lean.boxUsize(final));
}
