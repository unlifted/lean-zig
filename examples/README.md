# lean-zig Examples

Progressive **educational templates** demonstrating Lean 4 and Zig interoperability patterns.

## Important: Examples Are Educational Templates

These examples are **documentation and templates**, not standalone buildable projects. They demonstrate:
- FFI patterns and best practices
- Memory management strategies  
- API usage examples
- Performance considerations

**All concepts are tested and validated** in the lean-zig test suite (117 passing tests). See [BUILDING.md](BUILDING.md) for details on using these examples.

## Quick Validation

```bash
# From lean-zig root directory
./validate-examples.sh  # Runs test suite + checks documentation
```

This validates that all 117 tests pass, covering all example concepts.

## Learning Path

Study these examples in order to understand concepts progressively:

| Example | Difficulty | Key Concepts | Time |
|---------|-----------|--------------|------|
| [01-hello-ffi](01-hello-ffi/) | ⭐ Beginner | Basic FFI, IO monad, boxing | 10min |
| [02-boxing](02-boxing/) | ⭐ Beginner | Scalar types, tagged pointers, performance | 15min |
| [03-constructors](03-constructors/) | ⭐⭐ Intermediate | Algebraic types, memory layout, refcounting | 20min |
| [04-arrays](04-arrays/) | ⭐⭐ Intermediate | Collections, iteration, ownership | 20min |
| [05-strings](05-strings/) | ⭐⭐ Intermediate | Text processing, UTF-8, comparisons | 20min |
| [06-io-results](06-io-results/) | ⭐⭐ Intermediate | Error handling, result types, propagation | 20min |
| [07-closures](07-closures/) | ⭐⭐⭐ Advanced | Higher-order functions, partial application | 25min |
| [08-tasks](08-tasks/) | ⭐⭐⭐ Advanced | Async programming, concurrency | 25min |
| [09-complete-app](09-complete-app/) | ⭐⭐⭐ Advanced | Integration, real-world patterns | 45min |

**Total Learning Time:** ~3-4 hours

## Prerequisites

- Lean 4 installed (via `elan`)
- Zig 0.15.2 or later
- Basic understanding of Lean syntax
- Basic understanding of Zig syntax
- Familiarity with systems programming concepts

## How to Use These Examples

### 1. Read for Concepts

Each example teaches specific concepts:
- Read README.md for explanations
- Study Main.lean for Lean FFI patterns
- Examine zig/*.zig for Zig implementations
- Note memory management and performance tips

### 2. Verify Concepts Work

All concepts are validated in the test suite:

```bash
# From lean-zig root
zig build test  # Runs 117 tests covering all concepts
```

### 3. Use as Templates

Copy example structure into your project:
```bash
cp -r examples/01-hello-ffi my-project
# Then set up proper build (see BUILDING.md)
```

## Concept Matrix

What each example teaches:

|  | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 |
|--|----|----|----|----|----|----|----|----|---|
| **FFI Basics** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Boxing/Unboxing** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Tagged Pointers** |  | ✅ |  |  |  |  |  |  |  |
| **Constructors** |  |  | ✅ |  |  |  |  |  | ✅ |
| **Pattern Matching** |  |  | ✅ |  |  | ✅ |  |  | ✅ |
| **Arrays** |  |  |  | ✅ |  |  |  |  | ✅ |
| **Strings** |  |  |  |  | ✅ |  |  |  | ✅ |
| **Error Handling** |  |  | ✅ |  |  | ✅ |  |  | ✅ |
| **Memory Management** |  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |  | ✅ |
| **Closures** |  |  |  |  |  |  | ✅ |  |  |
| **Tasks** |  |  |  |  |  |  |  | ✅ |  |
| **Integration** |  |  |  |  |  |  |  |  | ✅ |

## Example Descriptions

### 01: Hello FFI
**First Steps** - Call a simple Zig function from Lean and get a result. Introduces:
- `@[extern]` declarations
- `opaque` types
- IO monad basics
- `boxUsize` for returning scalars
- `ioResultMkOk` for success

Perfect starting point to verify your setup works.

### 02: Boxing
**Scalar Types** - Work with numbers and understand performance. Introduces:
- Tagged pointer optimization (~1-2ns)
- Boxing/unboxing different types (u32, u64, f32, f64)
- Multiple function parameters
- Float heap allocation (~10-20ns)

Critical for understanding lean-zig's zero-cost abstractions.

### 03: Constructors
**Algebraic Types** - Handle Option, Result, and custom types. Introduces:
- Constructor tags (0, 1, 2, ...)
- Object and scalar fields
- `allocCtor` for creating values
- `ctorGet` / `ctorSet` for field access
- Reference counting with `defer`

Foundation for working with Lean's expressive type system.

### 04: Arrays
**Collections** - Store and process sequences of data. Introduces:
- `allocArray` / `mkArrayWithSize`
- Element access with `arrayGet` / `arrayUget`
- Iteration patterns
- Filter and map operations
- Memory ownership with arrays

Essential for data processing tasks.

### 05: Strings
**Text Processing** - Work with UTF-8 encoded strings. Introduces:
- `lean_mk_string` / `lean_mk_string_from_bytes`
- String metadata (`stringSize`, `stringLen`)
- String comparison (`stringEq`, `stringLt`)
- C string interop
- UTF-8 considerations

Critical for parsing, formatting, and I/O.

### 06: IO Results
**Error Handling** - Handle success and failure gracefully. Introduces:
- `ioResultMkOk` / `ioResultMkError`
- Result checking (`ioResultIsOk`)
- Value extraction (`ioResultGetValue`)
- Error propagation patterns
- Try-catch style code

Necessary for robust applications.

### 07: Closures
**Higher-Order Functions** - Work with first-class functions. Introduces:
- Closure structure (function + captured environment)
- `closureArity` / `closureNumFixed`
- Fixed argument access
- Partial application concepts
- Functional composition

Enables functional programming patterns.

### 08: Tasks
**Asynchronous Programming** - Understand concurrent computation. Introduces:
- Task spawning (`taskSpawn`)
- Task composition (`taskMap`, `taskBind`)
- Blocking waits (`lean_task_get_own`)
- Why tasks require full runtime
- Parallel computation patterns

Important for performance-critical applications.

### 09: Complete Application
**Integration** - Build a real CSV data processor. Demonstrates:
- Multi-stage pipeline (parse → validate → process → output)
- Error accumulation
- Performance optimization patterns
- Comprehensive memory management
- Real-world code structure

Ties everything together in a practical example.

## Building from Scratch

Want to create your own Lean+Zig project? Use these examples as templates:

### 1. Copy Example Structure

```bash
cp -r examples/01-hello-ffi my-project
cd my-project
```

### 2. Modify lakefile.lean

```lean
package «my-project» where
  version := v!"0.1.0"

require «lean-zig» from git
  "https://github.com/efvincent/lean-zig" @ "main"

@[default_target]
lean_exe «my-app» where
  root := `Main

extern_lib libmyzig where
  name := "myzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
```

### 3. Write Your Code

- **Main.lean**: Lean code with `@[extern]` declarations
- **zig/*.zig**: Zig implementations

### 4. Build and Run

```bash
lake build
lake exe my-app
```

## Common Pitfalls

### 1. Forgetting Reference Counting

```zig
// ❌ WRONG: Leaks memory
export fn bad(obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    // Forgot defer lean.lean_dec_ref(obj);
    return lean.ioResultMkOk(result);
}

// ✅ CORRECT
export fn good(obj: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(obj);  // Always clean up owned args
    return lean.ioResultMkOk(result);
}
```

### 2. Unboxing Without Checking

```zig
// ❌ WRONG: Crashes on heap objects
const value = lean.unboxUsize(obj);

// ✅ CORRECT: Check first
if (lean.isScalar(obj)) {
    const value = lean.unboxUsize(obj);
} else {
    // Handle error
}
```

### 3. Using After Dec_ref

```zig
// ❌ WRONG: Use after free
lean.lean_dec_ref(obj);
const tag = lean.objectTag(obj);  // Undefined behavior!

// ✅ CORRECT: Use defer at end of scope
defer lean.lean_dec_ref(obj);
const tag = lean.objectTag(obj);
// obj is still valid here
```

## Performance Tips

1. **Use tagged pointers when possible** - 1-2ns vs 10-20ns for heap allocation
2. **Prefer unchecked access in hot loops** - `arrayUget` over `arrayGet`
3. **Check exclusivity before mutation** - `isExclusive` enables in-place updates
4. **Batch reference counting** - Group operations to minimize inc/dec_ref calls
5. **Profile first** - Measure before optimizing

See [performance guide](../doc/design.md#performance) for details.

## Getting Help

- **API Documentation**: [doc/api.md](../doc/api.md)
- **Usage Guide**: [doc/usage.md](../doc/usage.md)
- **Design Document**: [doc/design.md](../doc/design.md)
- **Test Suite**: [Zig/tests/](../Zig/tests/) for more patterns
- **Issues**: https://github.com/efvincent/lean-zig/issues

## Contributing Examples

Have an idea for a new example? We'd love to see it!

1. Follow the existing structure (README, lakefile, Main.lean, zig/*.zig)
2. Include comprehensive documentation
3. Add to this README's concept matrix
4. Submit a PR

Good example ideas:
- File I/O operations
- Network communication
- Custom data structures
- Performance benchmarking
- Integration with C libraries

## Next Steps

1. **Complete the learning path** - Work through examples 01-09 in order
2. **Build your own project** - Use examples as templates
3. **Read the documentation** - Deep dive into lean-zig internals
4. **Join the community** - Share your projects and ask questions

Happy coding! 🚀
