# Example 10: External Objects - File I/O with Native Resource Management

This example demonstrates how to use external objects to wrap native resources (file handles) with automatic cleanup.

## What This Example Shows

- **External Class Registration**: Creating a class descriptor with custom finalizer
- **Resource Wrapping**: Wrapping native file handles as Lean objects
- **Automatic Cleanup**: Finalizer automatically closes files when objects are garbage collected
- **Type-Safe Access**: Safely accessing native data from Lean code
- **Error Handling**: Proper error handling with IO results
- **Borrowed vs Owned**: Using borrowed references (`@&`) for read-only operations

## Key Concepts

### External Objects

External objects allow you to wrap arbitrary native (Zig/C) data structures as Lean objects. The Lean runtime will automatically call your finalizer function when the object's reference count reaches zero, ensuring proper resource cleanup.

### Finalizer

The finalizer is a function called automatically when a Lean object is garbage collected:

```zig
fn fileFinalize(data: *anyopaque) callconv(.c) void {
    const handle: *FileHandle = @ptrCast(@alignCast(data));
    handle.fd.close();          // Close native resource
    allocator.free(handle.path); // Free native memory
    allocator.destroy(handle);   // Free the structure
}
```

**Important**: The finalizer only needs to clean up *your* native resources. The Lean runtime handles freeing the object header.

### Class Registration

External classes must be registered once at program startup:

```zig
export fn initFileClass() void {
    file_class = lean.registerExternalClass(fileFinalize, null);
}
```

The second parameter (`foreach`) is for GC traversal if your native data holds Lean objects. For pure native data (like file handles), pass `null`.

### Memory Ownership

- **Owned references** (`FileHandle`): Caller owns and must eventually release
- **Borrowed references** (`@& FileHandle`): Caller retains ownership, callee just reads
- The Zig FFI uses `obj_arg` (owned) vs `b_obj_arg` (borrowed) accordingly

## Building and Running

From this directory:

```bash
# Build
lake build

# Run
lake exe external-objects
```

Expected output:
```
=== External Objects Example: File I/O ===

1. Creating test file...
   Wrote 153 bytes

2. Reading test file...
   Read 153 bytes

Content:
Hello from Lean via Zig FFI!
External objects provide automatic resource management.
The file will be closed automatically when no longer needed.

3. File closed explicitly

✓ External object finalizer will clean up resources automatically!
[Zig] Finalizing file: test-output.txt
```

Note the finalizer message at the end - this proves the resource was cleaned up automatically!

## Code Structure

### Lean Side (`Main.lean`)

```lean
-- Opaque type hides implementation details
opaque FileHandle : Type

-- Operations use this opaque type
@[extern "openFile"]
opaque openFile (path : String) : IO FileHandle
```

The `opaque` keyword makes `FileHandle` an abstract type - Lean code can't inspect its contents, only pass it to Zig functions.

### Zig Side (`zig/file_io.zig`)

```zig
// Native structure (not visible to Lean)
const FileHandle = struct {
    fd: std.fs.File,
    path: []const u8,
    bytes_read: usize,
    bytes_written: usize,
};

// Wrap in external object
const ext = lean.allocExternal(file_class, handle);
```

The native `FileHandle` struct contains a real file descriptor and metadata. When wrapped, Lean code can pass it around but can't see inside.

## Common Patterns

### Pattern 1: Proper Error Handling

```zig
export fn openFile(path_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    defer lean.lean_dec_ref(path_obj);
    
    const handle = allocator.create(FileHandle) catch {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    handle.fd = std.fs.cwd().createFile(...) catch {
        allocator.destroy(handle);  // Clean up on error!
        const err = lean.lean_mk_string("file open failed");
        return lean.ioResultMkError(err);
    };
    
    // More initialization...
}
```

Always clean up resources in error paths before returning!

### Pattern 2: Borrowed References

```zig
// Borrowed reference - Lean code keeps ownership
export fn getFileStats(file_obj: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    // No defer lean_dec_ref here!
    const handle: *FileHandle = @ptrCast(@alignCast(
        lean.getExternalData(file_obj)
    ));
    // Use handle...
}
```

When the Lean signature uses `@& FileHandle`, the Zig function receives `b_obj_arg` (borrowed) and must not dec_ref it.

### Pattern 3: Multiple Cleanup Points

```zig
handle.fd = openFile(...) catch {
    allocator.free(handle.path);  // Already allocated path
    allocator.destroy(handle);    // Already allocated handle
    return error;
};

const ext = lean.allocExternal(...) orelse {
    handle.fd.close();           // Already opened file
    allocator.free(handle.path); // Already allocated path
    allocator.destroy(handle);   // Already allocated handle
    return error;
};
```

Track what's been allocated and ensure cleanup at every error point.

## When to Use External Objects

Use external objects when you need to:

- **Wrap OS resources**: Files, sockets, processes
- **Integrate C libraries**: Database connections, graphics contexts
- **Manage complex state**: Game engines, simulations
- **Control lifetimes**: Resources that need explicit cleanup

**Don't use for**:
- Simple data structures (use constructors instead)
- Shared, immutable data (use regular Lean types)
- Things that don't need finalization

## Related Examples

- **01-hello-ffi**: Basic FFI without external objects
- **02-boxing**: Boxing/unboxing simple values
- **06-io-results**: IO error handling patterns

## Further Reading

- [API Reference](../../doc/api.md#external-objects): Complete external object API
- [Usage Guide](../../doc/usage.md): More external object examples
- [Lean FFI Guide](https://lean-lang.org/): Official Lean FFI documentation
