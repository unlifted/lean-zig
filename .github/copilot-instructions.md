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

## Git Workflow (CRITICAL)

### Before Creating Feature Branches
**ALWAYS pull main first to avoid merge conflicts:**
```bash
git checkout main
git pull origin main
git checkout -b feature/new-branch
```

This project has a single developer, so merge conflicts should be rare. Following this pattern keeps the history clean and rebases/merges simple.

## Build & CI

### Lake Configuration
- This is a **library**, and normally libraries don't commit `lake-manifest.json`
- **Exception**: We DO commit `lake-manifest.json` for [Reservoir](https://reservoir.lean-lang.org) auto-indexing
- The `lakefile.lean` defines Zig build targets, not Lean executables
- CI must run `lake update` before `lake build`

### Zig Build
- Zig test files must link against Lean runtime: `-lc -lleanrt -lleanshared`
- Use `-fPIC` for shared library builds
- Optimization: `-O ReleaseFast` for production

## Common Mistakes to Avoid

1. **Don't forget reference counting**: Every owned `obj_arg` must be `dec_ref`'d
2. **Don't commit lake-manifest.json**: Libraries should let downstream resolve dependencies (EXCEPTION: We do commit it for Reservoir indexing)
3. **Don't mix naming conventions**: Zig functions use camelCase, C bindings use snake_case
4. **Don't unbox without checking**: Always verify `isScalar` before calling `unboxUsize`
5. **Don't use after free**: Never access an object after `dec_ref`
6. **Don't assume non-null**: Use `orelse` for all allocations
7. **NEVER push directly to main**: ALL changes must go through Pull Requests with review
8. **NEVER commit temporary files**: Planning docs, scratch notes, analysis files stay local
9. **ALWAYS check CI after push**: Verify GitHub Actions pass before considering PR complete
10. **Check unsigned comparisons**: `>= 0` is always true for `usize`, use `> 0` or remove check
11. **Verify spelling**: Run spell check on comments and documentation
12. **Count accurately**: Double-check all numeric claims (test counts, line numbers, etc.)

## Pre-Commit Quality Checklist (MANDATORY)

**Before EVERY commit, verify:**

### Code Quality
- [ ] **NO spelling errors** in comments, docs, or variable names
- [ ] **NO meaningless checks** (e.g., `unsigned >= 0`, always-true conditions)
- [ ] **NO unsigned underflow** checks that can't fail
- [ ] **Consistent naming** (camelCase for Zig, snake_case for C bindings)
- [ ] **Proper null handling** (`orelse` not `if/else` for optionals)

### Documentation Consistency
- [ ] **Test counts accurate** (verify with `git diff main file.zig | grep -c '^+test "'`)
- [ ] **CHANGELOG matches reality** (test counts, API changes, all accurate)
- [ ] **Performance targets documented** correctly (match actual thresholds in code)
- [ ] **No contradictions** between docs and implementation
- [ ] **Precondition sections complete** for all unsafe functions

### Memory Safety
- [ ] **Every allocation has matching `dec_ref`** in all paths (success AND error)
- [ ] **`defer` used correctly** for cleanup
- [ ] **No use-after-free** scenarios possible
- [ ] **Type checks before casts** (isScalar, isCtor, etc.)

### Testing
- [ ] **All tests pass locally** (`zig build test`)
- [ ] **Performance tests realistic** for CI environments
- [ ] **Edge cases covered** (null, zero, boundary values)
- [ ] **No test gaps** in new functionality

### CI/CD
- [ ] **CI passing on GitHub Actions** after every push
- [ ] **No temporary files committed** (test-plan.md, notes.md, scratch.txt, etc.)
- [ ] **Branch up to date** with remote before pushing

## Post-Push Verification (MANDATORY)

**After EVERY push to a PR branch:**

```bash
# Wait 30 seconds for CI to start
sleep 30

# Check CI status
GH_PAGER=cat gh run list --branch <branch-name> --limit 1

# If failed, get logs immediately
GH_PAGER=cat gh run view <run-id> --log-failed

# Fix issues and recommit
```

**Never wait for Copilot to catch mistakes. Catch them yourself first.**

## Contributing Guidelines

**ALWAYS follow the comprehensive guidelines in [CONTRIBUTING.md](../CONTRIBUTING.md)**, which includes:
- Development workflow and code style
- Versioning strategy (semantic versioning)
- Release process and version tagging
- Maintainer guide for Lean runtime updates
- Performance testing requirements
- Complete PR review checklist

### Key Requirements for All Changes

#### Documentation Updates
- All public functions must have doc comments (`///`)
- Update [api.md](../doc/api.md) when adding/changing public APIs
- Update [usage.md](../doc/usage.md) for new usage patterns
- Update README.md for major feature additions

#### CHANGELOG.md Updates (CRITICAL)
**ALWAYS update [CHANGELOG.md](../CHANGELOG.md)** under the `[Unreleased]` section when making changes:

- **Added**: New features, functions, or capabilities
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for removal
- **Removed**: Deleted features
- **Fixed**: Bug fixes
- **Security**: Security-related changes

Example:
```markdown
## [Unreleased]

### Added
- `arraySwap` function for efficient element swapping

### Fixed
- Memory leak in error path of `allocArray`
```

#### Versioning Impact
Consider which version component should be incremented (see [CONTRIBUTING.md](../CONTRIBUTING.md#versioning-strategy)):
- **MAJOR**: Breaking API changes, removed functions, signature changes
- **MINOR**: New functions, features, or backward-compatible additions
- **PATCH**: Bug fixes, documentation corrections, no API changes

### Pull Request Checklist
- [ ] All public functions have doc comments
- [ ] Tests added for new functionality
- [ ] No inline tests in `Zig/lean.zig` (use `Zig/lean_test.zig`)
- [ ] Reference counting is correct (no leaks, no double-frees)
- [ ] Error paths release resources properly
- [ ] **CHANGELOG.md updated** under `[Unreleased]` section
- [ ] Documentation updated (api.md, usage.md, README.md if needed)
- [ ] Versioning impact considered and noted in PR description

### Git Workflow (CRITICAL)

**NEVER commit directly to main branch. ALL changes require Pull Requests.**

1. **Create feature branch**: `git checkout -b feature/description`
2. **Commit changes**: `git commit -am "Description"`
3. **Push branch**: `git push origin feature/description`
4. **Create PR**: Use GitHub UI or `gh pr create`
5. **Wait for review**: Do not merge without approval
6. **After approval**: Merge via GitHub UI

**DO NOT USE:**
- `git push origin main`
- Direct commits to main
- Force pushes to main

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
