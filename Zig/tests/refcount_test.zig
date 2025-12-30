const std = @import("std");
const testing = std.testing;
const lean = @import("../lean.zig");

// ============================================================================
// Reference Counting Tests
// ============================================================================

test "inc and dec ref maintain balance" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;

    // Increment twice
    lean.lean_inc_ref(obj);
    lean.lean_inc_ref(obj);

    // Decrement three times (original + 2)
    lean.lean_dec_ref(obj);
    lean.lean_dec_ref(obj);
    lean.lean_dec_ref(obj);
    // Object should be freed now
}

test "reference count starts at 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));
}

test "refcount: circular references with manual cleanup" {
    // Create two objects that reference each other
    const obj1 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    const obj2 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;

    lean.ctorSet(obj1, 0, obj2);
    lean.lean_inc_ref(obj2);
    lean.ctorSet(obj2, 0, obj1);
    lean.lean_inc_ref(obj1);

    try testing.expectEqual(@as(i32, 2), lean.objectRc(obj1));
    try testing.expectEqual(@as(i32, 2), lean.objectRc(obj2));

    // Break cycle manually
    lean.lean_dec_ref(obj1);
    lean.lean_dec_ref(obj2);
}

test "refcount: many increments and decrements" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Increment many times
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        lean.lean_inc_ref(obj);
    }

    const rc = lean.objectRc(obj);
    try testing.expectEqual(@as(i32, 1001), rc);

    // Decrement back
    i = 0;
    while (i < 1000) : (i += 1) {
        lean.lean_dec_ref(obj);
    }

    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));
}

test "refcount: nested object graph" {
    // Create tree: root -> [left, right], left -> [leaf1], right -> [leaf2]
    const leaf1 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const leaf2 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const left = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    const right = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    const root = lean.allocCtor(0, 2, 0) orelse return error.AllocationFailed;

    lean.ctorSet(left, 0, leaf1);
    lean.ctorSet(right, 0, leaf2);
    lean.ctorSet(root, 0, left);
    lean.ctorSet(root, 1, right);

    try testing.expectEqual(@as(i32, 1), lean.objectRc(leaf1));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(leaf2));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(left));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(right));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(root));

    // Clean up (will cascade)
    lean.lean_dec_ref(root);
}

test "refcount: sharing object across multiple parents" {
    const shared = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const parent1 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    const parent2 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;

    lean.lean_inc_ref(shared);
    lean.lean_inc_ref(shared);

    lean.ctorSet(parent1, 0, shared);
    lean.ctorSet(parent2, 0, shared);

    try testing.expectEqual(@as(i32, 3), lean.objectRc(shared));

    lean.lean_dec_ref(parent1);
    lean.lean_dec_ref(parent2);
    lean.lean_dec_ref(shared);
}

test "refcount: initial refcount is 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));

    const arr = lean.allocArray(10) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    try testing.expectEqual(@as(i32, 1), lean.objectRc(arr));

    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    try testing.expectEqual(@as(i32, 1), lean.objectRc(str));
}

test "refcount: decrement to zero frees object" {
    // Create object with explicit control
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));

    // This should free the object (no memory leak)
    lean.lean_dec_ref(obj);
    // Note: Cannot verify object is freed without memory instrumentation
}

test "refcount: multiple inc/dec maintaining balance" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        lean.lean_inc_ref(obj);
        try testing.expectEqual(@as(i32, @intCast(i + 2)), lean.objectRc(obj));
    }

    i = 0;
    while (i < 10) : (i += 1) {
        lean.lean_dec_ref(obj);
        try testing.expectEqual(@as(i32, @intCast(11 - i - 1)), lean.objectRc(obj));
    }

    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));
}

// ============================================================================
// Multi-Threading Tests
// ============================================================================

test "MT object detection on ST object" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Initially ST (single-threaded)
    try testing.expect(!lean.isMt(obj));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj));
}

test "markMt converts ST to MT" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Initially ST
    try testing.expect(!lean.isMt(obj));

    // Mark as MT
    lean.markMt(obj);

    // Now MT (refcount should be negative)
    try testing.expect(lean.isMt(obj));
    try testing.expect(lean.objectRc(obj) < 0);
}

test "bulk reference count increment" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;

    // Bulk increment by 5 (total refcount = 6)
    lean.lean_inc_ref_n(obj, 5);

    // Now manually decrement 5 times
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        lean.lean_dec_ref(obj);
    }

    // Final cleanup (back to refcount 1, will be freed)
    lean.lean_dec_ref(obj);
}

test "MT object sharing simulation" {
    const obj = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;

    // Before sharing across threads, mark as MT
    lean.markMt(obj);
    try testing.expect(lean.isMt(obj));

    // Simulate thread 1 taking reference
    lean.lean_inc_ref(obj);

    // Simulate thread 2 taking reference
    lean.lean_inc_ref(obj);

    // Simulate thread 1 finishing
    lean.lean_dec_ref(obj);

    // Simulate thread 2 finishing
    lean.lean_dec_ref(obj);

    // Final cleanup
    lean.lean_dec_ref(obj);
}

test "scalars are never MT" {
    const scalar = lean.boxUsize(42);

    // Scalars don't have refcounts, so they can't be MT
    try testing.expect(!lean.isMt(scalar));

    // markMt on scalar should be safe (no-op)
    lean.markMt(scalar);
    try testing.expect(!lean.isMt(scalar));
}

test "MT status persists through inc operations" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Mark as MT
    lean.markMt(obj);
    try testing.expect(lean.isMt(obj));

    // Increment (doesn't change MT status)
    lean.lean_inc_ref(obj);
    try testing.expect(lean.isMt(obj)); // Still MT

    // Decrement back (still MT since we used MT increment)
    lean.lean_dec_ref(obj);
    
    // Note: MT status may not persist after dec to refcount 1
    // This is runtime-dependent behavior
}

test "null pointers safe in MT operations" {
    const null_obj: ?*lean.Object = null;

    // MT operations should handle null safely
    lean.lean_inc_ref_n(null_obj, 1);
    
    // markMt forwards to runtime which doesn't handle null, so skip it
    // lean.markMt(null_obj);  // Not tested - lean_mark_mt doesn't handle null

    const is_mt = lean.isMt(null_obj);
    try testing.expect(!is_mt);
}

test "bulk increment with n=1 equivalent to regular" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;

    // Bulk increment by 1
    lean.lean_inc_ref_n(obj, 1);

    // Now refcount is 2, decrement twice
    lean.lean_dec_ref(obj);
    lean.lean_dec_ref(obj);
}

test "bulk increment for MT object" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    
    lean.markMt(obj);
    try testing.expect(lean.isMt(obj));

    // Bulk increment by 3 for MT object
    lean.lean_inc_ref_n(obj, 3);

    // Decrement 3 times
    lean.lean_dec_ref(obj);
    lean.lean_dec_ref(obj);
    lean.lean_dec_ref(obj);

    // Final cleanup
    lean.lean_dec_ref(obj);
}

