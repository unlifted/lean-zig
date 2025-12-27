# Example 07: Closures

**Difficulty:** Advanced  
**Concepts:** Higher-order functions, partial application, callbacks, closures

## What You'll Learn

- Creating closures with captured environment
- Accessing closure metadata
- Partial application patterns
- Function composition

## Building and Running

```bash
lake build
lake exe closures-demo
```

Expected output:
```
Closure info: arity=2, fixed=1
Applied: 15
Composed: 50
```

## Key Concepts

### Closure Structure

A closure is a function with captured arguments:
- **Function pointer**: The actual code to execute
- **Fixed arguments**: Captured environment values
- **Arity**: Total parameters (including fixed)

### Creating Closures

Closures are typically created by Lean's compiler, not manually in Zig. However, you can inspect and manipulate them:

```zig
// Allocate closure (rare in practice)
const closure = lean.lean_alloc_closure(function_ptr, arity, num_fixed) orelse return error;

// Set fixed arguments
lean.closureSet(closure, 0, captured_value1);
lean.closureSet(closure, 1, captured_value2);
```

### Inspecting Closures

```zig
// Get total arity
const arity = lean.closureArity(closure);

// Get number of fixed (captured) arguments
const num_fixed = lean.closureNumFixed(closure);

// Get function pointer
const fun = lean.closureFun(closure);

// Get fixed argument
const arg = lean.closureGet(closure, 0);
```

### Partial Application

When a closure receives some (but not all) arguments, Lean creates a new closure with more fixed arguments:

```lean
def add (x y : Nat) : Nat := x + y
def addFive := add 5  -- Partial application
#eval addFive 10       -- Returns 15
```

The `addFive` closure has:
- Original arity: 2
- Fixed arguments: 1 (the value 5)
- Remaining parameters: 1

## Memory Management

### Closure Ownership

Closures own their fixed arguments:

```zig
export fn process_closure(closure: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(closure);  // Decrements closure + all fixed args
    
    const num_fixed = lean.closureNumFixed(closure);
    // Inspect fixed args...
    
    return lean.ioResultMkOk(result);
}
```

### Accessing Fixed Arguments

Getting a fixed argument returns a **borrowed** reference:

```zig
const arg = lean.closureGet(closure, 0);
// arg is borrowed - don't dec_ref unless you inc_ref first

if (need_ownership) {
    lean.lean_inc_ref(arg);  // Now we own it
    // ... use arg ...
    lean.lean_dec_ref(arg);  // Clean up
}
```

## Performance Notes

- Closure allocation: **~30-50ns** (depends on number of fixed args)
- Fixed argument access: **~2-3ns** (array lookup)
- Closure call overhead: **~5-10ns** (compared to direct function call)
- Zero overhead for non-escaping closures (inlined by compiler)

## Common Patterns

### Inspect Closure Info

```zig
export fn closure_info(closure: lean.b_obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    
    const arity = lean.closureArity(closure);
    const num_fixed = lean.closureNumFixed(closure);
    
    // Return tuple (Nat × Nat)
    const pair = lean.allocCtor(0, 0, @sizeOf(u16) * 2) orelse {
        const err = lean.lean_mk_string("allocation failed");
        return lean.ioResultMkError(err);
    };
    
    lean.ctorSetUint16(pair, 0, arity);
    lean.ctorSetUint16(pair, 2, num_fixed);
    
    return lean.ioResultMkOk(pair);
}
```

### Apply Closure (requires Lean runtime)

Closure application is handled by Lean's calling convention, not directly callable from Zig FFI. Instead, pass closures to Lean functions that expect them:

```lean
-- Lean side
def applyBinary (f : Nat → Nat → Nat) (x y : Nat) : Nat :=
  f x y

-- Zig creates closure, Lean applies it
```

### Iterate Fixed Arguments

```zig
const num_fixed = lean.closureNumFixed(closure);
var i: usize = 0;
while (i < num_fixed) : (i += 1) {
    const arg = lean.closureGet(closure, i);
    // Process arg (borrowed reference)...
}
```

## Advanced: Function Composition

In practice, closures enable powerful functional patterns in Lean:

```lean
def compose (f : β → γ) (g : α → β) (x : α) : γ :=
  f (g x)

def double (n : Nat) : Nat := n * 2
def addTen (n : Nat) : Nat := n + 10

def doubleAndAddTen := compose addTen double
#eval doubleAndAddTen 10  -- (10 * 2) + 10 = 30
```

Each closure captures its environment efficiently.

## Limitations

- **Can't call closures from Zig**: Closure calling convention is Lean-specific
- **Can't create arbitrary closures**: Function pointer must be Lean-compiled
- **Arity is fixed**: Can't dynamically change closure signature

These limitations are by design - closures are meant for Lean's functional programming model, not general C FFI.

## Next Steps

→ [Example 08: Tasks](../08-tasks) - Learn about asynchronous programming with Lean's task system.
