# Example 05: Strings

**Difficulty:** Intermediate  
**Concepts:** Text processing, UTF-8, string operations, C interop

## What You'll Learn

- Creating strings from Zig
- Accessing string content and metadata
- String comparison operations
- UTF-8 handling and byte access

## Building and Running

```bash
lake build
lake exe strings-demo
```

Expected output:
```
Greeted: Hello from Zig!
Length: 14 bytes, 14 chars
Reversed: !giZ morf olleH
Strings equal: false
'apple' < 'banana': true
```

## Key Concepts

### String Creation

```zig
// From null-terminated C string
const cstr: [*:0]const u8 = "Hello";
const str = lean.lean_mk_string(cstr);

// From byte slice
const bytes: []const u8 = "Hello";
const str = lean.lean_mk_string_from_bytes(bytes.ptr, bytes.len);
```

### String Access

```zig
// Get C string pointer (null-terminated)
const cstr = lean.stringCstr(str);

// Get byte size (includes null terminator)
const byte_size = lean.stringSize(str);

// Get Unicode length (code point count)
const char_count = lean.stringLen(str);

// Get allocated capacity
const capacity = lean.stringCapacity(str);
```

### Fast Byte Access

```zig
// Get byte at index (no bounds checking)
const byte = lean.stringGetByteFast(str, 0);

// Convert to Zig slice
const cstr = lean.stringCstr(str);
const len = lean.stringSize(str) - 1;  // Exclude null
const slice: []const u8 = cstr[0..len];
```

### String Comparison

```zig
// Equality
if (lean.stringEq(str1, str2)) { ... }

// Inequality
if (lean.stringNe(str1, str2)) { ... }

// Lexicographic comparison
if (lean.stringLt(str1, str2)) { ... }  // str1 < str2
```

## UTF-8 Handling

Lean strings are UTF-8 encoded. Be careful when working with byte indices vs character indices:

```zig
const str = lean.lean_mk_string("Hello 世界");  // Mixed ASCII and CJK
const byte_size = lean.stringSize(str);       // Bytes (11 + null)
const char_len = lean.stringLen(str);          // Unicode points (8)
```

**Important:** Byte operations (like `stringGetByteFast`) work with bytes, not characters. For multi-byte UTF-8 sequences, iterate by character using Lean's UTF-8 functions (not shown in this example).

## Memory Management

### String Ownership

Strings are reference-counted objects:

```zig
export fn process_string(str: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(str);  // Takes ownership, must clean up
    
    // Work with string...
    const cstr = lean.stringCstr(str);
    
    return lean.ioResultMkOk(result);
}
```

### String Immutability

Lean strings are immutable. To "modify" a string, create a new one:

```zig
// WRONG: Can't modify in-place
// lean.stringCstr(str)[0] = 'X';  // Undefined behavior!

// CORRECT: Create new string
var buffer: [256]u8 = undefined;
// ... fill buffer ...
const new_str = lean.lean_mk_string_from_bytes(&buffer, len);
```

## Performance Notes

- String creation: **~20-50ns** for small strings (<256 bytes)
- String comparison: **~0.5-2ns per byte** (depends on prefix match)
- Byte access: **~1-2ns** per byte (unchecked)
- C string conversion: **Zero cost** (already null-terminated internally)

## Common Patterns

### Reverse a string (byte-level)

```zig
const cstr = lean.stringCstr(str);
const len = lean.stringSize(str) - 1;

var buffer: [256]u8 = undefined;
if (len > 256) return error.TooLong;

var i: usize = 0;
while (i < len) : (i += 1) {
    buffer[len - 1 - i] = cstr[i];
}

const result = lean.lean_mk_string_from_bytes(&buffer, len);
```

### Concatenate strings

```zig
const str1_cstr = lean.stringCstr(str1);
const str1_len = lean.stringSize(str1) - 1;
const str2_cstr = lean.stringCstr(str2);
const str2_len = lean.stringSize(str2) - 1;

var buffer: [512]u8 = undefined;
@memcpy(buffer[0..str1_len], str1_cstr[0..str1_len]);
@memcpy(buffer[str1_len..][0..str2_len], str2_cstr[0..str2_len]);

const result = lean.lean_mk_string_from_bytes(&buffer, str1_len + str2_len);
```

### Check for prefix

```zig
fn hasPrefix(str: lean.b_obj_arg, prefix: []const u8) bool {
    const cstr = lean.stringCstr(str);
    const len = lean.stringSize(str) - 1;
    
    if (len < prefix.len) return false;
    
    for (prefix, 0..) |byte, i| {
        if (cstr[i] != byte) return false;
    }
    
    return true;
}
```

## Next Steps

→ [Example 06: IO Results](../06-io-results) - Learn proper error handling patterns.
