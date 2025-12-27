const lean = @import("lean-zig");

/// Extract value from Option, return 0 if None
/// Option is represented as: none (tag 0) | some (tag 1, field 0 = value)
export fn zig_option_get_or_zero(opt: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(opt);

    // Check the constructor tag
    const tag = lean.objectTag(opt);

    if (tag == 0) {
        // None case (tag 0)
        return lean.ioResultMkOk(lean.boxUsize(0));
    } else {
        // Some case (tag 1)
        // Get field 0 (the wrapped value)
        const value = lean.ctorGet(opt, 0);

        // Increment ref count since we're returning a borrowed reference
        lean.lean_inc_ref(value);

        return lean.ioResultMkOk(value);
    }
}

/// Safe division that returns Except String Nat
/// Except is: error (tag 0, field 0 = error msg) | ok (tag 1, field 0 = value)
export fn zig_safe_divide(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    const dividend = lean.unboxUsize(a);
    const divisor = lean.unboxUsize(b);

    if (divisor == 0) {
        // Create error result: Except.error
        const err_msg = lean.lean_mk_string("division by zero");
        const error_result = lean.allocCtor(0, 1, 0) orelse {
            lean.lean_dec_ref(err_msg);
            const alloc_err = lean.lean_mk_string("allocation failed");
            return lean.ioResultMkError(alloc_err);
        };

        lean.ctorSet(error_result, 0, err_msg);
        return lean.ioResultMkOk(error_result);
    } else {
        // Create success result: Except.ok
        const quotient = dividend / divisor;
        const value = lean.boxUsize(quotient);

        const ok_result = lean.allocCtor(1, 1, 0) orelse {
            const alloc_err = lean.lean_mk_string("allocation failed");
            return lean.ioResultMkError(alloc_err);
        };

        lean.ctorSet(ok_result, 0, value);
        return lean.ioResultMkOk(ok_result);
    }
}
