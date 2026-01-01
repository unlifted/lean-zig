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
  -- Create binary function
  let add (x y : Nat) := x + y

  -- Inspect closure structure of unapplied function
  let (arity, fixed) ← zigClosureInfo add
  IO.println s!"Binary function info: arity={arity}, fixed={fixed}"

  -- Apply binary function
  let result ← applyBinary add 5 10
  IO.println s!"Applied: {result}"

  -- Function composition with unary functions
  let double (n : Nat) := n * 2
  let addTen (n : Nat) := n + 10
  let composed ← compose addTen double 20
  IO.println s!"Composed: {composed}"
