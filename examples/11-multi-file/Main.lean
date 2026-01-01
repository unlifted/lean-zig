-- Multi-file Zig FFI Example
-- Demonstrates organizing Zig code across multiple files

-- FFI declarations
@[extern "zig_array_sum"]
opaque zigArraySum (arr : Array Nat) : IO Nat

@[extern "zig_array_average"]
opaque zigArrayAverage (arr : Array Nat) : IO Nat

@[extern "zig_array_max"]
opaque zigArrayMax (arr : Array Nat) : IO Nat

-- Stats is a struct with 3 USize fields: sum, average, max
structure Stats where
  sum : Nat
  average : Nat
  max : Nat
  deriving Repr

-- FFI to get all stats at once (returns constructor with scalar fields)
@[extern "zig_array_stats"]
opaque zigArrayStats (arr : Array Nat) : IO Stats

def main : IO Unit := do
  let numbers := #[10, 20, 30, 40, 50]

  IO.println s!"Numbers: {numbers}"
  IO.println ""

  -- Individual operations
  let sum ← zigArraySum numbers
  IO.println s!"Sum: {sum}"

  let avg ← zigArrayAverage numbers
  IO.println s!"Average: {avg}"

  let maximum ← zigArrayMax numbers
  IO.println s!"Max: {maximum}"

  IO.println ""

  -- All at once
  let stats ← zigArrayStats numbers
  IO.println s!"Stats (computed together): sum={stats.sum}, average={stats.average}, max={stats.max}"

  IO.println ""
  IO.println "✓ Multi-file Zig FFI working!"
  IO.println "  - ffi.zig exports FFI functions"
  IO.println "  - helpers.zig provides conversion utilities"
  IO.println "  - math.zig provides computation functions"
