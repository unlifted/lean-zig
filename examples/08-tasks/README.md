# Example 08: Tasks

**Difficulty:** Advanced  
**Concepts:** Asynchronous programming, task spawning, concurrency, futures

## What You'll Learn

- Understanding Lean's task system
- Task API structure and limitations
- Why task testing requires full Lean runtime
- Async programming concepts

## Building and Running

```bash
lake build
lake exe tasks-demo
```

Expected output:
```
Task API validated
Note: Full task execution requires Lean IO runtime initialization
See lean-zig test suite for task API validation examples
```

## Key Concepts

### Task System Overview

Lean provides a task-based concurrency model managed by a thread pool. Tasks represent asynchronous computations that can run in parallel.

### Task API Functions

```zig
// Spawn a task with default options (priority=0, async=true)
const task = lean.taskSpawn(closure) orelse return error;

// Map a function over task result
const mapped = lean.taskMap(task, transform_fn) orelse return error;

// Monadic bind for task sequencing
const chained = lean.taskBind(task, next_fn) orelse return error;

// Wait for task completion (blocking)
const result = lean.lean_task_get_own(task);
```

### Why Task Examples Are Limited

**Tasks require full Lean IO runtime initialization**, which includes:
- Thread pool setup
- Task scheduler initialization  
- Runtime state management
- Signal handling

This initialization happens automatically when running Lean programs but **not** when calling FFI functions from standalone Zig tests.

Therefore:
- ✅ **API validation**: Can test function signatures exist
- ❌ **Execution testing**: Can't actually spawn/run tasks from Zig tests
- ✅ **Integration testing**: Works in full Lean programs

## Task API Reference

### Core Functions

| Function | Purpose | Blocking |
|----------|---------|----------|
| `taskSpawn(closure)` | Spawn async task | No |
| `taskMap(task, f)` | Transform result | No |
| `taskBind(task, f)` | Sequence tasks | No |
| `lean_task_get_own(task)` | Wait for result | Yes |
| `lean_task_get(task)` | Wait (borrowed) | Yes |

### Advanced Functions

```zig
// Core with full control
lean.lean_task_spawn_core(closure, priority, async_mode);
lean.lean_task_map_core(task, f, priority, async_mode);
lean.lean_task_bind_core(task, f, priority, async_mode);
```

**Parameters:**
- `priority`: `0` = normal, higher = more important
- `async_mode`: `0` = wait before exit, `1` = background

## Memory Management

Tasks follow standard reference counting:

```zig
// Spawning takes ownership of closure
const task = lean.taskSpawn(closure);
// closure is consumed, don't dec_ref

// Getting result takes ownership of task
const result = lean.lean_task_get_own(task);
defer lean.lean_dec_ref(result);
// task is consumed, don't dec_ref
```

## Performance Notes

- Task spawn: **~100-500ns** (thread pool overhead)
- Task switching: **~1-10μs** depending on workload
- Minimum task duration for benefit: **~10-100μs**
- Very short tasks (<1μs) better done synchronously

## Common Patterns

### Parallel Map

```lean
-- Lean side (tasks work naturally in IO)
def parallelMap (f : α → β) (xs : Array α) : IO (Array β) := do
  let tasks ← xs.mapM (fun x => Task.spawn (fun () => f x))
  tasks.mapM Task.get
```

### Task Chaining

```lean
def chainedComputation : IO Nat := do
  let task1 ← Task.spawn (fun () => expensiveOp1 ())
  let task2 ← task1.map (fun x => expensiveOp2 x)
  let task3 ← task2.map (fun y => expensiveOp3 y)
  task3.get
```

### Error Handling with Tasks

```lean
def safeAsyncComputation : IO (Except String Nat) := do
  try
    let task ← Task.spawn (fun () => 
      if condition then
        throw (IO.userError "failed")
      else
        pure 42
    )
    let result ← task.get
    pure (Except.ok result)
  catch e =>
    pure (Except.error e.toString)
```

## Testing Tasks

### In Lean Programs (Recommended)

```lean
-- Full runtime available, tasks work normally
def testTasks : IO Unit := do
  let task ← Task.spawn (fun () => 42)
  let result ← task.get
  IO.println s!"Task result: {result}"
```

### In lean-zig Tests (API Only)

The lean-zig test suite validates task API existence:

```zig
test "task API exists" {
    // Validate function signatures compile
    _ = lean.taskSpawn;
    _ = lean.taskMap;
    _ = lean.taskBind;
    _ = lean.lean_task_get_own;
}
```

**We don't execute tasks** because:
1. No Lean runtime initialization in Zig tests
2. Thread pool not available
3. Would cause runtime crashes

## Real-World Task Usage

Tasks shine for:
- **Parallel computations**: Independent calculations on multicore CPUs
- **Async I/O**: Non-blocking file/network operations
- **Background work**: Long-running operations that shouldn't block UI
- **Pipeline parallelism**: Producer-consumer chains

Not suitable for:
- Very short operations (<1μs)
- Operations requiring sequential ordering
- Code that needs deterministic execution order

## Example: Async in Production

```lean
-- Parallel HTTP requests
def fetchMultipleUrls (urls : Array String) : IO (Array String) := do
  let tasks ← urls.mapM (fun url =>
    Task.spawn (fun () => fetchUrl url)
  )
  tasks.mapM Task.get

-- Background computation with progress
def backgroundProcess (data : Data) : IO Result := do
  let task ← Task.spawn (fun () => expensiveProcessing data)
  
  -- Can do other work while task runs
  IO.println "Processing in background..."
  
  -- Wait for completion
  task.get
```

## Limitations

- **No task cancellation**: Once spawned, tasks run to completion
- **No task priority adjustment**: Priority set at spawn time
- **No task introspection**: Can't query task status (pending/running/done)
- **Blocking waits only**: No async/await syntax (use task composition instead)

## Next Steps

→ [Example 09: Complete App](../09-complete-app) - See all concepts integrated in a real-world application.
