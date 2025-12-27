const lean = @import("lean-zig");

/// Inspect closure metadata
/// Returns (arity, num_fixed)
export fn zig_closure_info(closure: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Check if it's actually a closure
    if (!lean.isClosure(closure)) {
        const err = lean.lean_mk_string("not a closure");
        return lean.ioResultMkError(err);
    }

    const arity = lean.closureArity(closure);
    const num_fixed = lean.closureNumFixed(closure);

    // Return tuple (Nat × Nat)
    const pair = lean.allocCtor(0, 0, @sizeOf(u16) * 2) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    lean.ctorSetUint16(pair, 0, arity);
    lean.ctorSetUint16(pair, 2, num_fixed);

    return lean.ioResultMkOk(pair);
}
