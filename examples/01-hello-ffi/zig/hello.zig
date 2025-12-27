const lean = @import("lean-zig");

/// Returns a magic number (42) to Lean
/// This demonstrates the simplest possible FFI function
export fn zig_get_magic_number(world: lean.obj_arg) lean.obj_res {
    _ = world; // IO world token (unused in this simple example)

    // Box the number 42 as a Lean Nat
    const value = lean.boxUsize(42);

    // Wrap in IO.ok result
    return lean.ioResultMkOk(value);
}
