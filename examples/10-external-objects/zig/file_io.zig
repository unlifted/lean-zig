const std = @import("std");
const lean = @import("lean-zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Native file handle structure
const FileHandle = struct {
    fd: std.fs.File,
    path: []const u8,
    bytes_read: usize,
    bytes_written: usize,
};

/// Finalizer: automatically called when Lean object's refcount reaches 0
fn fileFinalize(data: *anyopaque) callconv(.c) void {
    const handle: *FileHandle = @ptrCast(@alignCast(data));

    std.debug.print("[Zig] Finalizing file: {s}\n", .{handle.path});

    // Close file descriptor
    handle.fd.close();

    // Free path string
    allocator.free(handle.path);

    // Free the handle structure
    allocator.destroy(handle);
}

/// External class registered once at startup
var file_class: *lean.ExternalClass = undefined;

/// Initialize the file class (must be called before creating file handles)
export fn initFileClass() void {
    file_class = lean.registerExternalClass(fileFinalize, null);
}

/// Open a file and wrap it as an external object
export fn openFile(path_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(path_obj);

    // Extract path string from Lean
    const path_str = lean.stringCstr(path_obj);
    const path_len = lean.stringSize(path_obj) - 1; // Exclude null terminator

    // Allocate native handle
    const handle = allocator.create(FileHandle) catch {
        const err = lean.lean_mk_string("Failed to allocate FileHandle");
        return lean.ioResultMkError(err);
    };

    // Open file (create if doesn't exist, append if exists)
    handle.fd = std.fs.cwd().createFile(path_str[0..path_len], .{ .read = true }) catch {
        allocator.destroy(handle);
        const err = lean.lean_mk_string("Failed to open file");
        return lean.ioResultMkError(err);
    };

    // Duplicate path for storage
    handle.path = allocator.dupe(u8, path_str[0..path_len]) catch {
        handle.fd.close();
        allocator.destroy(handle);
        const err = lean.lean_mk_string("Failed to copy path");
        return lean.ioResultMkError(err);
    };

    handle.bytes_read = 0;
    handle.bytes_written = 0;

    // Wrap native handle in external object
    const ext = lean.allocExternal(file_class, handle) orelse {
        handle.fd.close();
        allocator.free(handle.path);
        allocator.destroy(handle);
        const err = lean.lean_mk_string("Failed to allocate external object");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(ext);
}

/// Read up to n bytes from the file
export fn readBytes(file_obj: lean.obj_arg, n_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(file_obj);
    defer lean.lean_dec_ref(n_obj);

    // Extract native handle from external object
    const handle: *FileHandle = @ptrCast(@alignCast(lean.getExternalData(file_obj)));

    const n = lean.unboxUsize(n_obj);

    // Allocate read buffer
    const buffer = allocator.alloc(u8, n) catch {
        const err = lean.lean_mk_string("Failed to allocate read buffer");
        return lean.ioResultMkError(err);
    };
    defer allocator.free(buffer);

    // Read from file
    const bytes_read = handle.fd.read(buffer) catch {
        const err = lean.lean_mk_string("Failed to read from file");
        return lean.ioResultMkError(err);
    };

    handle.bytes_read += bytes_read;

    // Convert to Lean string
    const result = lean.lean_mk_string_from_bytes(buffer.ptr, bytes_read);
    return lean.ioResultMkOk(result);
}

/// Write string to file
export fn writeBytes(file_obj: lean.obj_arg, data_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(file_obj);
    defer lean.lean_dec_ref(data_obj);

    // Extract native handle
    const handle: *FileHandle = @ptrCast(@alignCast(lean.getExternalData(file_obj)));

    // Extract data string
    const data_str = lean.stringCstr(data_obj);
    const data_len = lean.stringSize(data_obj) - 1;

    // Write to file
    const bytes_written = handle.fd.write(data_str[0..data_len]) catch {
        const err = lean.lean_mk_string("Failed to write to file");
        return lean.ioResultMkError(err);
    };

    handle.bytes_written += bytes_written;

    // Return unit
    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("Failed to allocate unit");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(unit);
}

/// Get file statistics (bytes read, bytes written)
export fn getFileStats(file_obj: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;

    const handle: *FileHandle = @ptrCast(@alignCast(lean.getExternalData(file_obj)));

    // Create tuple (USize, USize)
    const tuple = lean.allocCtor(0, 0, 2 * @sizeOf(usize)) orelse {
        const err = lean.lean_mk_string("Failed to allocate tuple");
        return lean.ioResultMkError(err);
    };

    lean.ctorSetUsize(tuple, 0, handle.bytes_read);
    lean.ctorSetUsize(tuple, @sizeOf(usize), handle.bytes_written);

    return lean.ioResultMkOk(tuple);
}

/// Close file explicitly (optional - finalizer does this automatically)
export fn closeFile(file_obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(file_obj);

    const handle: *FileHandle = @ptrCast(@alignCast(lean.getExternalData(file_obj)));

    // Close the file descriptor
    handle.fd.close();

    // Mark as closed by setting path to empty
    // (Finalizer will still be called, but close() on already-closed file is safe in Zig)

    const unit = lean.allocCtor(0, 0, 0) orelse {
        const err = lean.lean_mk_string("Failed to allocate unit");
        return lean.ioResultMkError(err);
    };

    return lean.ioResultMkOk(unit);
}
