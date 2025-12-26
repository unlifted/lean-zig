# Comprehensive Unit Testing Plan for lean-zig FFI Interface

## Executive Summary

This document outlines a comprehensive testing strategy for the lean-zig FFI interface. Current test coverage is ~25 tests covering basic functionality. This plan expands coverage to **100+ tests** across all API categories with focus on:

- **Memory safety** (reference counting, no leaks, no double-frees)
- **Type correctness** (boxing/unboxing, type checks, field access)
- **Edge cases** (boundaries, empty inputs, maximum values)
- **Property-based patterns** (round-trip invariants, algebraic laws)
- **Performance validation** (hot-path functions meet performance targets)

---

## Current Test Coverage Analysis

### ✅ Already Tested (25 tests)

| Category | Tests | Coverage |
|----------|-------|----------|
| Tagged pointers | 3 | Good - encoding, zero value, format |
| Boxing/Unboxing | 3 | Good - basic round-trips, large values |
| Constructors | 5 | Good - allocation, fields, tags, initialization |
| Reference counting | 2 | Basic - inc/dec balance, initial count |
| Arrays | 4 | Good - allocation, get/set, tags, initialization |
| Strings | 5 | Good - creation, access, length, empty |
| IO Results | 3 | Good - ok/error creation, inspection |

### ❌ Missing Coverage

| Category | Functions | Priority | Risk |
|----------|-----------|----------|------|
| Type inspection | 13 functions | **HIGH** | Core safety |
| Scalar field accessors | 14 functions | **HIGH** | Data corruption |
| String operations | 5+ functions | MEDIUM | UTF-8 handling |
| Array operations | 8 functions | MEDIUM | Bounds/capacity |
| Closures | 7 functions | MEDIUM | Functional correctness |
| Thunks/Tasks | 8 functions | LOW | Async behavior |
| References | 2 functions | LOW | ST monad |
| Scalar arrays | 5 functions | LOW | Specialized types |
| Multi-threading | MT objects | **HIGH** | Race conditions |

---

## Test Plan by Category

### 1. Type Inspection Functions (HIGH PRIORITY)

**13 functions to test:**

```zig
// Boolean predicates
isScalar, isCtor, isString, isArray, isSarray, isClosure
isThunk, isTask, isRef, isExternal, isMpz

// Sharing/exclusivity
isExclusive, isShared

// Meta
objTag, ptrTag
```

**Test plan (26 tests):**

```zig
// Positive tests - verify correct type detection
test "isScalar detects tagged pointers" {
    const scalar = lean.boxUsize(42);
    try testing.expect(lean.isScalar(scalar));
    try testing.expect(!lean.isCtor(scalar));  // scalar ctors are different
}

test "isCtor detects constructor objects" {
    const ctor = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    try testing.expect(lean.isCtor(ctor));
    try testing.expect(!lean.isScalar(ctor));
}

test "isString detects string objects" {
    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    try testing.expect(lean.isString(str));
    try testing.expectEqual(lean.Tag.string, lean.objectTag(str));
}

test "isArray detects array objects" {
    const arr = lean.allocArray(5) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    try testing.expect(lean.isArray(arr));
    try testing.expectEqual(lean.Tag.array, lean.objectTag(arr));
}

// Negative tests - verify false positives don't occur
test "type checks are mutually exclusive" {
    const types = [_]struct { obj: lean.obj_arg, name: []const u8 }{
        .{ .obj = lean.boxUsize(1), .name = "scalar" },
        .{ .obj = lean.allocCtor(0, 0, 0), .name = "ctor" },
        .{ .obj = lean.allocArray(1), .name = "array" },
        .{ .obj = lean.lean_mk_string("x"), .name = "string" },
    };
    
    // Each type should only pass its own check
    for (types, 0..) |t1, i| {
        defer if (i > 0) lean.lean_dec_ref(t1.obj);
        for (types, 0..) |t2, j| {
            if (i == j) continue;
            // Verify t1 is not detected as t2's type
            // ... detailed checks ...
        }
    }
}

// Exclusivity tests
test "isExclusive true when rc == 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);
    try testing.expect(lean.isExclusive(obj));
    try testing.expect(!lean.isShared(obj));
}

test "isShared true when rc > 1" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj);
    
    lean.lean_inc_ref(obj);
    defer lean.lean_dec_ref(obj);
    
    try testing.expect(lean.isShared(obj));
    try testing.expect(!lean.isExclusive(obj));
}

// Edge cases
test "ptrTag distinguishes heap from scalar" {
    const scalar = lean.boxUsize(42);
    try testing.expectEqual(@as(usize, 1), lean.ptrTag(scalar));
    
    const heap = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(heap);
    try testing.expectEqual(@as(usize, 0), lean.ptrTag(heap));
}

test "objTag returns correct tag for all types" {
    // Test all Tag constants
    const tests = [_]struct { obj: lean.obj_arg, tag: u8 }{
        .{ .obj = lean.allocCtor(0, 0, 0), .tag = 0 },
        .{ .obj = lean.allocCtor(243, 0, 0), .tag = 243 },
        .{ .obj = lean.allocArray(1), .tag = lean.Tag.array },
        .{ .obj = lean.lean_mk_string("x"), .tag = lean.Tag.string },
    };
    
    for (tests) |t| {
        defer lean.lean_dec_ref(t.obj);
        try testing.expectEqual(t.tag, lean.objectTag(t.obj));
    }
}
```

**Additional tests needed:**
- Tag boundary tests (0, 243, 244+)
- Null pointer handling (if applicable)
- Multi-threaded object detection (negative rc)

---

### 2. Constructor Scalar Field Access (HIGH PRIORITY)

**14 functions to test (7 getters + 7 setters):**

```zig
// Getters
ctorGetUint8, ctorGetUint16, ctorGetUint32, ctorGetUint64
ctorGetUsize, ctorGetFloat, ctorGetFloat32

// Setters
ctorSetUint8, ctorSetUint16, ctorSetUint32, ctorSetUint64
ctorSetUsize, ctorSetFloat, ctorSetFloat32

// Utilities
ctorScalarCptr, ctorSetTag, ctorRelease, ctorNumObjs
```

**Test plan (42+ tests):**

```zig
// Round-trip tests for each type
test "ctor uint8 round-trip" {
    const ctor = lean.allocCtor(0, 0, 1) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]u8{ 0, 1, 127, 255 };
    for (values) |val| {
        lean.ctorSetUint8(ctor, 0, val);
        const retrieved = lean.ctorGetUint8(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor uint16 round-trip" {
    const ctor = lean.allocCtor(0, 0, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]u16{ 0, 1, 256, 32767, 65535 };
    for (values) |val| {
        lean.ctorSetUint16(ctor, 0, val);
        const retrieved = lean.ctorGetUint16(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor uint32 round-trip" {
    const ctor = lean.allocCtor(0, 0, 4) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]u32{ 0, 1, 65536, 2147483647, 4294967295 };
    for (values) |val| {
        lean.ctorSetUint32(ctor, 0, val);
        const retrieved = lean.ctorGetUint32(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor uint64 round-trip" {
    const ctor = lean.allocCtor(0, 0, 8) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]u64{
        0, 1, 4294967296,
        9223372036854775807,  // Max i64
        18446744073709551615, // Max u64
    };
    for (values) |val| {
        lean.ctorSetUint64(ctor, 0, val);
        const retrieved = lean.ctorGetUint64(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor usize round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(usize)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]usize{ 0, 1, 4294967296, @as(usize, 1) << 62 };
    for (values) |val| {
        lean.ctorSetUsize(ctor, 0, val);
        const retrieved = lean.ctorGetUsize(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

test "ctor float round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(f64)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]f64{
        0.0, -0.0, 1.0, -1.0, 3.14159, -3.14159,
        @as(f64, std.math.inf(f64)),
        @as(f64, -std.math.inf(f64)),
    };
    for (values) |val| {
        lean.ctorSetFloat(ctor, 0, val);
        const retrieved = lean.ctorGetFloat(ctor, 0);
        if (std.math.isNan(val)) {
            try testing.expect(std.math.isNan(retrieved));
        } else {
            try testing.expectEqual(val, retrieved);
        }
    }
}

test "ctor float32 round-trip" {
    const ctor = lean.allocCtor(0, 0, @sizeOf(f32)) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    const values = [_]f32{ 0.0, 1.0, -1.0, 3.14, @as(f32, std.math.inf(f32)) };
    for (values) |val| {
        lean.ctorSetFloat32(ctor, 0, val);
        const retrieved = lean.ctorGetFloat32(ctor, 0);
        try testing.expectEqual(val, retrieved);
    }
}

// Multiple field tests
test "ctor with multiple scalar fields" {
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

// Alignment tests
test "ctor scalar fields maintain alignment" {
    // Test that misaligned offsets still work (or document requirements)
    const ctor = lean.allocCtor(0, 0, 16) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    // Write u64 at offset 0 (aligned)
    lean.ctorSetUint64(ctor, 0, 0xDEADBEEF);
    // Write u64 at offset 8 (aligned)
    lean.ctorSetUint64(ctor, 8, 0xCAFEBABE);
    
    try testing.expectEqual(@as(u64, 0xDEADBEEF), lean.ctorGetUint64(ctor, 0));
    try testing.expectEqual(@as(u64, 0xCAFEBABE), lean.ctorGetUint64(ctor, 8));
}

// ctorNumObjs test
test "ctorNumObjs returns correct count" {
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

// ctorSetTag test
test "ctorSetTag changes constructor variant" {
    const ctor = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(ctor);
    
    try testing.expectEqual(@as(u8, 0), lean.objectTag(ctor));
    
    lean.ctorSetTag(ctor, 5);
    try testing.expectEqual(@as(u8, 5), lean.objectTag(ctor));
}

// ctorScalarCptr test
test "ctorScalarCptr points to correct region" {
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

// ctorRelease test
test "ctorRelease decrements field references" {
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
```

**Additional tests needed:**
- Mixed object + scalar field constructors
- Scalar field overwrite behavior
- Edge case: scalar_size = 0

---

### 3. String Operations (MEDIUM PRIORITY)

**Additional functions (beyond basic tests):**

```zig
stringCapacity, stringGetByteFast
stringEq, stringNe, stringLt
// (Note: More string functions may exist in lean_raw)
```

**Test plan (20+ tests):**

```zig
test "stringCapacity >= stringSize" {
    const str = lean.lean_mk_string("Hello");
    defer lean.lean_dec_ref(str);
    
    const size = lean.stringSize(str);
    const capacity = lean.stringCapacity(str);
    try testing.expect(capacity >= size);
}

test "stringGetByteFast accesses individual bytes" {
    const str = lean.lean_mk_string("ABC");
    defer lean.lean_dec_ref(str);
    
    try testing.expectEqual(@as(u8, 'A'), lean.stringGetByteFast(str, 0));
    try testing.expectEqual(@as(u8, 'B'), lean.stringGetByteFast(str, 1));
    try testing.expectEqual(@as(u8, 'C'), lean.stringGetByteFast(str, 2));
    try testing.expectEqual(@as(u8, 0), lean.stringGetByteFast(str, 3)); // null
}

test "stringEq compares equal strings" {
    const str1 = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str1);
    const str2 = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str2);
    
    try testing.expect(lean.stringEq(str1, str2));
    try testing.expect(!lean.stringNe(str1, str2));
}

test "stringEq rejects different strings" {
    const str1 = lean.lean_mk_string("foo");
    defer lean.lean_dec_ref(str1);
    const str2 = lean.lean_mk_string("bar");
    defer lean.lean_dec_ref(str2);
    
    try testing.expect(!lean.stringEq(str1, str2));
    try testing.expect(lean.stringNe(str1, str2));
}

test "stringLt lexicographic ordering" {
    const tests = [_]struct { a: [:0]const u8, b: [:0]const u8, expect_lt: bool }{
        .{ .a = "a", .b = "b", .expect_lt = true },
        .{ .a = "abc", .b = "abd", .expect_lt = true },
        .{ .a = "abc", .b = "abc", .expect_lt = false },
        .{ .a = "abd", .b = "abc", .expect_lt = false },
        .{ .a = "", .b = "a", .expect_lt = true },
    };
    
    for (tests) |t| {
        const str1 = lean.lean_mk_string(t.a.ptr);
        defer lean.lean_dec_ref(str1);
        const str2 = lean.lean_mk_string(t.b.ptr);
        defer lean.lean_dec_ref(str2);
        
        try testing.expectEqual(t.expect_lt, lean.stringLt(str1, str2));
    }
}

test "string with UTF-8 multi-byte characters" {
    const utf8_str = "Hello 世界 🌍";
    const str = lean.lean_mk_string(utf8_str);
    defer lean.lean_dec_ref(str);
    
    // Byte count includes all UTF-8 bytes + null
    const byte_size = lean.stringSize(str);
    try testing.expect(byte_size > 12); // More than ASCII length
    
    // Code point count
    const cp_len = lean.stringLen(str);
    try testing.expectEqual(@as(usize, 11), cp_len); // "Hello " + 2 CJK + 1 emoji
}

test "string empty vs single space" {
    const empty = lean.lean_mk_string("");
    defer lean.lean_dec_ref(empty);
    const space = lean.lean_mk_string(" ");
    defer lean.lean_dec_ref(space);
    
    try testing.expect(!lean.stringEq(empty, space));
    try testing.expectEqual(@as(usize, 1), lean.stringSize(empty));
    try testing.expectEqual(@as(usize, 2), lean.stringSize(space));
}
```

---

### 4. Array Operations (MEDIUM PRIORITY)

**Additional functions:**

```zig
arrayUget, arrayUset  // Unchecked (fast)
arraySwap, arraySetSize
arrayCapacity
arrayGetBorrowed (alias)
```

**Test plan (25+ tests):**

```zig
test "arrayUget unchecked access" {
    const arr = lean.mkArrayWithSize(3, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    lean.arraySet(arr, 0, lean.boxUsize(100));
    lean.arraySet(arr, 1, lean.boxUsize(200));
    lean.arraySet(arr, 2, lean.boxUsize(300));
    
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(lean.arrayUget(arr, 0)));
    try testing.expectEqual(@as(usize, 200), lean.unboxUsize(lean.arrayUget(arr, 1)));
    try testing.expectEqual(@as(usize, 300), lean.unboxUsize(lean.arrayUget(arr, 2)));
}

test "arrayUset unchecked write" {
    const arr = lean.mkArrayWithSize(2, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    lean.arrayUset(arr, 0, lean.boxUsize(42));
    lean.arrayUset(arr, 1, lean.boxUsize(99));
    
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(lean.arrayGet(arr, 0)));
    try testing.expectEqual(@as(usize, 99), lean.unboxUsize(lean.arrayGet(arr, 1)));
}

test "arraySwap exchanges elements" {
    const arr = lean.mkArrayWithSize(3, 3) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    lean.arraySet(arr, 0, lean.boxUsize(1));
    lean.arraySet(arr, 1, lean.boxUsize(2));
    lean.arraySet(arr, 2, lean.boxUsize(3));
    
    lean.arraySwap(arr, 0, 2);
    
    try testing.expectEqual(@as(usize, 3), lean.unboxUsize(lean.arrayGet(arr, 0)));
    try testing.expectEqual(@as(usize, 2), lean.unboxUsize(lean.arrayGet(arr, 1)));
    try testing.expectEqual(@as(usize, 1), lean.unboxUsize(lean.arrayGet(arr, 2)));
}

test "arraySwap is idempotent" {
    const arr = lean.mkArrayWithSize(2, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    lean.arraySet(arr, 0, lean.boxUsize(10));
    lean.arraySet(arr, 1, lean.boxUsize(20));
    
    lean.arraySwap(arr, 0, 1);
    lean.arraySwap(arr, 0, 1);
    
    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(lean.arrayGet(arr, 0)));
    try testing.expectEqual(@as(usize, 20), lean.unboxUsize(lean.arrayGet(arr, 1)));
}

test "arraySetSize modifies size field" {
    const arr = lean.allocArray(10) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    try testing.expectEqual(@as(usize, 0), lean.arraySize(arr));
    
    lean.arraySetSize(arr, 5);
    try testing.expectEqual(@as(usize, 5), lean.arraySize(arr));
}

test "arrayCapacity returns max elements" {
    const capacity: usize = 100;
    const arr = lean.allocArray(capacity) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    try testing.expectEqual(capacity, lean.arrayCapacity(arr));
}

test "array with heap objects maintains refcounts" {
    const arr = lean.mkArrayWithSize(2, 2) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    const obj1 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    const obj2 = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj1));
    try testing.expectEqual(@as(i32, 1), lean.objectRc(obj2));
    
    lean.arraySet(arr, 0, obj1);
    lean.arraySet(arr, 1, obj2);
    
    // Objects are now owned by array, refcount still 1
    // (arraySet doesn't inc_ref, it transfers ownership)
}

test "array empty capacity edge case" {
    const arr = lean.allocArray(0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    try testing.expectEqual(@as(usize, 0), lean.arraySize(arr));
    try testing.expectEqual(@as(usize, 0), lean.arrayCapacity(arr));
}
```

---

### 5. Boxing/Unboxing Additional Types (MEDIUM PRIORITY)

**Functions:**

```zig
boxUint32, unboxUint32
boxUint64, unboxUint64
boxFloat, unboxFloat
boxFloat32, unboxFloat32
```

**Test plan (20+ tests):**

```zig
test "box and unbox uint32" {
    const values = [_]u32{ 0, 1, 42, 65535, 4294967295 };
    for (values) |val| {
        const boxed = lean.boxUint32(val);
        const unboxed = lean.unboxUint32(boxed);
        try testing.expectEqual(val, unboxed);
    }
}

test "box and unbox uint64" {
    const values = [_]u64{
        0, 1, 4294967296,
        @as(u64, 1) << 62,
        (@as(u64, 1) << 63) - 1, // Max tagged value
    };
    for (values) |val| {
        const boxed = lean.boxUint64(val);
        const unboxed = lean.unboxUint64(boxed);
        try testing.expectEqual(val, unboxed);
    }
}

test "box and unbox float64" {
    const values = [_]f64{
        0.0, -0.0, 1.0, -1.0, 3.14159265358979,
        1.7976931348623157e+308, // Max f64
        2.2250738585072014e-308, // Min positive f64
    };
    for (values) |val| {
        const boxed = lean.boxFloat(val);
        defer lean.lean_dec_ref(boxed); // Floats allocate
        const unboxed = lean.unboxFloat(boxed);
        try testing.expectEqual(val, unboxed);
    }
}

test "box and unbox float32" {
    const values = [_]f32{ 0.0, 1.0, -1.0, 3.14, -3.14 };
    for (values) |val| {
        const boxed = lean.boxFloat32(val);
        defer lean.lean_dec_ref(boxed);
        const unboxed = lean.unboxFloat32(boxed);
        try testing.expectEqual(val, unboxed);
    }
}

test "float special values" {
    const inf = std.math.inf(f64);
    const ninf = -std.math.inf(f64);
    const nan = std.math.nan(f64);
    
    const boxed_inf = lean.boxFloat(inf);
    defer lean.lean_dec_ref(boxed_inf);
    try testing.expect(std.math.isInf(lean.unboxFloat(boxed_inf)));
    
    const boxed_ninf = lean.boxFloat(ninf);
    defer lean.lean_dec_ref(boxed_ninf);
    try testing.expect(std.math.isNegativeInf(lean.unboxFloat(boxed_ninf)));
    
    const boxed_nan = lean.boxFloat(nan);
    defer lean.lean_dec_ref(boxed_nan);
    try testing.expect(std.math.isNan(lean.unboxFloat(boxed_nan)));
}

test "uint64 overflow panics" {
    // Values >= 2^63 should panic
    const too_large: u64 = @as(u64, 1) << 63;
    _ = lean.boxUint64(too_large); // Should panic
}

test "float boxing allocates on heap" {
    const boxed = lean.boxFloat(3.14);
    defer lean.lean_dec_ref(boxed);
    
    // Verify it's not a scalar (heap allocated)
    try testing.expect(!lean.isScalar(boxed));
    try testing.expect(lean.isCtor(boxed));
}
```

---

### 6. Closure Operations (MEDIUM PRIORITY)

**Functions:**

```zig
lean_alloc_closure
closureArity, closureNumFixed, closureFun
closureGet, closureSet, closureArgCptr
```

**Test plan (15+ tests):**

```zig
fn example_fn_2(a: lean.obj_arg, b: lean.obj_arg) callconv(.C) lean.obj_res {
    _ = a; _ = b;
    return lean.boxUsize(42);
}

test "allocate closure with no fixed args" {
    const closure = lean.lean_alloc_closure(@ptrCast(&example_fn_2), 2, 0);
    defer lean.lean_dec_ref(closure);
    
    try testing.expectEqual(@as(u16, 2), lean.closureArity(closure));
    try testing.expectEqual(@as(u16, 0), lean.closureNumFixed(closure));
}

test "allocate closure with fixed args" {
    const closure = lean.lean_alloc_closure(@ptrCast(&example_fn_2), 2, 1);
    defer lean.lean_dec_ref(closure);
    
    const arg = lean.boxUsize(100);
    lean.closureSet(closure, 0, arg);
    
    try testing.expectEqual(@as(u16, 2), lean.closureArity(closure));
    try testing.expectEqual(@as(u16, 1), lean.closureNumFixed(closure));
    
    const retrieved = lean.closureGet(closure, 0);
    try testing.expectEqual(@as(usize, 100), lean.unboxUsize(retrieved));
}

test "closure has correct tag" {
    const closure = lean.lean_alloc_closure(@ptrCast(&example_fn_2), 2, 0);
    defer lean.lean_dec_ref(closure);
    
    try testing.expectEqual(lean.Tag.closure, lean.objectTag(closure));
}

test "closureFun returns function pointer" {
    const closure = lean.lean_alloc_closure(@ptrCast(&example_fn_2), 2, 0);
    defer lean.lean_dec_ref(closure);
    
    const fun_ptr = lean.closureFun(closure);
    try testing.expect(fun_ptr != null);
}

test "closureArgCptr accesses fixed args" {
    const closure = lean.lean_alloc_closure(@ptrCast(&example_fn_2), 3, 2);
    defer lean.lean_dec_ref(closure);
    
    lean.closureSet(closure, 0, lean.boxUsize(10));
    lean.closureSet(closure, 1, lean.boxUsize(20));
    
    const args = lean.closureArgCptr(closure);
    try testing.expectEqual(@as(usize, 10), lean.unboxUsize(args[0]));
    try testing.expectEqual(@as(usize, 20), lean.unboxUsize(args[1]));
}
```

---

### 7. Thunks and Tasks (LOW PRIORITY)

**Functions:**

```zig
lean_thunk_pure, lean_thunk_get_own, thunkGet
lean_task_spawn_core, lean_task_get_own, lean_task_map_core, lean_task_bind_core
taskSpawn, taskMap, taskBind
```

**Test plan (10+ tests):**

```zig
test "thunk pure creates evaluated thunk" {
    const value = lean.boxUsize(42);
    const thunk = lean.lean_thunk_pure(value);
    defer lean.lean_dec_ref(thunk);
    
    const result = lean.thunkGet(thunk);
    try testing.expectEqual(@as(usize, 42), lean.unboxUsize(result));
}

test "thunk has correct tag" {
    const thunk = lean.lean_thunk_pure(lean.boxUsize(1));
    defer lean.lean_dec_ref(thunk);
    
    try testing.expectEqual(lean.Tag.thunk, lean.objectTag(thunk));
}

// Task tests would require async execution environment
test "task spawn creates task object" {
    // Simplified test - full test requires Lean runtime context
    // const task = lean.taskSpawn(computation);
    // try testing.expectEqual(lean.Tag.task, lean.objectTag(task));
}
```

---

### 8. References (LOW PRIORITY)

**Functions:**

```zig
refGet, refSet
```

**Test plan (5+ tests):**

```zig
test "ref get and set" {
    // Requires creating a reference object via Lean runtime
    // These are ST monad primitives, need proper context
}
```

---

### 9. Scalar Arrays (LOW PRIORITY)

**Functions:**

```zig
sarraySize, sarrayCapacity, sarrayElemSize
sarrayCptr, sarraySetSize
```

**Test plan (10+ tests):**

```zig
test "sarray size and capacity" {
    // const byte_array = lean.allocByteArray(100);
    // try testing.expectEqual(@as(usize, 1), lean.sarrayElemSize(byte_array));
}
```

---

### 10. Reference Counting Deep Tests (HIGH PRIORITY)

**Additional scenarios:**

```zig
test "circular references with manual cleanup" {
    // Create two objects that reference each other
    const obj1 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    const obj2 = lean.allocCtor(0, 1, 0) orelse return error.AllocationFailed;
    
    lean.ctorSet(obj1, 0, obj2);
    lean.lean_inc_ref(obj2);
    lean.ctorSet(obj2, 0, obj1);
    lean.lean_inc_ref(obj1);
    
    // Break cycle
    lean.lean_dec_ref(obj1);
    lean.lean_dec_ref(obj2);
}

test "refcount overflow protection" {
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
}

test "multi-threaded object detection" {
    // MT objects have negative refcount
    // Would need to create MT object via Lean runtime
}
```

---

## Performance Tests

**Hot-path functions must meet performance targets:**

```zig
test "benchmark boxing performance" {
    var timer = try std.time.Timer.start();
    
    const iterations = 10_000_000;
    var i: usize = 0;
    var sum: usize = 0;
    while (i < iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        sum +%= lean.unboxUsize(boxed);
    }
    
    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;
    
    std.debug.print("\nBoxing: {d}ns per round-trip\n", .{ns_per_op});
    try testing.expect(ns_per_op < 5); // Should be 1-2ns
    try testing.expect(sum > 0); // Prevent optimization
}

test "benchmark array access performance" {
    const arr = lean.mkArrayWithSize(1000, 1000) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    var timer = try std.time.Timer.start();
    
    const iterations = 1_000_000;
    var i: usize = 0;
    var sum: usize = 0;
    while (i < iterations) : (i += 1) {
        const elem = lean.arrayUget(arr, i % 1000);
        sum +%= lean.unboxUsize(elem);
    }
    
    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;
    
    std.debug.print("\nArray access: {d}ns per operation\n", .{ns_per_op});
    try testing.expect(ns_per_op < 5); // Should be 2-3ns
    try testing.expect(sum >= 0);
}

test "benchmark refcount operations" {
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
    
    std.debug.print("\nRefcount: {d}ns per operation\n", .{ns_per_op});
    try testing.expect(ns_per_op < 2); // Should be 0.5ns
}
```

---

## Property-Based Testing Patterns

**While Zig lacks mature PBT frameworks, implement randomized tests:**

```zig
test "boxing round-trip for many random values" {
    var prng = std.rand.DefaultPrng.init(12345);
    const rng = prng.random();
    
    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        const val = rng.int(usize) & ((@as(usize, 1) << 62) - 1);
        const boxed = lean.boxUsize(val);
        const unboxed = lean.unboxUsize(boxed);
        try testing.expectEqual(val, unboxed);
    }
}

test "array operations maintain size invariant" {
    var prng = std.rand.DefaultPrng.init(54321);
    const rng = prng.random();
    
    const capacity: usize = 100;
    const arr = lean.allocArray(capacity) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(arr);
    
    var current_size: usize = 0;
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const new_size = rng.intRangeAtMost(usize, 0, capacity);
        lean.arraySetSize(arr, new_size);
        current_size = new_size;
        
        try testing.expectEqual(current_size, lean.arraySize(arr));
    }
}

test "constructor field set/get property" {
    var prng = std.rand.DefaultPrng.init(99999);
    const rng = prng.random();
    
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const num_fields = rng.intRangeAtMost(u8, 1, 10);
        const ctor = lean.allocCtor(0, num_fields, 0) orelse return error.AllocationFailed;
        defer lean.lean_dec_ref(ctor);
        
        var field: usize = 0;
        while (field < num_fields) : (field += 1) {
            const val = rng.int(usize) & ((@as(usize, 1) << 62) - 1);
            lean.ctorSet(ctor, field, lean.boxUsize(val));
            const retrieved = lean.ctorGet(ctor, field);
            try testing.expectEqual(val, lean.unboxUsize(retrieved));
        }
    }
}
```

---

## Test Organization

### File Structure

```
Zig/
  lean_test.zig          # Main test suite (current)
  tests/
    boxing_test.zig      # Boxing/unboxing all types
    ctor_test.zig        # Constructor operations
    array_test.zig       # Array operations
    string_test.zig      # String operations
    refcount_test.zig    # Reference counting
    closure_test.zig     # Closures
    task_test.zig        # Tasks/thunks
    property_test.zig    # Property-based patterns
    perf_test.zig        # Performance benchmarks
```

### Test Naming Convention

```zig
test "category: specific behavior [edge case]" { ... }

// Examples:
test "boxing: uint64 round-trip [max value]" { ... }
test "ctor: scalar fields [multiple types]" { ... }
test "array: swap [idempotent]" { ... }
test "refcount: exclusive detection [rc == 1]" { ... }
```

---

## Test Coverage Goals

| Category | Current | Target | Priority |
|----------|---------|--------|----------|
| Type inspection | 0% | 100% | **HIGH** |
| Scalar accessors | 0% | 100% | **HIGH** |
| Reference counting | 20% | 100% | **HIGH** |
| Boxing/unboxing | 60% | 100% | MEDIUM |
| Constructors | 70% | 100% | MEDIUM |
| Arrays | 50% | 100% | MEDIUM |
| Strings | 60% | 100% | MEDIUM |
| Closures | 0% | 80% | MEDIUM |
| IO Results | 80% | 100% | LOW |
| Thunks/Tasks | 0% | 50% | LOW |
| References | 0% | 50% | LOW |
| Scalar arrays | 0% | 50% | LOW |
| Performance | 0% | 100% | **HIGH** |

**Total test count goal: 150-200 tests** (currently ~25)

---

## Implementation Strategy

### Phase 1: Critical Safety (Week 1)
- [ ] All type inspection tests
- [ ] All scalar accessor tests
- [ ] Deep reference counting tests
- [ ] Performance baselines

### Phase 2: Core API (Week 2)
- [ ] Complete boxing/unboxing
- [ ] Complete array operations
- [ ] Complete string operations
- [ ] Constructor edge cases

### Phase 3: Advanced Features (Week 3)
- [ ] Closure operations
- [ ] Property-based patterns
- [ ] Multi-threading scenarios
- [ ] Performance benchmarks

### Phase 4: Specialized (Week 4)
- [ ] Thunks and tasks
- [ ] References
- [ ] Scalar arrays
- [ ] Integration tests

---

## CI Integration

**Add to GitHub Actions workflow:**

```yaml
- name: Run Zig tests
  run: zig build test
  
- name: Run performance benchmarks
  run: zig build bench
  
- name: Check test coverage
  run: zig build test-coverage
```

---

## Success Metrics

1. **Coverage**: ≥ 90% of public API has tests
2. **Reliability**: 0 memory leaks in test suite
3. **Performance**: All hot-path functions meet ns targets
4. **Documentation**: Every test documents the invariant it checks
5. **Maintainability**: Tests are easy to understand and extend

---

## Conclusion

This comprehensive testing plan transforms lean-zig from a basic prototype into a production-ready library with:

- **150-200 tests** covering all API surface area
- **Property-based patterns** catching edge cases
- **Performance benchmarks** ensuring hot-path optimization
- **Safety guarantees** through exhaustive reference counting tests
- **Documentation** of expected behavior through tests

The phased approach allows incremental progress while prioritizing critical safety and performance concerns.
