# Contributing to lean-zig

Thank you for your interest in contributing to `lean-zig`! We want this library to be a high-quality example of Lean/Zig interoperability.

## Development Workflow

1.  **Fork and Clone**: Fork the repository and clone it locally.
2.  **Branch**: Create a feature branch for your changes (`git checkout -b my-feature`).
3.  **Implement**: Write your code and tests.
4.  **Format**:
    - Lean: Run `lake run lint` (if configured) or ensure your editor formats on save.
    - Zig: Run `zig fmt Zig/lean.zig`.
5.  **Test**: Run `lake script run test` to ensure everything works.
6.  **Pull Request**: Submit a PR with a clear description of your changes.
7.  **Code Review**: Wait for review and approval before merging.

### CRITICAL: Never Push Directly to Main

**ALL changes must go through Pull Requests**, including:
- Bug fixes
- New features
- Documentation updates
- Version releases
- Configuration changes

**Process:**
1. Create a feature branch: `git checkout -b feature/my-change`
2. Make changes and commit
3. Push branch: `git push origin feature/my-change`
4. Create PR on GitHub
5. Wait for review and CI to pass
6. Merge only after approval

## Code Style

- **Lean**: Follow standard Lean 4 naming conventions (CamelCase for types, camelCase for definitions).
- **Zig**: Follow standard Zig style guide (`camelCase` for functions, `PascalCase` for types).
- **Comments**: Document performance implications for hot-path code.

---

## Maintainer Guide

This section is for maintainers who need to handle Lean runtime updates and performance optimization.

### Handling Lean Runtime Updates

The hybrid JIT strategy automatically syncs with Lean changes, but maintainers should verify after major Lean releases:

#### 1. Automatic Bindings (No Action Required)

The `build.zig` automatically regenerates bindings via `translateC`. When users update Lean:

```bash
elan update
lake clean && lake build
```

The bindings will automatically match the new Lean version. **No changes to lean-zig required.**

#### 2. Manual Inline Functions (Verify After Updates)

Some functions are manually inlined in `Zig/lean.zig` for maximum performance. After a major Lean release:

**Check if these implementations still match `lean.h`:**

```zig
// Hot-path functions that MUST stay synchronized:
- lean_inc_ref()       // Reference count increment
- lean_dec_ref()       // Reference count decrement (fast path)
- boxUsize()           // Tagged pointer encoding
- unboxUsize()         // Tagged pointer decoding
- object field access  // objectTag(), objectRc(), objectOther()
- array access         // arraySize(), arrayUget(), arraySet()
- constructor access   // ctorGet(), ctorSet()
- string access        // stringCstr(), stringSize()
```

**How to verify:**

1. Check `lean.h` for changes to inline functions
2. Compare bit layouts, offsets, and formulas
3. Update `Zig/lean.zig` if implementations changed
4. Run full test suite: `zig build test`
5. Profile performance benchmarks (see below)

#### 3. Memory Layout Changes (Rare but Critical)

If Lean changes `ObjectHeader`, `CtorObject`, `ArrayObject`, or `StringObject` layouts:

1. Update type definitions in `Zig/lean.zig`
2. Update offset calculations in field accessor functions
3. Verify with tests (especially test "constructor stores numObjs in m_other field")
4. Document changes in CHANGELOG.md

### Performance-Critical Functions

These functions are **manually inlined** because they're hot-path operations (called millions of times):

| Function | Why Inlined | CPU Instructions | Impact if Not Inlined |
|----------|-------------|------------------|----------------------|
| `boxUsize` / `unboxUsize` | Tagged pointer ops used everywhere | 1-2 (shift + OR/mask) | 10-20x slowdown |
| `lean_inc_ref` / `lean_dec_ref` | Every object operation needs refcounting | 2-3 (compare + inc/dec) | 5-10x slowdown |
| `objectTag` / `objectRc` | Type checking and optimization decisions | 2 (cast + load) | 3-5x slowdown |
| `arrayUget` / `arrayGet` | Array iteration hot loops | 2-3 (arithmetic + load) | 3-5x slowdown |
| `ctorGet` / `ctorSet` | Field access for algebraic types | 2-3 (arithmetic + load/store) | 3-5x slowdown |
| `stringCstr` / `stringSize` | String processing loops | 2 (arithmetic + load) | 3-5x slowdown |

**Cold-path functions** (forwarded to `lean_raw`):
- `allocCtor`, `allocArray`, `allocString` - Allocation is inherently slow (heap ops)
- `lean_mk_string`, `lean_mk_string_from_bytes` - String creation
- `lean_dec_ref_cold` - Object finalization (complex, handles MT objects)

### When to Inline a New Function

**Inline if:**
1. Called in tight loops (array/string processing)
2. Pure pointer arithmetic or bitwise ops
3. No heap allocation or complex logic
4. Profiling shows significant impact (>5% of runtime)

**Forward to lean_raw if:**
1. Heap allocation required
2. Complex state management
3. Rarely called (once per operation, not per element)
4. Uses platform-specific features (atomics, thread-local storage)

### Performance Testing

After changes to hot-path functions, verify performance:

```zig
// Add to Zig/lean_test.zig
test "benchmark boxing performance" {
    var timer = std.time.Timer.start() catch unreachable;
    
    const iterations = 10_000_000;
    var i: usize = 0;
    var sum: usize = 0;
    while (i < iterations) : (i += 1) {
        const boxed = lean.boxUsize(i);
        sum += lean.unboxUsize(boxed);
    }
    
    const elapsed_ns = timer.read();
    const ns_per_op = elapsed_ns / iterations;
    
    std.debug.print("\nBoxing: {d}ns per operation\n", .{ns_per_op});
    try testing.expect(ns_per_op < 5);  // Should be 1-2ns
}
```

**Expected performance on modern x86_64:**
- Boxing/unboxing: 1-2ns per round-trip
- Reference counting fast path: 0.5ns per operation  
- Array element access: 2-3ns
- Field access: 1-2ns

**If performance degrades:**
1. Check that functions are actually being inlined (use `zig build-lib -O ReleaseFast --verbose-cc`)
2. Verify assembly output (use `zig build-lib -O ReleaseFast -femit-asm=output.s`)
3. Profile with `perf` or similar tools
4. Consider architecture-specific optimizations if needed

### Lean ABI Stability

**Important**: Lean does NOT guarantee C ABI stability between minor versions.

- Always pin Lean version in `lean-toolchain`
- Test thoroughly after Lean updates
- Document any breaking changes in CHANGELOG.md
- CI must test against the pinned Lean version

### Multi-Threading Support

The current implementation handles MT objects by:
- Single-threaded (ST) objects: Fast path with simple increment/decrement
- Multi-threaded (MT) objects: Delegate to `lean_raw.lean_inc_ref` which uses atomics

**If Lean's MT strategy changes:**
1. Update `lean_inc_ref` in `Zig/lean.zig`
2. Ensure MT objects (`m_rc < 0`) are handled correctly
3. Test with concurrent Lean code (if possible)

### Common Pitfalls

1. **Forgetting to update tests**: Always add tests for new inline functions
2. **Not profiling**: "Fast" code should be measured, not assumed
3. **Overinlining**: Too many inlined functions can bloat binary and hurt cache
4. **Underinlining**: Missing hot-path functions can kill performance

### Review Checklist for PRs

- [ ] All public functions have doc comments
- [ ] Tests added for new functionality
- [ ] No inline tests in `Zig/lean.zig` (put in `Zig/lean_test.zig`)
- [ ] Reference counting is correct (no leaks, no double-frees)
- [ ] Error paths properly release resources
- [ ] Performance implications documented for hot-path changes
- [ ] CI passes (including Zig build test)

---

## Versioning Strategy

This project follows [Semantic Versioning 2.0.0](https://semver.org/):

### Version Format: MAJOR.MINOR.PATCH

#### MAJOR version (breaking changes)
Increment when making incompatible API changes:
- Removing or renaming public functions
- Changing function signatures (parameters, return types)
- Changing memory ownership semantics
- Breaking changes to build system integration
- Requiring a different Lean 4 major version

**Examples:**
- Removing `lean_inc_ref` function → `v2.0.0`
- Changing `boxUsize(usize) → obj_res` to `boxUsize(*const usize) → obj_res` → `v2.0.0`
- Dropping support for Lean 4.x and requiring Lean 5.x → `v2.0.0`

#### MINOR version (new features, backward compatible)
Increment when adding functionality in a backward-compatible manner:
- Adding new wrapper functions
- Adding new test coverage
- Adding documentation or examples
- Performance improvements without API changes
- Supporting new Lean runtime features (additive)
- Updating to new Lean 4.x patch version (same runtime ABI)

**Examples:**
- Adding `lean_string_utf8_next` wrapper → `v0.2.0`
- Adding comprehensive test suite → `v0.2.0`
- Adding new scalar array type support → `v0.3.0`

#### PATCH version (bug fixes)
Increment when making backward-compatible bug fixes:
- Fixing incorrect reference counting
- Fixing memory leaks
- Correcting documentation errors
- Fixing test failures
- Build system fixes that don't change usage

**Examples:**
- Fixing missing `dec_ref` in error path → `v0.2.1`
- Correcting doc comment typos → `v0.2.1`
- Fixing Zig compilation warnings → `v0.2.1`

### Release Process

1. **Update version** in `lakefile.lean`
2. **Update CHANGELOG.md** with changes for the new version
3. **Commit changes**: `git commit -am "Release v0.x.y"`
4. **Create annotated tag**: `git tag -a v0.x.y -m "Release v0.x.y"`
5. **Push tag**: `git push origin v0.x.y`
6. **Create GitHub release** with CHANGELOG excerpt

### Pre-release Versions

For testing before official release:
- Alpha: `v0.3.0-alpha.1` (early testing, API may change)
- Beta: `v0.3.0-beta.1` (feature-complete, testing for bugs)
- RC: `v0.3.0-rc.1` (release candidate, final testing)

### Deprecation Policy

When removing features:
1. Mark as deprecated in current MINOR version with clear migration path
2. Remove in next MAJOR version
3. Provide at least one MINOR version cycle between deprecation and removal

**Example:**
```zig
/// @deprecated Use `boxU64` instead. Will be removed in v2.0.0
pub inline fn legacyBoxU64(x: u64) obj_res {
    return boxU64(x);
}
```


