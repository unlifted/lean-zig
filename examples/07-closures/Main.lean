-- Example 07: Closures - Higher-order functions

/-- Inspect closure metadata -/
@[extern "zig_closure_info"]
opaque zigClosureInfo (f : @& (Nat → Nat → Nat)) : IO (Nat × Nat)

/-- Apply a binary function (Lean applies, Zig can't directly) -/
def applyBinary (f : Nat → Nat → Nat) (x y : Nat) : IO Nat :=
  pure (f x y)

/-- Compose two unary functions -/
def compose (f : Nat → Nat) (g : Nat → Nat) (x : Nat) : IO Nat :=
  pure (f (g x))

def main : IO Unit := do
  -- Create partially applied closure
  let add (x y : Nat) := x + y
  let addFive := add 5

  -- Inspect closure structure
  let (arity, fixed) ← zigClosureInfo addFive
  IO.println s!"Closure info: arity={arity}, fixed={fixed}"

  -- Apply closure
  let result ← applyBinary addFive 10 -- Fixed arg is 5, new arg is 10
  IO.println s!"Applied: {result}"

  -- Function composition
  let double (n : Nat) := n * 2
  let addTen (n : Nat) := n + 10
  let composed ← compose addTen double 20
  IO.println s!"Composed: {composed}"
