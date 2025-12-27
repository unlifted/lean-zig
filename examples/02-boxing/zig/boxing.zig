const lean = @import("lean-zig");

/// Double a natural number
export fn zig_double(n: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

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

    // Unbox both arguments
    const x = lean.unboxUsize(a);
    const y = lean.unboxUsize(b);

    // Add them
    const sum = x + y;

    // Box and return
    return lean.ioResultMkOk(lean.boxUsize(sum));
}

/// Multiply two floats
/// Note: Floats require heap allocation, so this is slower than integer boxing
export fn zig_multiply_floats(a: lean.obj_arg, b: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Unbox the floats
    const x = lean.unboxFloat(a);
    const y = lean.unboxFloat(b);

    // Multiply
    const product = x * y;

    // Box the result (allocates on heap)
    const boxed = lean.boxFloat(product);

    return lean.ioResultMkOk(boxed);
}
