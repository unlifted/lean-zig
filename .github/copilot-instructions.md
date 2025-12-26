# Copilot Instructions for lean-zig

## Project Overview

This project provides Zig FFI bindings for the Lean 4 runtime, enabling Zig code to interoperate with Lean without C shims. It's a **library** (not an application), designed for reuse by downstream projects.

## Code Style & Conventions

### Naming
- **Zig wrapper functions**: Use `camelCase` (e.g., `allocCtor`, `arrayGet`, `stringMk`)
- **C API bindings**: Keep original `snake_case` with `lean_` prefix (e.g., `lean_inc_ref`, `lean_alloc_object`)
- **Constants and types**: Use `PascalCase` for types (e.g., `Object`, `StringObject`), `camelCase` for constants
- **Test names**: Use descriptive lowercase with spaces (e.g., `test "array get and set operations"`)

### Zig Style
- Prefer explicit over implicit
- Use `orelse` for null handling, not `if/else` patterns
- Use `defer` for cleanup (especially `lean_dec_ref`)
- Include safety checks before unsafe operations (e.g., check `isScalar` before `unboxUsize`)
- Use `@ptrCast` and `@alignCast` explicitly when needed

### Documentation
- All public functions must have doc comments (`///`)
- Include preconditions, parameters, return values, and examples where helpful
- Document ownership semantics clearly (`obj_arg` = takes ownership, `b_obj_arg` = borrows, `obj_res` = returns ownership)
- Add inline comments for non-obvious pointer arithmetic or memory layouts

## Memory Safety Rules

### Reference Counting (CRITICAL)
- Always `lean_dec_ref` owned objects when done
- Never `dec_ref` borrowed objects (`b_obj_arg`)
- Use `defer lean_dec_ref(obj)` immediately after allocation in tests
- Check `isExclusive` before in-place mutations
- Never use an object after calling `dec_ref` on it

### Type Safety
- Always check object types before casting (use `isScalar`, `isCtor`, `isArray`, etc.)
- Validate array bounds before access
- Check allocation failures (`orelse` clauses)
- Never assume a tagged pointer is a heap object or vice versa

## Testing

### Test Organization
- Tests go in `Zig/lean_test.zig`, NOT inline in `Zig/lean.zig`
- Group tests by category with section comments
- Test both success and error cases
- Include edge cases (empty arrays, zero values, max tagged pointer values)

### Test Patterns
```zig
test "descriptive name" {
    const obj = lean.allocCtor(0, 0, 0) orelse return error.AllocationFailed;
    defer lean.lean_dec_ref(obj); // Always defer cleanup
    
    // Test assertions
    try testing.expectEqual(expected, actual);
}
```

### Test Coverage Priorities
1. Memory safety (reference counting, no leaks, no double-frees)
2. Type correctness (boxing/unboxing round-trips)
3. API contracts (array bounds, null handling)
4. Edge cases (empty inputs, maximum values)

## Build & CI

### Lake Configuration
- This is a **library**, so do NOT commit `lake-manifest.json`
- The `lakefile.lean` defines Zig build targets, not Lean executables
- CI must run `lake update` before `lake build`

### Zig Build
- Zig test files must link against Lean runtime: `-lc -lleanrt -lleanshared`
- Use `-fPIC` for shared library builds
- Optimization: `-O ReleaseFast` for production

## Common Mistakes to Avoid

1. **Don't forget reference counting**: Every owned `obj_arg` must be `dec_ref`'d
2. **Don't commit lake-manifest.json**: Libraries should let downstream resolve dependencies
3. **Don't mix naming conventions**: Zig functions use camelCase, C bindings use snake_case
4. **Don't unbox without checking**: Always verify `isScalar` before calling `unboxUsize`
5. **Don't use after free**: Never access an object after `dec_ref`
6. **Don't assume non-null**: Use `orelse` for all allocations

## Pull Request Guidelines

### What to Check
- All public functions have doc comments
- Tests added for new functionality
- No inline tests in `Zig/lean.zig`
- Reference counting is correct (no leaks, no double-frees)
- Error paths release resources properly
- Documentation updated (README, api.md, usage.md if API changes)

### After Pushing to PR Branch
**ALWAYS verify CI passes after pushing changes to a PR branch:**
```bash
# Wait a moment for CI to start, then check status
GH_PAGER=cat gh run list --branch <branch-name> --limit 1

# If failed, get logs
GH_PAGER=cat gh run view <run-id> --log-failed
```

### Using GitHub CLI (gh)
**Always disable the pager** to avoid interactive mode that requires 'q' to exit:
```bash
# Set pager to cat for all gh commands
GH_PAGER=cat gh pr view 1
GH_PAGER=cat gh run list
GH_PAGER=cat gh api ...
```

Or set it permanently in your environment:
```bash
export GH_PAGER=cat
```

### Code Review Focus
1. Memory safety (reference counting, null checks)
2. Type safety (proper use of `isScalar`, `isCtor`, etc.)
3. API consistency (naming, ownership semantics)
4. Test coverage (edge cases, error paths)
5. Documentation completeness

## Performance Considerations

- Prefer stack allocation over heap when possible
- Use `isExclusive` to enable in-place mutations
- Batch reference count operations when safe
- For bulk primitives, consider scalar arrays instead of boxing each element
- Tagged pointers (small integers) are zero-cost

## Examples of Good Code

### Memory Management
```zig
// ✅ Good: defer ensures cleanup even on error paths
const obj = lean.allocCtor(0, 1, 0) orelse {
    return lean.ioResultMkError(err);
};
defer lean.lean_dec_ref(obj);

// ✅ Good: check before unboxing
if (lean.isScalar(val)) {
    const n = lean.unboxUsize(val);
    // use n...
}
```

### Error Handling
```zig
// ✅ Good: handle allocation failure explicitly
const arr = lean.allocArray(size) orelse {
    const err = lean.lean_mk_string_from_bytes("allocation failed", 17);
    return lean.ioResultMkError(err);
};
```

## Architecture Notes

- **No C shim layer**: Direct extern declarations matching lean.h
- **Inline function reimplementation**: Lean's inline functions must be reimplemented in Zig
- **ABI stability**: Lean does not guarantee C ABI stability; pin Lean version in `lean-toolchain`
- **Platform**: Targets 64-bit systems (tagged pointers assume 63-bit value space)

## When to Consult

- Major API changes or additions
- Memory model questions (ownership, lifetimes)
- Performance-sensitive code paths
- Integration with new Lean runtime features
- Breaking changes to public API
