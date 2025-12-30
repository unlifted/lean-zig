//! External objects tests
//!
//! External objects require full Lean runtime initialization for class registration
//! via lean_register_external_class. Manual allocation without proper registration
//! causes segfaults during cleanup when the runtime tries to call finalizers.
//!
//! These tests verify the API structure only (similar to task tests).

const std = @import("std");
const testing = std.testing;
const lean = @import("../lean.zig");

// ============================================================================
// External Objects Tests
// ============================================================================

test "external: API existence and signatures" {
    // Verify all external object API functions are accessible and have correct signatures
    
    // Core registration and allocation functions
    _ = lean.lean_register_external_class;
    _ = lean.registerExternalClass;
    _ = lean.allocExternal;
    
    // Data access functions
    _ = lean.getExternalData;
    _ = lean.getExternalClass;
    _ = lean.setExternalData;
    
    // Type checking
    _ = lean.isExternal;
    
    // Type definitions
    _ = lean.ExternalClass;
    _ = lean.ExternalObject;
}

test "external: type checking with non-external object" {
    // Create a non-external object to verify isExternal returns false
    const str = lean.lean_mk_string("test");
    defer lean.lean_dec_ref(str);
    
    try testing.expect(!lean.isExternal(str));
    try testing.expect(lean.isString(str));
}
