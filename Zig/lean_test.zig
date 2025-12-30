const std = @import("std");

// Test suite driver for modularized lean-zig tests
// This file imports all test category modules to enable running with `zig build test`

// Import all test category modules
// Zig will automatically discover and run all tests from these modules

test {
    @import("std").testing.refAllDecls(@This());
}

// Test Categories
test "Boxing & Unboxing" {
    _ = @import("tests/boxing_test.zig");
}

test "Constructors" {
    _ = @import("tests/constructor_test.zig");
}

test "Reference Counting" {
    _ = @import("tests/refcount_test.zig");
}

test "Arrays" {
    _ = @import("tests/array_test.zig");
}

test "Strings" {
    _ = @import("tests/string_test.zig");
}

test "Scalar Arrays" {
    _ = @import("tests/scalar_array_test.zig");
}

test "Type Inspection" {
    _ = @import("tests/type_test.zig");
}

test "Closures" {
    _ = @import("tests/closure_test.zig");
}

test "Performance Benchmarks" {
    _ = @import("tests/performance_test.zig");
}

test "Advanced Features" {
    _ = @import("tests/advanced_test.zig");
}

test "External Objects" {
    _ = @import("tests/external_test.zig");
}
