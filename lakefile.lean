import Lake
open Lake DSL
open System (FilePath)

package «lean-zig» where
  version := v!"0.3.1"
  description := "Zig bindings for the Lean 4 runtime (Hybrid JIT Strategy)"
  keywords := #["zig", "ffi", "low-level"]

@[default_target]
lean_lib «LeanZig» where
  -- No Lean code yet, but required for package structure

-- Build target that invokes Zig build system to generate bindings and library
target zig_build pkg : Unit := do
  let zigCmd := "zig"
  let args := #["build"]
  let proc ← IO.Process.spawn {
    cmd := zigCmd
    args := args
    cwd := pkg.dir
  }
  let exitCode ← proc.wait
  if exitCode != 0 then
    logError "Zig build failed!"
  return Job.pure ()

-- Export the path to the Zig source file (for legacy compatibility)
target lean_zig_lib pkg : FilePath := do
  -- Ensure zig build runs first
  let _ ← fetch <| pkg.target ``zig_build
  return Job.pure (pkg.dir / "Zig" / "lean.zig")

script test do
  -- Run zig build test target (uses hybrid bindings)
  let zigCmd := "zig"
  let args := #["build", "test"]
  let child ← IO.Process.spawn {
    cmd := zigCmd
    args := args
  }
  let exitCode ← child.wait
  if exitCode != 0 then
    return 1
  return 0
