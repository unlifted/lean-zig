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

    // Verify size was set correctly
    try testing.expectEqual(@as(usize, 3), lean.arraySize(arr));

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
// ============================================================================
// PHASE 3: Scalar Array Tests
// ============================================================================

// Note: We can't create scalar arrays directly without calling Lean runtime
// allocation functions that aren't exposed yet. These tests demonstrate the
// API and will work once we have scalar array creation functions.

// TODO: Once we have lean_alloc_sarray or similar, add these tests:
// - Create ByteArray and verify structure
// - Access and modify bytes
// - FloatArray operations
// - Empty scalar array edge case
// - Large scalar array performance

// For now, we test the type detection function with mock structures
test "sarray: isSarray type detection" {
    // This test verifies that isSarray correctly identifies scalar arrays
    // by checking the tag field. We can test this with a manually created
    // header structure.

    // Create a minimal object with sarray tag
    const size = @sizeOf(lean.ScalarArrayObject);
    const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 0;
    obj.m_capacity = 0;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);
    try testing.expect(lean.isSarray(as_obj));
    try testing.expect(!lean.isArray(as_obj));
    try testing.expect(!lean.isString(as_obj));
}

test "sarray: accessor functions with mock structure" {
    // Test that our accessor functions correctly read the fields
    const size = @sizeOf(lean.ScalarArrayObject) + 16; // + some data
    const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 10;
    obj.m_capacity = 20;
    obj.m_elem_size = 1; // ByteArray

    const as_obj: lean.obj_arg = @ptrCast(obj);

    try testing.expectEqual(@as(usize, 10), lean.sarraySize(as_obj));
    try testing.expectEqual(@as(usize, 20), lean.sarrayCapacity(as_obj));
    try testing.expectEqual(@as(usize, 1), lean.sarrayElemSize(as_obj));
}

test "sarray: data pointer calculation" {
    // Verify that sarrayCptr returns pointer immediately after header
    const total_size = @sizeOf(lean.ScalarArrayObject) + 256; // + data buffer
    const mem = std.testing.allocator.alloc(u8, total_size) catch unreachable;
    defer std.testing.allocator.free(mem);

    // Initialize with known pattern
    for (mem, 0..) |*byte, i| {
        byte.* = @intCast(i & 0xFF);
    }

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 256;
    obj.m_capacity = 256;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);
    const data = lean.sarrayCptr(as_obj);

    // Data should point to memory right after the header
    const header_end = @sizeOf(lean.ScalarArrayObject);
    try testing.expectEqual(mem[header_end], data[0]);
}

test "sarray: setSize mutation" {
    const size = @sizeOf(lean.ScalarArrayObject);
    const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 10;
    obj.m_capacity = 20;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    lean.sarraySetSize(as_obj, 15);
    try testing.expectEqual(@as(usize, 15), lean.sarraySize(as_obj));
}

test "sarray: capacity >= size invariant" {
    const size = @sizeOf(lean.ScalarArrayObject);
    const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 10;
    obj.m_capacity = 20;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    const cap = lean.sarrayCapacity(as_obj);
    const sz = lean.sarraySize(as_obj);
    try testing.expect(cap >= sz);
}

test "sarray: different element sizes" {
    // Test element size field for different scalar array types
    const test_cases = [_]struct { elem_size: usize, array_type: []const u8 }{
        .{ .elem_size = 1, .array_type = "ByteArray" },
        .{ .elem_size = 4, .array_type = "Float32Array" },
        .{ .elem_size = 8, .array_type = "Float64Array" },
    };

    for (test_cases) |tc| {
        const size = @sizeOf(lean.ScalarArrayObject);
        const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
        defer std.testing.allocator.free(mem);

        const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
        obj.m_header.m_tag = lean.Tag.sarray;
        obj.m_header.m_rc = 1;
        obj.m_size = 0;
        obj.m_capacity = 0;
        obj.m_elem_size = tc.elem_size;

        const as_obj: lean.obj_arg = @ptrCast(obj);
        try testing.expectEqual(tc.elem_size, lean.sarrayElemSize(as_obj));
    }
}

test "sarray: simulate byte array access pattern" {
    // Simulate how you'd work with a ByteArray
    const data_size: usize = 100;
    const total_size = @sizeOf(lean.ScalarArrayObject) + data_size;
    const mem = std.testing.allocator.alloc(u8, total_size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = data_size;
    obj.m_capacity = data_size;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    // Write pattern to byte array
    const data = lean.sarrayCptr(as_obj);
    const bytes: [*]u8 = @ptrCast(data);
    var i: usize = 0;
    while (i < data_size) : (i += 1) {
        bytes[i] = @intCast(i % 256);
    }

    // Read back and verify
    i = 0;
    while (i < data_size) : (i += 1) {
        try testing.expectEqual(@as(u8, @intCast(i % 256)), bytes[i]);
    }
}

test "sarray: simulate float array access pattern" {
    // Simulate how you'd work with a FloatArray (f64)
    const elem_count: usize = 10;
    const elem_size: usize = @sizeOf(f64);
    const data_size = elem_count * elem_size;
    const total_size = @sizeOf(lean.ScalarArrayObject) + data_size;
    const mem = std.testing.allocator.alloc(u8, total_size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = elem_count;
    obj.m_capacity = elem_count;
    obj.m_elem_size = elem_size;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    // Write floats
    const data = lean.sarrayCptr(as_obj);
    const floats: [*]f64 = @ptrCast(@alignCast(data));
    var i: usize = 0;
    while (i < elem_count) : (i += 1) {
        floats[i] = @as(f64, @floatFromInt(i)) * 1.5;
    }

    // Read back and verify
    i = 0;
    while (i < elem_count) : (i += 1) {
        const expected = @as(f64, @floatFromInt(i)) * 1.5;
        try testing.expectEqual(expected, floats[i]);
    }
}

test "sarray: empty scalar array" {
    const size = @sizeOf(lean.ScalarArrayObject);
    const mem = std.testing.allocator.alloc(u8, size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = 0;
    obj.m_capacity = 0;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    try testing.expectEqual(@as(usize, 0), lean.sarraySize(as_obj));
    try testing.expect(lean.isSarray(as_obj));
}

test "sarray: distinguish from object array" {
    // Verify scalar arrays and object arrays are distinct
    const sarray_size = @sizeOf(lean.ScalarArrayObject);
    const sarray_mem = std.testing.allocator.alloc(u8, sarray_size) catch unreachable;
    defer std.testing.allocator.free(sarray_mem);

    const sarray_obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(sarray_mem.ptr));
    sarray_obj.m_header.m_tag = lean.Tag.sarray;
    sarray_obj.m_header.m_rc = 1;
    sarray_obj.m_size = 0;
    sarray_obj.m_capacity = 0;
    sarray_obj.m_elem_size = 1;

    const array_size = @sizeOf(lean.ArrayObject);
    const array_mem = std.testing.allocator.alloc(u8, array_size) catch unreachable;
    defer std.testing.allocator.free(array_mem);

    const array_obj: *lean.ArrayObject = @ptrCast(@alignCast(array_mem.ptr));
    array_obj.m_header.m_tag = lean.Tag.array;
    array_obj.m_header.m_rc = 1;
    array_obj.m_size = 0;
    array_obj.m_capacity = 0;

    const sarray_ptr: lean.obj_arg = @ptrCast(sarray_obj);
    const array_ptr: lean.obj_arg = @ptrCast(array_obj);

    try testing.expect(lean.isSarray(sarray_ptr));
    try testing.expect(!lean.isArray(sarray_ptr));

    try testing.expect(lean.isArray(array_ptr));
    try testing.expect(!lean.isSarray(array_ptr));
}

test "sarray: performance baseline for byte access" {
    // Test that scalar array access is efficient
    const data_size: usize = 10000;
    const total_size = @sizeOf(lean.ScalarArrayObject) + data_size;
    const mem = std.testing.allocator.alloc(u8, total_size) catch unreachable;
    defer std.testing.allocator.free(mem);

    const obj: *lean.ScalarArrayObject = @ptrCast(@alignCast(mem.ptr));
    obj.m_header.m_tag = lean.Tag.sarray;
    obj.m_header.m_rc = 1;
    obj.m_size = data_size;
    obj.m_capacity = data_size;
    obj.m_elem_size = 1;

    const as_obj: lean.obj_arg = @ptrCast(obj);

    var timer = std.time.Timer.start() catch unreachable;

    const iterations = 1_000_000;
    const data = lean.sarrayCptr(as_obj);
    const bytes: [*]u8 = @ptrCast(data);

    var i: usize = 0;
    var sum: u64 = 0;
    while (i < iterations) : (i += 1) {
        sum +%= bytes[i % data_size];
    }

    const elapsed_ns = timer.read();
    const ns_per_access = elapsed_ns / iterations;

    std.debug.print("\nScalar array access: {d}ns per operation (sum={d})\n", .{ ns_per_access, sum });

    // Should be very fast - just pointer arithmetic + load
    // Higher threshold due to cache effects with large iteration count
    const is_ci = std.process.hasEnvVarConstant("CI") or std.process.hasEnvVarConstant("GITHUB_ACTIONS");
    const threshold: u64 = if (is_ci) 15 else 10;
    try testing.expect(ns_per_access < threshold);
}
// ============================================================================
// PHASE 4: Closures & Advanced IO Tests
// ============================================================================

// Closure Tests

test "closure: allocation and basic accessors" {
    // Allocate a closure: function that takes 3 params, 1 already fixed
    const mock_fn: *const anyopaque = @ptrFromInt(0x1000); // Mock function pointer
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 3, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    // Verify it's a closure
    try testing.expect(lean.isClosure(closure));
    try testing.expect(!lean.isThunk(closure));
    try testing.expect(!lean.isTask(closure));

    // Verify metadata
    try testing.expectEqual(@as(u16, 3), lean.closureArity(closure));
    try testing.expectEqual(@as(u16, 1), lean.closureNumFixed(closure));

    // Verify function pointer (store casted value for clarity)
    const expected_fn_ptr: *anyopaque = @ptrCast(@constCast(mock_fn));
    const fun_ptr = lean.closureFun(closure);
    try testing.expect(fun_ptr == expected_fn_ptr);
}

test "closure: setting and getting fixed arguments" {
    const mock_fn: *const anyopaque = @ptrFromInt(0x2000);
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 4, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    // Set fixed arguments
    const arg0 = lean.boxUsize(42);
    const arg1 = lean.boxUsize(84);

    lean.closureSet(closure, 0, arg0);
    lean.closureSet(closure, 1, arg1);

    // Get arguments back
    const retrieved0 = lean.closureGet(closure, 0);
    const retrieved1 = lean.closureGet(closure, 1);

    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(retrieved0));
    try testing.expectEqual(@as(usize, 84), lean.unboxUsize(retrieved1));
}

test "closure: closureArgCptr pointer access" {
    const mock_fn: *const anyopaque = @ptrFromInt(0x3000);
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 5, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    // Set arguments
    lean.closureSet(closure, 0, lean.boxUsize(10));
    lean.closureSet(closure, 1, lean.boxUsize(20));
    lean.closureSet(closure, 2, lean.boxUsize(30));

    // Access via pointer
    const args = lean.closureArgCptr(closure);

    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(args[0]));
    try testing.expectEqual(@as(usize, 20), lean.unboxUsize(args[1]));
    try testing.expectEqual(@as(usize, 30), lean.unboxUsize(args[2]));
}

test "closure: zero fixed arguments" {
    // Closure with no captured args yet (will need all params when called)
    const mock_fn: *const anyopaque = @ptrFromInt(0x4000);
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 2, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    try testing.expectEqual(@as(u16, 2), lean.closureArity(closure));
    try testing.expectEqual(@as(u16, 0), lean.closureNumFixed(closure));
}

test "closure: fully saturated" {
    // Closure where all params are fixed (ready to call)
    const mock_fn: *const anyopaque = @ptrFromInt(0x5000);
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 2, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    lean.closureSet(closure, 0, lean.boxUsize(100));
    lean.closureSet(closure, 1, lean.boxUsize(200));

    // When arity == num_fixed, closure is fully saturated
    const arity = lean.closureArity(closure);
    const fixed = lean.closureNumFixed(closure);
    try testing.expectEqual(arity, fixed);
}

test "closure: reference counting for captured objects" {
    const mock_fn: *const anyopaque = @ptrFromInt(0x6000);
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 3, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    // Create an object to capture
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    _ = lean.objectRc(obj); // Just to use it

    // Capture it in closure (closureSet takes ownership)
    lean.closureSet(closure, 0, obj);

    // Object is now owned by closure, we shouldn't dec_ref it
    // When closure is freed, it will dec_ref the captured object
}

test "closure: multiple closures sharing object" {
    const mock_fn: *const anyopaque = @ptrFromInt(0x7000);

    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);

    // Create two closures that will share the object
    const closure1 = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 2, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure1);

    const closure2 = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 2, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure2);

    // Share the object between closures
    lean.lean_inc_ref(obj); // One ref for closure1
    lean.closureSet(closure1, 0, obj);

    lean.lean_inc_ref(obj); // One ref for closure2
    lean.closureSet(closure2, 0, obj);

    // obj now has rc=3: our defer + closure1 + closure2
    try testing.expectEqual(@as(i32, 3), lean.objectRc(obj));
}

test "closure: partial application scenario" {
    // Simulate currying: f(a, b, c) => f(a) returns closure g(b, c)
    const mock_fn: *const anyopaque = @ptrFromInt(0x8000);

    // First application: bind 'a'
    const partial1 = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), 3, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(partial1);
    lean.closureSet(partial1, 0, lean.boxUsize(10));

    try testing.expectEqual(@as(u16, 3), lean.closureArity(partial1));
    try testing.expectEqual(@as(u16, 1), lean.closureNumFixed(partial1));

    // Remaining params: 3 - 1 = 2
    const remaining = lean.closureArity(partial1) - lean.closureNumFixed(partial1);
    try testing.expectEqual(@as(u16, 2), remaining);
}

test "closure: iterate over captured args" {
    const mock_fn: *const anyopaque = @ptrFromInt(0x9000);
    const num_args: u16 = 5;
    const closure = lean.lean_alloc_closure(@ptrCast(@constCast(mock_fn)), num_args, num_args) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(closure);

    // Populate all arguments
    var i: usize = 0;
    while (i < num_args) : (i += 1) {
        lean.closureSet(closure, i, lean.boxUsize(i * 10));
    }

    // Verify via iteration
    const args = lean.closureArgCptr(closure);
    i = 0;
    while (i < num_args) : (i += 1) {
        const val = lean.unboxUsize(args[i]);
        try testing.expectEqual(i * 10, val);
    }
}

// Advanced IO Result Tests

test "io: ioResultGetValue extraction" {
    const value = lean.boxUsize(12345);
    const result = lean.ioResultMkOk(value);
    defer lean.lean_dec_ref(result);

    try testing.expect(lean.ioResultIsOk(result));

    const extracted = lean.ioResultGetValue(result);
    try testing.expectEqual(@as(usize, 12345), lean.unboxUsize(extracted));
}

test "io: error result with string message" {
    const err_msg = lean.lean_mk_string_from_bytes("operation failed", 16);
    const result = lean.ioResultMkError(err_msg);
    defer lean.lean_dec_ref(result);

    try testing.expect(lean.ioResultIsError(result));
    try testing.expect(!lean.ioResultIsOk(result));

    // Extract error message
    const extracted = lean.ioResultGetValue(result);
    try testing.expect(lean.isString(extracted));
}

test "io: success with complex object" {
    const obj = lean.allocCtor(1, 2, 0) orelse return error.AllocationFailed;
    lean.ctorSet(obj, 0, lean.boxUsize(42));
    lean.ctorSet(obj, 1, lean.boxUsize(84));

    const result = lean.ioResultMkOk(obj);
    defer lean.lean_dec_ref(result);

    try testing.expect(lean.ioResultIsOk(result));

    const extracted = lean.ioResultGetValue(result);
    try testing.expect(lean.isCtor(extracted));
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(lean.ctorGet(extracted, 0)));
}

test "io: result tag correctness" {
    const ok_result = lean.ioResultMkOk(lean.boxUsize(1));
    defer lean.lean_dec_ref(ok_result);

    const err_result = lean.ioResultMkError(lean.boxUsize(2));
    defer lean.lean_dec_ref(err_result);

    // Tag 0 = ok, Tag 1 = error
    try testing.expectEqual(@as(u8, 0), lean.objectTag(ok_result));
    try testing.expectEqual(@as(u8, 1), lean.objectTag(err_result));
}

test "io: round-trip through result" {
    const original = lean.allocArray(5) orelse return error.AllocationFailed;
    lean.arraySet(original, 0, lean.boxUsize(99));

    // Wrap in success
    const result = lean.ioResultMkOk(original);
    defer lean.lean_dec_ref(result);

    // Extract and verify
    try testing.expect(lean.ioResultIsOk(result));
    const extracted = lean.ioResultGetValue(result);

    try testing.expect(lean.isArray(extracted));
    try testing.expectEqual(@as(usize, 99), lean.unboxUsize(lean.arrayGet(extracted, 0)));
}

test "io: nested results" {
    // Create Result (Result A)
    const inner_value = lean.boxUsize(42);
    const inner_result = lean.ioResultMkOk(inner_value);

    const outer_result = lean.ioResultMkOk(inner_result);
    defer lean.lean_dec_ref(outer_result);

    // Unwrap outer
    try testing.expect(lean.ioResultIsOk(outer_result));
    const middle = lean.ioResultGetValue(outer_result);

    // Unwrap inner
    try testing.expect(lean.ioResultIsOk(middle));
    const final_value = lean.ioResultGetValue(middle);

    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(final_value));
}

test "io: error propagation pattern" {
    // Simulate error handling chain
    const errors = [_][]const u8{
        "file not found",
        "permission denied",
        "disk full",
    };

    for (errors) |err_str| {
        const msg = lean.lean_mk_string_from_bytes(err_str.ptr, err_str.len);
        const result = lean.ioResultMkError(msg);
        defer lean.lean_dec_ref(result);

        try testing.expect(lean.ioResultIsError(result));

        const extracted = lean.ioResultGetValue(result);
        try testing.expect(lean.isString(extracted));
    }
}

// ============================================================================
// PHASE 5: Thunks, Tasks & References Tests
// ============================================================================

// Thunk Tests

test "thunk: pure thunk creation and access" {
    const value = lean.boxUsize(42);
    const thunk = lean.lean_thunk_pure(value) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(thunk);
    
    // Verify it's a thunk
    try testing.expect(lean.isThunk(thunk));
    try testing.expect(!lean.isTask(thunk));
    try testing.expect(!lean.isClosure(thunk));
    
    // Get value (borrowed)
    const retrieved = lean.thunkGet(thunk);
    try testing.expect(lean.isScalar(retrieved));
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(retrieved));
}

test "thunk: get_own transfers ownership" {
    const value = lean.boxUsize(100);
    const thunk = lean.lean_thunk_pure(value) orelse return error.AllocationFailed;
    
    // Get with ownership (increments ref on value)
    const owned = lean.lean_thunk_get_own(thunk);
    defer lean.lean_dec_ref(owned);
    
    // Original thunk still valid
    try testing.expect(lean.isThunk(thunk));
    
    // Can still access value through thunk
    const borrowed = lean.thunkGet(thunk);
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(borrowed));
    
    // Clean up thunk
    lean.lean_dec_ref(thunk);
}

test "thunk: multiple accesses return same value" {
    const value = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const thunk = lean.lean_thunk_pure(value) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(thunk);
    
    // Multiple gets should return same cached value
    const v1 = lean.thunkGet(thunk);
    const v2 = lean.thunkGet(thunk);
    const v3 = lean.thunkGet(thunk);
    
    try testing.expect(v1 == v2);
    try testing.expect(v2 == v3);
}

// Task Tests

test "task: type checking" {
    // We can't easily test task execution without the full Lean IO system,
    // but we can test type checking on mock task objects.
    // Tasks are created via lean_task_spawn_core which requires full runtime init,
    // so we'll just verify the API functions exist and have correct signatures.
    
    // Just verify functions are accessible (compilation test)
    _ = lean.lean_task_spawn_core;
    _ = lean.lean_task_get;
    _ = lean.lean_task_get_own;
    _ = lean.lean_task_map_core;
    _ = lean.lean_task_bind_core;
    _ = lean.taskSpawn;
    _ = lean.taskMap;
    _ = lean.taskBind;
}

// Reference Tests

test "ref: basic get and set" {
    // Create a ref object manually (refs are normally created by ST runtime)
    const ref = lean.lean_alloc_object(@sizeOf(lean.RefObject)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ref);
    
    // Initialize header
    const header: *lean.ObjectHeader = @ptrCast(@alignCast(ref));
    header.m_tag = lean.Tag.ref;
    header.m_other = 0;
    
    // Set initial value
    const initial = lean.boxUsize(10);
    lean.refSet(ref, initial);
    
    // Get value
    const retrieved = lean.refGet(ref);
    try testing.expect(lean.isScalar(retrieved));
    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(retrieved));
}

test "ref: set updates value" {
    const ref = lean.lean_alloc_object(@sizeOf(lean.RefObject)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ref);
    
    const header: *lean.ObjectHeader = @ptrCast(@alignCast(ref));
    header.m_tag = lean.Tag.ref;
    header.m_other = 0;
    
    // Set initial value
    lean.refSet(ref, lean.boxUsize(100));
    
    // Verify initial
    const v1 = lean.refGet(ref);
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(v1));
    
    // Update value
    lean.refSet(ref, lean.boxUsize(200));
    
    // Verify updated
    const v2 = lean.refGet(ref);
    try testing.expectEqual(@as(usize, 200), lean.unboxUsize(v2));
    
    // Update again
    lean.refSet(ref, lean.boxUsize(300));
    const v3 = lean.refGet(ref);
    try testing.expectEqual(@as(usize, 300), lean.unboxUsize(v3));
}

test "ref: set decrements old value refcount" {
    const ref = lean.lean_alloc_object(@sizeOf(lean.RefObject)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ref);
    
    const header: *lean.ObjectHeader = @ptrCast(@alignCast(ref));
    header.m_tag = lean.Tag.ref;
    header.m_other = 0;
    
    // Create an object to track
    const obj1 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    lean.lean_inc_ref(obj1); // Keep alive for test
    
    // Set as ref value
    lean.refSet(ref, obj1);
    try testing.expectEqual(@as(i32, 2), lean.objectRc(obj1));
    
    // Create another object
    const obj2 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    lean.lean_inc_ref(obj2); // Keep alive
    
    // Replace ref value (should dec_ref obj1)
    lean.refSet(ref, obj2);
    
    // obj1 should have rc=1, obj2 should have rc=2
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj1));
    try testing.expectEqual(@as(i32, 2), lean.objectRc(obj2));
    
    // Clean up
    lean.lean_dec_ref(obj1);
    lean.lean_dec_ref(obj2);
}

test "ref: object storage and retrieval" {
    const ref = lean.lean_alloc_object(@sizeOf(lean.RefObject)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ref);
    
    const header: *lean.ObjectHeader = @ptrCast(@alignCast(ref));
    header.m_tag = lean.Tag.ref;
    header.m_other = 0;
    
    // Store a complex constructor
    const ctor = lean.allocCtor(5, 2, 8) orelse return error.AllocationFailed;
    lean.ctorSetUint64(ctor, 0, 12345);
    
    lean.refSet(ref, ctor);
    
    // Retrieve and verify
    const retrieved = lean.refGet(ref);
    try testing.expect(!lean.isScalar(retrieved));
    try testing.expectEqual(@as(u8, 5), lean.objectTag(retrieved));
    try testing.expectEqual(@as(u64, 12345), lean.ctorGetUint64(retrieved, 0));
}

test "ref: null value handling" {
    const ref = lean.lean_alloc_object(@sizeOf(lean.RefObject)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ref);
    
    const header: *lean.ObjectHeader = @ptrCast(@alignCast(ref));
    header.m_tag = lean.Tag.ref;
    header.m_other = 0;
    
    // Set null value
    lean.refSet(ref, null);
    
    // Get should return null
    const retrieved = lean.refGet(ref);
    try testing.expect(retrieved == null);
    
    // Can set non-null after null
    lean.refSet(ref, lean.boxUsize(42));
    const v = lean.refGet(ref);
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(v));
}
