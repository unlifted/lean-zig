const lean = @import("lean-zig");

/// Create a greeting string
export fn zig_create_greeting(world: lean.obj_arg) lean.obj_res {
    _ = world;

    const message = "Hello from Zig!";
    const str = lean.lean_mk_string_from_bytes(message.ptr, message.len);

    return lean.ioResultMkOk(str);
}

/// Get string length (bytes and Unicode char count)
export fn zig_string_length(str: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    const byte_size = lean.stringSize(str) - 1; // Exclude null terminator
    const char_len = lean.stringLen(str);

    // Return tuple (Nat × Nat)
    const pair = lean.allocCtor(0, 0, @sizeOf(usize) * 2) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    lean.ctorSetUsize(pair, 0, byte_size);
    lean.ctorSetUsize(pair, @sizeOf(usize), char_len);

    return lean.ioResultMkOk(pair);
}

/// Reverse a string (byte-wise, not Unicode-aware)
export fn zig_reverse_string(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(str);

    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1; // Exclude null

    var buffer: [256]u8 = undefined;
    if (len > 256) {
        const err = lean.lean_mk_string("string too long");
        return lean.ioResultMkError(err);
    }

    // Reverse bytes
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buffer[len - 1 - i] = cstr[i];
    }

    const result = lean.lean_mk_string_from_bytes(&buffer, len);
    return lean.ioResultMkOk(result);
}

/// Check if two strings are equal
export fn zig_strings_equal(str1: lean.b_obj_arg, str2: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    const equal = lean.stringEq(str1, str2);

    // Box boolean (false=0, true=1 as constructor tags)
    const result = lean.allocCtor(if (equal) 1 else 0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(result);
}

/// Lexicographic comparison: str1 < str2
export fn zig_string_less_than(str1: lean.b_obj_arg, str2: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    const less_than = lean.stringLt(str1, str2);

    // Box boolean
    const result = lean.allocCtor(if (less_than) 1 else 0, 0, 0) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(result);
}
