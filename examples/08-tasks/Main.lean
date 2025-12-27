-- Example 08: Tasks - Asynchronous programming

/-- Validate task API is available -/
@[extern "zig_validate_task_api"]
opaque zigValidateTaskApi : IO Unit

/-- Example: Parallel computation (Lean native) -/
def parallelSum (n : Nat) : IO Nat := do
  -- Spawn two tasks computing partial sums
  let task1 ← Task.spawn (fun () => List.range (n / 2) |>.foldl (· + ·) 0)
  let task2 ← Task.spawn (fun () => List.range (n / 2) |>.foldl (· + ·) 0)
  
  -- Wait for both results
  let sum1 ← task1.get
  let sum2 ← task2.get
  
  pure (sum1 + sum2)

def main : IO Unit := do
  -- Validate API
  zigValidateTaskApi
  IO.println "Task API validated"
  
  -- Note about task execution
  IO.println "Note: Full task execution requires Lean IO runtime initialization"
  IO.println "See lean-zig test suite for task API validation examples"
  
  -- Demonstrate Lean-native task usage
  -- let result ← parallelSum 100
  -- IO.println s!"Parallel sum: {result}"
