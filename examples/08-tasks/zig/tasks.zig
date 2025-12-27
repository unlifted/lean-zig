const lean = @import("lean-zig");

/// Validate that task API functions exist and compile
/// Note: We can't actually execute tasks from Zig FFI because it requires
/// full Lean IO runtime initialization (thread pool, scheduler, etc.)
export fn zig_validate_task_api(world: lean.obj_arg) lean.obj_res {
    _ = world;

    // Validate function pointers exist (compile-time check)
    _ = lean.taskSpawn;
    _ = lean.taskMap;
    _ = lean.taskBind;
    _ = lean.lean_task_get_own;
    _ = lean.lean_task_get;
    _ = lean.lean_task_spawn_core;
    _ = lean.lean_task_map_core;
    _ = lean.lean_task_bind_core;

    // Return unit
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(unit);
}

// Note: The following demonstrates what task usage WOULD look like,
// but can't be executed from Zig FFI without full runtime:
//
// export fn zig_spawn_task(closure: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
//     _ = world;
//
//     // This would require Lean IO runtime to be initialized
//     const task = lean.taskSpawn(closure) orelse {
//         lean.lean_dec_ref(closure);
//         const err = lean.lean_mk_string("task spawn failed");
//         return lean.ioResultMkError(err);
//     };
//
//     return lean.ioResultMkOk(task);
// }
