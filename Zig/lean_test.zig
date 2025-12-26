const std = @import("std");
const testing = std.testing;
const lean = @import("lean.zig");

// Note: lean.zig currently provides a minimal API focused on core functionality.
// Many functions from a full Lean C API wrapper are not yet implemented.

// ============================================================================
// Basic Type Tests
// ============================================================================

// Note: We don't test Object size directly since it's opaque from lean_raw.
// The Lean runtime guarantees the header layout is 8 bytes through the C ABI.

test "tagged pointer encoding produces odd address" {
    // Tagged pointers have the low bit set (odd address)
    // We test the encoding math without going through the pointer type
    const value: usize = 42;
    const encoded = (value << 1) | 1;
    try testing.expect(encoded & 1 == 1); // Odd address
    try testing.expectEqual(value, encoded >> 1); // Decodes correctly
}

test "tagged pointer zero encodes to 1" {
    // 0 encodes to (0 << 1) | 1 = 1
    const encoded = (0 << 1) | 1;
    try testing.expectEqual(@as(usize, 1), encoded);
}

// ============================================================================
// Boxing/Unboxing Tests
// ============================================================================

test "box and unbox usize" {
    const original: usize = 42;
    const boxed = lean.boxUsize(original);
    const unboxed = lean.unboxUsize(boxed);
    try testing.expectEqual(original, unboxed);
}

test "box large usize values" {
    // Test edge cases for tagged pointer encoding
    const maxTagged: usize = (1 << 62) - 1;
    const boxed = lean.boxUsize(maxTagged);
    const unboxed = lean.unboxUsize(boxed);
    try testing.expectEqual(maxTagged, unboxed);
}

test "boxed usize has tagged pointer format" {
    const original: usize = 123;
    const boxed = lean.boxUsize(original);
    const ptr = @intFromPtr(boxed);

    // Must be odd (tagged pointer)
    try testing.expect(ptr & 1 == 1);

    // Must decode correctly
    try testing.expectEqual(original, ptr >> 1);
}

// ============================================================================
// Constructor Tests
// ============================================================================

test "allocate constructor with no fields" {
    // Unit type / empty constructor
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    try testing.expectEqual(@as(u8, 0), lean.objectTag(obj));
    try testing.expectEqual(@as(u8, 0), lean.objectOther(obj));
}

test "allocate constructor with object fields" {
    // Pair-like constructor with 2 object fields
    const pair = lean.allocCtor(0, 2, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(pair);

    const first = lean.boxUsize(10);
    const second = lean.boxUsize(20);

    lean.ctorSet(pair, 0, first);
    lean.ctorSet(pair, 1, second);

    const retrieved_first = lean.ctorGet(pair, 0);
    const retrieved_second = lean.ctorGet(pair, 1);

    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(retrieved_first));
    try testing.expectEqual(@as(usize, 20), lean.unboxUsize(retrieved_second));
}

test "constructor tag field" {
    const obj = lean.allocCtor(5, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    try testing.expectEqual(@as(u8, 5), lean.objectTag(obj));
}

test "constructor stores numObjs in m_other field" {
    const obj = lean.allocCtor(0, 3, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    try testing.expectEqual(@as(u8, 3), lean.objectOther(obj));
}

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

// ============================================================================
// Array Tests
// ============================================================================

test "allocate array with capacity" {
    const arr = lean.allocArray(10) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    try testing.expectEqual(@as(usize, 0), lean.arraySize(arr));

    const arrObj: *lean.ArrayObject = @ptrCast(@alignCast(arr));
    try testing.expectEqual(@as(usize, 10), arrObj.m_capacity);
}

test "mkArrayWithSize creates presized array" {
    const arr = lean.mkArrayWithSize(5, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    try testing.expectEqual(@as(usize, 3), lean.arraySize(arr));

    const arrObj: *lean.ArrayObject = @ptrCast(@alignCast(arr));
    try testing.expectEqual(@as(usize, 5), arrObj.m_capacity);
}

test "array get and set operations" {
    const arr = lean.mkArrayWithSize(3, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    const val1 = lean.boxUsize(42);
    const val2 = lean.boxUsize(100);
    const val3 = lean.boxUsize(255);

    lean.arraySet(arr, 0, val1);
    lean.arraySet(arr, 1, val2);
    lean.arraySet(arr, 2, val3);

    const retrieved1 = lean.arrayGet(arr, 0);
    const retrieved2 = lean.arrayGet(arr, 1);
    const retrieved3 = lean.arrayGet(arr, 2);

    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(retrieved1));
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(retrieved2));
    try testing.expectEqual(@as(usize, 255), lean.unboxUsize(retrieved3));
}

test "array has correct tag" {
    const arr = lean.allocArray(5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    try testing.expectEqual(lean.Tag.array, lean.objectTag(arr));
}

// ============================================================================
// String Tests
// ============================================================================

test "create string from C string" {
    const str = lean.lean_mk_string("Hello");
    defer lean.lean_dec_ref(str);

    const size = lean.stringSize(str);
    try testing.expectEqual(@as(usize, 6), size); // 5 chars + null terminator
}

test "create string from bytes" {
    const str = lean.lean_mk_string_from_bytes("Test", 4);
    defer lean.lean_dec_ref(str);

    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;
    try testing.expectEqualStrings("Test", cstr[0..len]);
}

test "string cstr returns valid pointer" {
    const str = lean.lean_mk_string_from_bytes("Example", 7);
    defer lean.lean_dec_ref(str);

    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;
    try testing.expectEqualStrings("Example", cstr[0..len]);
}

test "string length counts unicode codepoints" {
    const str = lean.lean_mk_string("Hello");
    defer lean.lean_dec_ref(str);

    const len = lean.stringLen(str);
    try testing.expectEqual(@as(usize, 5), len);
}

test "empty string has size 1 (null terminator)" {
    const str = lean.lean_mk_string_from_bytes("", 0);
    defer lean.lean_dec_ref(str);

    try testing.expectEqual(@as(usize, 1), lean.stringSize(str));
    try testing.expectEqual(@as(usize, 0), lean.stringLen(str));
}

test "string has correct tag" {
    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);

    try testing.expectEqual(lean.Tag.string, lean.objectTag(str));
}

// ============================================================================
// IO Result Tests
// ============================================================================

test "ioResultMkOk creates success result" {
    const value = lean.boxUsize(42);
    const result = lean.ioResultMkOk(value) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(result);

    try testing.expect(lean.ioResultIsOk(result));
    try testing.expect(!lean.ioResultIsError(result));

    const retrieved = lean.ioResultGetValue(result);
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(retrieved));
}

test "ioResultMkError creates error result" {
    // Pass string directly to avoid extra reference that would leak.
    // ioResultMkError takes ownership (obj_arg), so storing in a variable first
    // would require an inc_ref that wouldn't have a matching dec_ref.
    const result = lean.ioResultMkError(lean.lean_mk_string("something failed")) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(result);

    try testing.expect(lean.ioResultIsError(result));
    try testing.expect(!lean.ioResultIsOk(result));
}

test "IO result has correct tag" {
    const ok_result = lean.ioResultMkOk(lean.boxUsize(1)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ok_result);
    try testing.expectEqual(@as(u8, 0), lean.objectTag(ok_result));

    // Pass string directly to avoid extra reference that would leak
    const err_result = lean.ioResultMkError(lean.lean_mk_string("error")) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(err_result);
    try testing.expectEqual(@as(u8, 1), lean.objectTag(err_result));
}

test "allocCtor pre-initializes object fields to boxed(0)" {
    // Allocate constructor with 3 object fields
    const obj = lean.allocCtor(0, 3, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Verify all fields are initialized to boxed(0), not null
    const field0 = lean.ctorGet(obj, 0);
    const field1 = lean.ctorGet(obj, 1);
    const field2 = lean.ctorGet(obj, 2);

    // Check they're tagged pointers (odd address = scalar)
    try testing.expectEqual(@as(usize, 1), @intFromPtr(field0) & 1);
    try testing.expectEqual(@as(usize, 1), @intFromPtr(field1) & 1);
    try testing.expectEqual(@as(usize, 1), @intFromPtr(field2) & 1);

    // Verify they decode to 0
    try testing.expectEqual(@as(usize, 0), lean.unboxUsize(field0));
    try testing.expectEqual(@as(usize, 0), lean.unboxUsize(field1));
    try testing.expectEqual(@as(usize, 0), lean.unboxUsize(field2));
}

test "mkArrayWithSize pre-initializes elements to boxed(0)" {
    // Create array with initial size but don't set elements
    const arr = lean.mkArrayWithSize(5, 10) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Verify all elements are initialized to boxed(0), not null
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        const elem = lean.arrayGet(arr, i);
        // Check it's a tagged pointer (odd address = scalar)
        try testing.expectEqual(@as(usize, 1), @intFromPtr(elem) & 1);
        // Verify it decodes to 0
        try testing.expectEqual(@as(usize, 0), lean.unboxUsize(elem));
    }
}

// ============================================================================
// Recommendations for Test Expansion
// ============================================================================
//
// **Current Coverage**: ~25 tests covering:
// - Basic types and tagged pointers
// - Boxing/unboxing
// - Constructors
// - Reference counting
// - Arrays
// - Strings
// - IO results
//
// **Missing Coverage** (functions not yet exposed in lean.zig):
// - Closure operations
// - Task/thunk operations
// - External class management
// - Scalar arrays (ByteArray, FloatArray)
// - BigInt (mpz) operations
// - More comprehensive string operations
//
// **Property-Based Testing Value**:
//
// Property-based testing would be HIGHLY VALUABLE for this library because:
//
// 1. **Reference Counting Laws**: Critical for memory safety
//    - ∀obj: lean_inc_ref(obj); lean_dec_ref(obj) ≡ identity
//    - Must not leak or double-free
//
// 2. **Encoding/Decoding Round-trips**: Core correctness
//    - ∀x: usize: unboxUsize(boxUsize(x)) ≡ x
//    - Tagged pointer encoding must be bijective
//
// 3. **Array Operations**: Structural integrity
//    - ∀arr, i, v: arrayGet(arraySet(arr, i, v), i) ≡ v
//    - Size/capacity invariants maintained
//
// 4. **Constructor Field Access**: Algebraic invariants
//    - ∀ctor, i, v: ctorGet(ctorSet(ctor, i, v), i) ≡ v
//    - Tag and field count preservation
//
// 5. **String Operations** (when implemented):
//    - UTF-8 validity preserved
//    - Length calculations correct
//    - Concatenation associativity
//
// **Implementation Strategy**:
//
// Zig doesn't have a mature property-based testing framework yet, but you could:
//
// 1. **Manual generators**: Write simple random value generators
//    ```zig
//    fn randomUsize(rng: *std.rand.Random) usize {
//        return rng.int(usize) & ((1 << 62) - 1); // Keep in tagged range
//    }
//    ```
//
// 2. **Test many values**: Loop over ranges/random values
//    ```zig
//    test "boxing round-trip for many values" {
//        var prng = std.rand.DefaultPrng.init(0);
//        const rng = prng.random();
//        var i: usize = 0;
//        while (i < 1000) : (i += 1) {
//            const val = randomUsize(rng);
//            try testing.expectEqual(val, lean.unboxUsize(lean.boxUsize(val)));
//        }
//    }
//    ```
//
// 3. **Shrinking**: When a test fails, manually test nearby values
//
// 4. **Wait for ecosystem**: Keep eye on projects like `zig-quickcheck` or similar
//
// **Verdict**: Property-based testing would catch subtle bugs in:
// - Memory management edge cases
// - Pointer arithmetic errors
// - Off-by-one errors in array/string operations
// - Reference counting leaks
//
// It's worth implementing simple randomized tests even without a full framework.
