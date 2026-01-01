-- Example 08: Tasks - Asynchronous programming

/-- Validate task API is available -/
@[extern "zig_validate_task_api"]
opaque zigValidateTaskApi : IO Unit

def main : IO Unit := do
  -- Validate API
  zigValidateTaskApi
  IO.println "Task API validated"

  IO.println ""
  IO.println "Note: Full task execution requires Lean IO runtime initialization"
  IO.println "This example validates that the task API functions are available"
  IO.println "See lean-zig test suite for comprehensive task API validation"
  IO.println ""
  IO.println "Available task operations:"
  IO.println "  - taskSpawn: Spawn async computation"
  IO.println "  - taskMap: Map function over task result"
  IO.println "  - taskBind: Monadic bind for task sequencing"
  IO.println "  - lean_task_get/lean_task_get_own: Wait for completion"
