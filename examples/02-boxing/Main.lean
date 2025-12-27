-- Example 02: Boxing - Passing scalar values between Lean and Zig

/-- Double a natural number in Zig -/
@[extern "zig_double"]
opaque zigDouble (n : Nat) : IO Nat

/-- Add two natural numbers in Zig -/
@[extern "zig_add"]
opaque zigAdd (a b : Nat) : IO Nat

/-- Multiply two floats in Zig -/
@[extern "zig_multiply_floats"]
opaque zigMultiplyFloats (a b : Float) : IO Float

def main : IO Unit := do
  -- Test doubling
  let doubled ← zigDouble 21
  IO.println s!"Double 21: {doubled}"

  -- Test addition
  let sum ← zigAdd 15 27
  IO.println s!"Add 15 + 27: {sum}"

  -- Test float multiplication
  let product ← zigMultiplyFloats 6.0 7.0
  IO.println s!"Multiply 6.0 * 7.0: {product}"
