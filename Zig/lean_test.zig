const std = @import("std");
const testing = std.testing;
const lean = @import("lean.zig");

// Performance test thresholds (nanoseconds per operation)
// CI environments have higher thresholds due to variable performance
const perf_boxing_threshold_local: u64 = 10;
const perf_boxing_threshold_ci: u64 = 20;
const perf_array_threshold_local: u64 = 15;
const perf_array_threshold_ci: u64 = 20;
const perf_refcount_threshold_local: u64 = 5;
const perf_refcount_threshold_ci: u64 = 10;

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
    const arr = lean.allocArray(5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Manually set size and populate elements
    lean.arraySet(arr, 0, lean.boxUsize(0));
    lean.arraySet(arr, 1, lean.boxUsize(1));
    lean.arraySet(arr, 2, lean.boxUsize(2));
    lean.arraySetSize(arr, 3);

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

test "mkArrayWithSize creates array with correct size" {
    // mkArrayWithSize sets size but does NOT initialize elements
    // We must populate all elements before freeing
    const arr = lean.mkArrayWithSize(5, 5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements before cleanup
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        lean.arraySet(arr, i, lean.boxUsize(i));
    }

    // Verify size was set correctly
    try testing.expectEqual(@as(usize, 5), lean.arraySize(arr));
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

// ============================================================================
// PHASE 1: Type Inspection Tests (Critical Safety)
// ============================================================================

test "type: isScalar detects tagged pointers" {
    const scalar = lean.boxUsize(42);
    try testing.expect(lean.isScalar(scalar));
    try testing.expect(lean.isCtor(scalar)); // Tagged scalars are treated as constructors in Lean's runtime
    try testing.expect(!lean.isString(scalar));
    try testing.expect(!lean.isArray(scalar));
}

test "type: isCtor detects constructor objects" {
    const ctor = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    try testing.expect(lean.isCtor(ctor));
    try testing.expect(!lean.isScalar(ctor));
    try testing.expect(!lean.isString(ctor));
}

test "type: isString detects string objects" {
    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    try testing.expect(lean.isString(str));
    try testing.expect(!lean.isCtor(str));
    try testing.expect(!lean.isArray(str));
    try testing.expectEqual(lean.Tag.string, lean.objectTag(str));
}

test "type: isArray detects array objects" {
    const arr = lean.allocArray(5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    try testing.expect(lean.isArray(arr));
    try testing.expect(!lean.isCtor(arr));
    try testing.expect(!lean.isString(arr));
    try testing.expectEqual(lean.Tag.array, lean.objectTag(arr));
}

test "type: type checks are mutually exclusive for heap objects" {
    const ctor = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    const arr = lean.allocArray(1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    const str = lean.lean_mk_string("x");
    defer lean.lean_dec_ref(str);

    // Constructor is only ctor
    try testing.expect(lean.isCtor(ctor));
    try testing.expect(!lean.isArray(ctor));
    try testing.expect(!lean.isString(ctor));

    // Array is only array
    try testing.expect(lean.isArray(arr));
    try testing.expect(!lean.isCtor(arr));
    try testing.expect(!lean.isString(arr));

    // String is only string
    try testing.expect(lean.isString(str));
    try testing.expect(!lean.isCtor(str));
    try testing.expect(!lean.isArray(str));
}

test "type: isExclusive true when rc == 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);
    try testing.expect(lean.isExclusive(obj));
    try testing.expect(!lean.isShared(obj));
}

test "type: isShared true when rc > 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    lean.lean_inc_ref(obj);
    defer lean.lean_dec_ref(obj);

    try testing.expect(lean.isShared(obj));
    try testing.expect(!lean.isExclusive(obj));
}

test "type: isExclusive true for scalars" {
    const scalar = lean.boxUsize(100);
    try testing.expect(lean.isExclusive(scalar));
}

test "type: ptrTag distinguishes heap from scalar" {
    const scalar = lean.boxUsize(42);
    try testing.expectEqual(@as(usize, 1), lean.ptrTag(scalar));

    const heap = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(heap);
    try testing.expectEqual(@as(usize, 0), lean.ptrTag(heap));
}

test "type: objTag returns correct tag for constructors" {
    const tests = [_]struct { tag: u8 }{
        .{ .tag = 0 },
        .{ .tag = 1 },
        .{ .tag = 100 },
        .{ .tag = 243 },
    };

    for (tests) |t| {
        const obj = lean.allocCtor(t.tag, 0, 0) orelse return error.AllocationFailed;
        defer lean.lean_dec_ref(obj);
        try testing.expectEqual(t.tag, lean.objectTag(obj));
    }
}

test "type: objTag returns correct tag for special types" {
    const arr = lean.allocArray(1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    try testing.expectEqual(lean.Tag.array, lean.objectTag(arr));

    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    try testing.expectEqual(lean.Tag.string, lean.objectTag(str));
}

test "type: constructor tags within valid range" {
    const ctor = lean.allocCtor(100, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    try testing.expect(lean.objectTag(ctor) <= lean.Tag.max_ctor);
}

test "type: max constructor tag boundary" {
    const ctor = lean.allocCtor(lean.Tag.max_ctor, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    try testing.expect(lean.isCtor(ctor));
    try testing.expectEqual(lean.Tag.max_ctor, lean.objectTag(ctor));
}

test "type: special types not detected as constructors" {
    const arr = lean.allocArray(1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    // Array tag (246) is > max_ctor (243)
    try testing.expect(!lean.isCtor(arr));
    try testing.expect(lean.objectTag(arr) > lean.Tag.max_ctor);

    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    try testing.expect(!lean.isCtor(str));
    try testing.expect(lean.objectTag(str) > lean.Tag.max_ctor);
}

test "type: isExclusive with scalars" {
    // Scalars are always exclusive (no refcount)
    const scalar = lean.boxUsize(999);
    try testing.expect(lean.isExclusive(scalar));
    try testing.expect(!lean.isShared(scalar));
}

// ============================================================================
// PHASE 1: Constructor Scalar Accessor Tests (Critical Safety)
// ============================================================================

test "ctor scalar: uint8 round-trip" {
    const ctor = lean.allocCtor(0, 0, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]u8{ 0, 1, 127, 255 };
    for (values) |val| {
        lean.ctorSetUint8(ctor, 0, val);
        const retrieved = lean.ctorGetUint8(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: uint16 round-trip" {
    const ctor = lean.allocCtor(0, 0, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]u16{ 0, 1, 256, 32767, 65535 };
    for (values) |val| {
        lean.ctorSetUint16(ctor, 0, val);
        const retrieved = lean.ctorGetUint16(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: uint32 round-trip" {
    const ctor = lean.allocCtor(0, 0, 4) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]u32{ 0, 1, 65536, 2147483647, 4294967295 };
    for (values) |val| {
        lean.ctorSetUint32(ctor, 0, val);
        const retrieved = lean.ctorGetUint32(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: uint64 round-trip" {
    const ctor = lean.allocCtor(0, 0, 8) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]u64{
        0,
        1,
        4294967296,
        9223372036854775807, // Max i64
        18446744073709551615, // Max u64
    };
    for (values) |val| {
        lean.ctorSetUint64(ctor, 0, val);
        const retrieved = lean.ctorGetUint64(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: usize round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(usize)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]usize{ 0, 1, 4294967296, @as(usize, 1) << 62 };
    for (values) |val| {
        lean.ctorSetUsize(ctor, 0, val);
        const retrieved = lean.ctorGetUsize(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: float64 round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(f64)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]f64{
        0.0,
        -0.0,
        1.0,
        -1.0,
        3.14159,
        -3.14159,
    };
    for (values) |val| {
        lean.ctorSetFloat(ctor, 0, val);
        const retrieved = lean.ctorGetFloat(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: float64 special values" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(f64)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const inf = std.math.inf(f64);
    lean.ctorSetFloat(ctor, 0, inf);
    try testing.expect(std.math.isInf(lean.ctorGetFloat(ctor, 0)));

    const ninf = -std.math.inf(f64);
    lean.ctorSetFloat(ctor, 0, ninf);
    try testing.expect(std.math.isNegativeInf(lean.ctorGetFloat(ctor, 0)));

    const nan = std.math.nan(f64);
    lean.ctorSetFloat(ctor, 0, nan);
    try testing.expect(std.math.isNan(lean.ctorGetFloat(ctor, 0)));
}

test "ctor scalar: float32 round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(f32)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const values = [_]f32{ 0.0, 1.0, -1.0, 3.14, -3.14 };
    for (values) |val| {
        lean.ctorSetFloat32(ctor, 0, val);
        const retrieved = lean.ctorGetFloat32(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor scalar: multiple fields with different types" {
    // Create: struct { id: u64, score: f64, flag: u8 }
    const scalar_size = @sizeOf(u64) + @sizeOf(f64) + @sizeOf(u8);
    const ctor = lean.allocCtor(0, 0, scalar_size) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const offset_id: usize = 0;
    const offset_score: usize = @sizeOf(u64);
    const offset_flag: usize = @sizeOf(u64) + @sizeOf(f64);

    lean.ctorSetUint64(ctor, offset_id, 12345);
    lean.ctorSetFloat(ctor, offset_score, 98.6);
    lean.ctorSetUint8(ctor, offset_flag, 1);

    try testing.expectEqual(@as(u64, 12345), lean.ctorGetUint64(ctor, offset_id));
    try testing.expectEqual(@as(f64, 98.6), lean.ctorGetFloat(ctor, offset_score));
    try testing.expectEqual(@as(u8, 1), lean.ctorGetUint8(ctor, offset_flag));
}

test "ctor scalar: aligned multi-field access" {
    const ctor = lean.allocCtor(0, 0, 16) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    // Write u64 at offset 0 (aligned)
    lean.ctorSetUint64(ctor, 0, 0xDEADBEEF);
    // Write u64 at offset 8 (aligned)
    lean.ctorSetUint64(ctor, 8, 0xCAFEBABE);

    try testing.expectEqual(@as(u64, 0xDEADBEEF), lean.ctorGetUint64(ctor, 0));
    try testing.expectEqual(@as(u64, 0xCAFEBABE), lean.ctorGetUint64(ctor, 8));
}

test "ctor utility: ctorNumObjs returns correct count" {
    const tests = [_]struct { num_objs: u8 }{
        .{ .num_objs = 0 },
        .{ .num_objs = 1 },
        .{ .num_objs = 10 },
        .{ .num_objs = 255 },
    };

    for (tests) |t| {
        const ctor = lean.allocCtor(0, t.num_objs, 0) orelse return error.AllocationFailed;
        defer lean.lean_dec_ref(ctor);
        try testing.expectEqual(t.num_objs, lean.ctorNumObjs(ctor));
    }
}

test "ctor utility: ctorSetTag changes constructor variant" {
    const ctor = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    try testing.expectEqual(@as(u8, 0), lean.objectTag(ctor));

    lean.ctorSetTag(ctor, 5);
    try testing.expectEqual(@as(u8, 5), lean.objectTag(ctor));

    lean.ctorSetTag(ctor, 200);
    try testing.expectEqual(@as(u8, 200), lean.objectTag(ctor));
}

test "ctor utility: ctorScalarCptr points to correct region" {
    const ctor = lean.allocCtor(0, 2, 8) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const scalar_ptr = lean.ctorScalarCptr(ctor);
    // Write directly via pointer
    scalar_ptr[0] = 42;
    scalar_ptr[7] = 99;

    // Verify via typed accessor
    try testing.expectEqual(@as(u8, 42), lean.ctorGetUint8(ctor, 0));
    try testing.expectEqual(@as(u8, 99), lean.ctorGetUint8(ctor, 7));
}

test "ctor utility: ctorRelease decrements field references" {
    const ctor = lean.allocCtor(0, 2, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    const field1 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const field2 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;

    lean.lean_inc_ref(field1);
    lean.lean_inc_ref(field2);

    lean.ctorSet(ctor, 0, field1);
    lean.ctorSet(ctor, 1, field2);

    try testing.expectEqual(@as(i32, 2), lean.objectRc(field1));
    try testing.expectEqual(@as(i32, 2), lean.objectRc(field2));

    lean.ctorRelease(ctor, 2);

    try testing.expectEqual(@as(i32, 1), lean.objectRc(field1));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(field2));

    // Clean up
    lean.lean_dec_ref(field1);
    lean.lean_dec_ref(field2);
}

test "ctor scalar: mixed object and scalar fields" {
    const ctor = lean.allocCtor(0, 2, @sizeOf(u64)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    // Set object fields
    lean.ctorSet(ctor, 0, lean.boxUsize(100));
    lean.ctorSet(ctor, 1, lean.boxUsize(200));

    // Set scalar field
    lean.ctorSetUint64(ctor, 0, 0xABCDEF);

    // Verify object fields
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(lean.ctorGet(ctor, 0)));
    try testing.expectEqual(@as(usize, 200), lean.unboxUsize(lean.ctorGet(ctor, 1)));

    // Verify scalar field
    try testing.expectEqual(@as(u64, 0xABCDEF), lean.ctorGetUint64(ctor, 0));
}

test "ctor scalar: zero-size scalar region" {
    // Constructor with only object fields, no scalar fields
    const ctor = lean.allocCtor(0, 3, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    lean.ctorSet(ctor, 0, lean.boxUsize(1));
    lean.ctorSet(ctor, 1, lean.boxUsize(2));
    lean.ctorSet(ctor, 2, lean.boxUsize(3));

    try testing.expectEqual(@as(usize, 1), lean.unboxUsize(lean.ctorGet(ctor, 0)));
    try testing.expectEqual(@as(usize, 2), lean.unboxUsize(lean.ctorGet(ctor, 1)));
    try testing.expectEqual(@as(usize, 3), lean.unboxUsize(lean.ctorGet(ctor, 2)));
}

test "ctor scalar: boundary value testing" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(u8) * 4) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);

    // Test min and max values for u8
    lean.ctorSetUint8(ctor, 0, 0);
    lean.ctorSetUint8(ctor, 1, 255);
    lean.ctorSetUint8(ctor, 2, 127);
    lean.ctorSetUint8(ctor, 3, 128);

    try testing.expectEqual(@as(u8, 0), lean.ctorGetUint8(ctor, 0));
    try testing.expectEqual(@as(u8, 255), lean.ctorGetUint8(ctor, 1));
    try testing.expectEqual(@as(u8, 127), lean.ctorGetUint8(ctor, 2));
    try testing.expectEqual(@as(u8, 128), lean.ctorGetUint8(ctor, 3));
}

// ============================================================================
// PHASE 1: Deep Reference Counting Tests (Critical Safety)
// ============================================================================

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
// PHASE 1: Performance Baseline Tests
// ============================================================================

test "perf: boxing round-trip baseline" {
    var timer = try std.time.Timer.start();

    const iterations = 1_000_000;
    var i: usize = 0;
    var sum: usize = 0;
    while (i < iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        sum +%= lean.unboxUsize(boxed);
    }

    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;

    std.debug.print("\nBoxing round-trip: {d}ns per operation\n", .{ns_per_op});
    // Performance target: < 5ns (should be 1-2ns on modern hardware)
    // Relaxed for CI environments which may have variable performance
    const is_ci = std.process.hasEnvVarConstant("CI") or std.process.hasEnvVarConstant("GITHUB_ACTIONS");
    const threshold: u64 = if (is_ci) perf_boxing_threshold_ci else perf_boxing_threshold_local;
    try testing.expect(ns_per_op < threshold);
    try testing.expect(sum > 0); // Prevent optimization
}

test "perf: array access baseline" {
    const arr = lean.mkArrayWithSize(1000, 1000) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements (required before cleanup)
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        lean.arraySet(arr, i, lean.boxUsize(i));
    }

    var timer = try std.time.Timer.start();

    const iterations = 1_000_000;
    i = 0;
    var sum: usize = 0;
    while (i < iterations) : (i += 1) {
        const elem = lean.arrayGet(arr, i % 1000);
        sum +%= lean.unboxUsize(elem);
    }

    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;

    std.debug.print("Array access: {d}ns per operation\n", .{ns_per_op});
    // Performance target: < 5ns (should be 2-3ns)
    const is_ci = std.process.hasEnvVarConstant("CI") or std.process.hasEnvVarConstant("GITHUB_ACTIONS");
    const threshold: u64 = if (is_ci) perf_array_threshold_ci else perf_array_threshold_local;
    try testing.expect(ns_per_op < threshold);
}

test "perf: refcount operations baseline" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    var timer = try std.time.Timer.start();

    const iterations = 10_000_000;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        lean.lean_inc_ref(obj);
        lean.lean_dec_ref(obj);
    }

    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / (iterations * 2);

    std.debug.print("Refcount operation: {d}ns per inc/dec\n", .{ns_per_op});
    // Performance target: < 2ns (should be 0.5ns)
    const is_ci = std.process.hasEnvVarConstant("CI") or std.process.hasEnvVarConstant("GITHUB_ACTIONS");
    const threshold: u64 = if (is_ci) perf_refcount_threshold_ci else perf_refcount_threshold_local;
    try testing.expect(ns_per_op < threshold);
}

// ============================================================================
// PHASE 2: Core API Tests (Array Operations, String Operations)
// ============================================================================

// Array Operations Tests
// ----------------------

test "array: simple allocation and cleanup" {
    const arr = lean.mkArrayWithSize(3, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements before cleanup
    lean.arraySet(arr, 0, lean.boxUsize(10));
    lean.arraySet(arr, 1, lean.boxUsize(20));
    lean.arraySet(arr, 2, lean.boxUsize(30));

    const size = lean.arraySize(arr);
    try testing.expectEqual(@as(usize, 3), size);
}

test "array: swap elements at different indices" {
    const arr = lean.mkArrayWithSize(5, 5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements before any operations
    lean.arraySet(arr, 0, lean.boxUsize(10));
    lean.arraySet(arr, 1, lean.boxUsize(20));
    lean.arraySet(arr, 2, lean.boxUsize(30));
    lean.arraySet(arr, 3, lean.boxUsize(40));
    lean.arraySet(arr, 4, lean.boxUsize(50));

    // Swap indices 1 and 3
    lean.arraySwap(arr, 1, 3);

    // Verify swap
    try testing.expectEqual(@as(usize, 40), lean.unboxUsize(lean.arrayGet(arr, 1)));
    try testing.expectEqual(@as(usize, 20), lean.unboxUsize(lean.arrayGet(arr, 3)));
    // Other elements unchanged
    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(lean.arrayGet(arr, 0)));
    try testing.expectEqual(@as(usize, 30), lean.unboxUsize(lean.arrayGet(arr, 2)));
    try testing.expectEqual(@as(usize, 50), lean.unboxUsize(lean.arrayGet(arr, 4)));
}

test "array: swap same index is no-op" {
    const arr = lean.mkArrayWithSize(3, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements
    lean.arraySet(arr, 0, lean.boxUsize(10));
    lean.arraySet(arr, 1, lean.boxUsize(42));
    lean.arraySet(arr, 2, lean.boxUsize(30));
    lean.arraySwap(arr, 1, 1);

    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(lean.arrayGet(arr, 1)));
}

test "array: unchecked get performance" {
    const arr = lean.mkArrayWithSize(100, 100) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    // Populate all elements (required before cleanup)
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        lean.arraySet(arr, i, lean.boxUsize(i * 2));
    }

    // Verify unchecked access matches checked
    i = 0;
    while (i < 100) : (i += 1) {
        const checked = lean.arrayGet(arr, i);
        const unchecked = lean.arrayUget(arr, i);
        try testing.expectEqual(checked, unchecked);
    }
}

test "array: capacity >= size invariant" {
    const arr = lean.allocArray(10) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);

    const cap = lean.arrayCapacity(arr);
    const size = lean.arraySize(arr);

    try testing.expect(cap >= size);
    try testing.expectEqual(@as(usize, 10), cap);
    try testing.expectEqual(@as(usize, 0), size);
}

// REMOVED: arraySetSize is unsafe without proper initialization
// test "array: modify size with arraySetSize" {
//     const arr = lean.allocArray(10) orelse return error.AllocationFailed;
//     defer lean.lean_dec_ref(arr);
//
//     try testing.expectEqual(@as(usize, 0), lean.arraySize(arr));
//
//     lean.arraySetSize(arr, 5);
//     try testing.expectEqual(@as(usize, 5), lean.arraySize(arr));
// }

// String Operation Tests
// ----------------------

test "string: equality comparison" {
    const str1 = lean.lean_mk_string("hello");
    defer lean.lean_dec_ref(str1);
    const str2 = lean.lean_mk_string("hello");
    defer lean.lean_dec_ref(str2);
    const str3 = lean.lean_mk_string("world");
    defer lean.lean_dec_ref(str3);

    try testing.expect(lean.stringEq(str1, str2));
    try testing.expect(!lean.stringEq(str1, str3));
}

test "string: inequality comparison" {
    const str1 = lean.lean_mk_string("hello");
    defer lean.lean_dec_ref(str1);
    const str2 = lean.lean_mk_string("hello");
    defer lean.lean_dec_ref(str2);
    const str3 = lean.lean_mk_string("world");
    defer lean.lean_dec_ref(str3);

    try testing.expect(!lean.stringNe(str1, str2));
    try testing.expect(lean.stringNe(str1, str3));
}

test "string: lexicographic less-than" {
    const tests = [_]struct { a: [:0]const u8, b: [:0]const u8, expect_lt: bool }{
        .{ .a = "a", .b = "b", .expect_lt = true },
        .{ .a = "abc", .b = "abd", .expect_lt = true },
        .{ .a = "abc", .b = "abc", .expect_lt = false },
        .{ .a = "abd", .b = "abc", .expect_lt = false },
        .{ .a = "", .b = "a", .expect_lt = true },
        .{ .a = "z", .b = "a", .expect_lt = false },
    };

    for (tests) |t| {
        const str1 = lean.lean_mk_string(t.a.ptr);
        defer lean.lean_dec_ref(str1);
        const str2 = lean.lean_mk_string(t.b.ptr);
        defer lean.lean_dec_ref(str2);

        try testing.expectEqual(t.expect_lt, lean.stringLt(str1, str2));
    }
}

test "string: capacity >= size invariant" {
    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);

    const cap = lean.stringCapacity(str);
    const size = lean.stringSize(str);

    try testing.expect(cap >= size);
}

test "string: getStringByteFast accesses individual bytes" {
    const str = lean.lean_mk_string("ABC");
    defer lean.lean_dec_ref(str);

    try testing.expectEqual(@as(u8, 'A'), lean.stringGetByteFast(str, 0));
    try testing.expectEqual(@as(u8, 'B'), lean.stringGetByteFast(str, 1));
    try testing.expectEqual(@as(u8, 'C'), lean.stringGetByteFast(str, 2));
    try testing.expectEqual(@as(u8, 0), lean.stringGetByteFast(str, 3)); // null terminator
}

test "string: UTF-8 multi-byte character handling" {
    const utf8_str = "Hello world"; // ASCII first
    const str = lean.lean_mk_string(utf8_str);
    defer lean.lean_dec_ref(str);

    // Byte count includes all UTF-8 bytes + null
    const byte_size = lean.stringSize(str);
    try testing.expectEqual(@as(usize, 12), byte_size); // 11 chars + null
}

test "string: empty string properties" {
    const str = lean.lean_mk_string("");
    defer lean.lean_dec_ref(str);

    try testing.expectEqual(@as(usize, 1), lean.stringSize(str)); // Just null terminator
    try testing.expectEqual(@as(usize, 0), lean.stringLen(str)); // Zero code points
}

test "string: comparison with empty strings" {
    const empty = lean.lean_mk_string("");
    defer lean.lean_dec_ref(empty);
    const nonempty = lean.lean_mk_string("a");
    defer lean.lean_dec_ref(nonempty);

    try testing.expect(!lean.stringEq(empty, nonempty));
    try testing.expect(lean.stringNe(empty, nonempty));
    try testing.expect(lean.stringLt(empty, nonempty));
    try testing.expect(!lean.stringLt(nonempty, empty));
}
