//! External (foreign) object support for wrapping native data.
//!
//! External objects allow wrapping arbitrary Zig/C data structures as Lean objects
//! with custom finalization logic. This is essential for FFI work with resources
//! like file handles, database connections, sockets, and native data structures.
//!
//! ## Usage Pattern
//!
//! 1. Define a finalizer function that cleans up your native resources
//! 2. Register an external class with the Lean runtime
//! 3. Allocate external objects wrapping your native data
//! 4. Access native data via `getExternalData()`
//! 5. Finalizer automatically called when object's refcount reaches 0
//!
//! ## Example
//!
//! ```zig
//! const FileHandle = struct {
//!     fd: std.fs.File,
//!     path: []const u8,
//! };
//!
//! fn fileFinalize(data: *anyopaque) callconv(.C) void {
//!     const handle: *FileHandle = @ptrCast(@alignCast(data));
//!     handle.fd.close();
//!     allocator.free(handle.path);
//!     allocator.destroy(handle);
//! }
//!
//! // Register once at startup
//! const file_class = lean.registerExternalClass(fileFinalize, null);
//!
//! // Create external object
//! export fn openFile(path: lean.obj_arg) lean.obj_res {
//!     const handle = allocator.create(FileHandle);
//!     handle.fd = std.fs.cwd().openFile(...);
//!
//!     const ext = lean.allocExternal(file_class, handle);
//!     return lean.ioResultMkOk(ext);
//! }
//!
//! // Use in operations
//! export fn readBytes(file_obj: lean.obj_arg, n: usize) lean.obj_res {
//!     const handle: *FileHandle = @ptrCast(@alignCast(
//!         lean.getExternalData(file_obj)
//!     ));
//!     const bytes = handle.fd.read(...);
//!     // ...
//! }
//! ```

const types = @import("types.zig");
const memory = @import("memory.zig");

pub const obj_arg = types.obj_arg;
pub const b_obj_arg = types.b_obj_arg;
pub const obj_res = types.obj_res;
pub const Object = types.Object;
pub const ExternalClass = types.ExternalClass;
pub const ExternalObject = types.ExternalObject;
pub const lean_alloc_object = memory.lean_alloc_object;

// ============================================================================
// External Functions from Lean Runtime
// ============================================================================

/// Register an external class with the Lean runtime.
///
/// Must be called before creating external objects of this class.
/// Typically registered once at program startup.
///
/// ## Parameters
/// - `finalize`: Called when object's refcount reaches 0. Must free native resources.
///               Can be null if no cleanup needed (rare).
/// - `foreach`: Called during GC marking. Must visit any Lean objects held by native data.
///              Can be null if native data doesn't hold Lean objects (common case).
///
/// ## Returns
/// Pointer to registered external class. Store this and reuse for all objects of this type.
///
/// ## Thread Safety
/// Registration is thread-safe and typically done at startup.
pub extern fn lean_register_external_class(
    finalize: ?*const fn (*anyopaque) callconv(.c) void,
    foreach: ?*const fn (*anyopaque, b_obj_arg) callconv(.c) void,
) *ExternalClass;

// ============================================================================
// Inline Wrapper Functions
// ============================================================================

/// Register an external class.
///
/// Wrapper around `lean_register_external_class` for type safety.
///
/// ## Finalizer Signature
/// ```zig
/// fn myFinalizer(data: *anyopaque) callconv(.C) void {
///     const my_data: *MyType = @ptrCast(@alignCast(data));
///     // Free native resources
///     my_data.resource.close();
///     // Dec_ref any Lean objects held
///     if (my_data.lean_value) |val| {
///         lean.lean_dec_ref(val);
///     }
///     // Free your structure
///     allocator.destroy(my_data);
///     // DON'T free Lean object header - runtime handles that!
/// }
/// ```
///
/// ## Foreach Signature (optional)
/// ```zig
/// fn myForeach(data: *anyopaque, visitor: lean.b_obj_arg) callconv(.C) void {
///     const my_data: *MyType = @ptrCast(@alignCast(data));
///     // Tell GC about Lean objects you're holding
///     if (my_data.cached_result) |result| {
///         lean.lean_apply_1(visitor, result);
///     }
/// }
/// ```
///
/// ## Performance
/// Called once per class at startup. Zero overhead after registration.
pub inline fn registerExternalClass(
    finalize: ?*const fn (*anyopaque) callconv(.c) void,
    foreach: ?*const fn (*anyopaque, b_obj_arg) callconv(.c) void,
) *ExternalClass {
    return lean_register_external_class(finalize, foreach);
}

/// Allocate an external object wrapping native data.
///
/// Creates a Lean object that wraps a pointer to your native data structure.
/// When the object's refcount reaches 0, the class's finalizer is called.
///
/// ## Preconditions
/// - `class` must be a registered external class
/// - `data` must be a valid pointer to your native structure
/// - `data` must remain valid until finalizer is called
///
/// ## Parameters
/// - `class`: External class descriptor (from `registerExternalClass`)
/// - `data`: Pointer to your native data
///
/// ## Returns
/// External object with refcount=1, or null on allocation failure.
/// Return type is `obj_res` (which is `?*Object`), making this an optional pointer.
///
/// ## Memory Ownership
/// - The returned object has refcount=1 (caller owns initial reference)
/// - Native data lifetime is managed by your finalizer
/// - Lean runtime manages the object header lifetime
///
/// ## Performance
/// Inline function. Allocation cost: ~same as allocCtor.
///
/// ## Example
/// ```zig
/// const handle = allocator.create(FileHandle) catch return null;
/// handle.* = FileHandle{ .fd = file, .path = path };
///
/// const ext = lean.allocExternal(file_class, handle) orelse {
///     allocator.destroy(handle);
///     return error.AllocationFailed;
/// };
/// defer lean.lean_dec_ref(ext);
/// ```
pub inline fn allocExternal(class: *ExternalClass, data: *anyopaque) obj_res {
    // Allocate object header + class pointer + data pointer
    const obj_ptr = @as(?*ExternalObject, @ptrCast(@alignCast(
        lean_alloc_object(@sizeOf(ExternalObject)),
    ))) orelse return null;

    // Initialize fields
    obj_ptr.m_header.m_rc = 1;
    obj_ptr.m_header.m_cs_sz = @sizeOf(ExternalObject);
    obj_ptr.m_header.m_other = 0;
    obj_ptr.m_header.m_tag = types.Tag.external;
    obj_ptr.m_class = class;
    obj_ptr.m_data = data;

    return @ptrCast(obj_ptr);
}

/// Get the native data pointer from an external object.
///
/// Extracts the wrapped native data from an external object.
/// Cast the result to your native type.
///
/// ## Preconditions
/// - `o` must be a valid external object (check with `isExternal()`)
/// - Undefined behavior if called on non-external object
///
/// ## Parameters
/// - `o`: External object (borrowed reference)
///
/// ## Returns
/// Pointer to native data (as passed to `allocExternal`).
///
/// ## Performance
/// **2 CPU instructions**: 1 cast + 1 load
///
/// ## Example
/// ```zig
/// const handle: *FileHandle = @ptrCast(@alignCast(
///     lean.getExternalData(file_obj)
/// ));
/// _ = handle.fd.read(buffer);
/// ```
pub inline fn getExternalData(o: b_obj_arg) *anyopaque {
    const ext: *ExternalObject = @ptrCast(@alignCast(o));
    return ext.m_data;
}

/// Get the external class from an external object.
///
/// Retrieves the class descriptor for an external object.
/// Rarely needed in user code.
///
/// ## Preconditions
/// - `o` must be a valid external object
///
/// ## Parameters
/// - `o`: External object (borrowed reference)
///
/// ## Returns
/// External class descriptor.
///
/// ## Performance
/// **2 CPU instructions**: 1 cast + 1 load
pub inline fn getExternalClass(o: b_obj_arg) *ExternalClass {
    const ext: *ExternalObject = @ptrCast(@alignCast(o));
    return ext.m_class;
}

/// Set new native data for an external object.
///
/// Replaces the data pointer in an external object. If the object is exclusive
/// (refcount=1), modifies in-place. Otherwise, allocates a new object.
///
/// **Note:** The old data is NOT freed by this function. Typically you'd
/// free it in the class finalizer, or explicitly before calling this function.
///
/// ## Preconditions
/// - `o` must be a valid external object
///
/// ## Parameters
/// - `o`: External object (takes ownership)
/// - `data`: New data pointer
///
/// ## Returns
/// External object with updated data (transfers ownership).
///
/// ## Performance
/// Inline function. Fast path if exclusive.
///
/// ## Example
/// ```zig
/// // Typically you'd free old data first
/// const old_data: *MyData = @ptrCast(@alignCast(lean.getExternalData(obj)));
/// allocator.destroy(old_data);
///
/// const new_data = allocator.create(MyData);
/// const updated = lean.setExternalData(obj, new_data) orelse {
///     allocator.destroy(new_data);
///     return error.AllocationFailed;
/// };
/// ```
pub inline fn setExternalData(o: obj_arg, data: *anyopaque) ?obj_res {
    const obj = o orelse return null;

    if (memory.isExclusive(obj)) {
        // Exclusive - modify in place
        const ext: *ExternalObject = @ptrCast(@alignCast(obj));
        ext.m_data = data;
        return obj;
    } else {
        // Shared - allocate new object
        const class = getExternalClass(obj);
        const new_obj = allocExternal(class, data);

        memory.lean_dec_ref(obj);
        return new_obj;
    }
}
