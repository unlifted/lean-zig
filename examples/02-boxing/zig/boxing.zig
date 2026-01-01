const lean = @import("lean-zig");

/// Double a natural number
export fn zig_double(n: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Safety check: verify scalar before unboxing
    if (!lean.isScalar(n)) {
        const err = lean.lean_mk_string("expected scalar value");
        return lean.ioResultMkError(err);
    }

    // Unbox the Lean Nat to get a Zig usize
    const value = lean.unboxUsize(n);

    // Perform the calculation
    const result = value * 2;

    // Box the result back as a Lean Nat
    const boxed = lean.boxUsize(result);

    // Wrap in IO.ok
    return lean.ioResultMkOk(boxed);
}

/// Add two natural numbers
export fn zig_add(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Safety checks
    if (!lean.isScalar(a) or !lean.isScalar(b)) {
        const err = lean.lean_mk_string("expected scalar values");
        return lean.ioResultMkError(err);
    }

    // Unbox both arguments
    const x = lean.unboxUsize(a);
    const y = lean.unboxUsize(b);

    // Add them
    const sum = x + y;

    // Box and return
    return lean.ioResultMkOk(lean.boxUsize(sum));
}

/// Multiply two floats
/// Note: Lean's Float type is passed as unboxed f64 via ABI
export fn zig_multiply_floats(a: f64, b: f64, world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Floats are already unboxed in the ABI
    const product = a * b;

    // Return as boxed float for IO result
    const boxed = lean.boxFloat(product) orelse {
        const err = lean.lean_mk_string("Float boxing failed");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(boxed);
}
