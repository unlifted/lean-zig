-- Example 03: Constructors - Working with algebraic data types

/-- Extract value from Option, returns 0 if None -/
@[extern "zig_option_get_or_zero"]
opaque zigOptionGetOrZero (opt : Option Nat) : IO Nat

/-- Safe division that returns Result -/
@[extern "zig_safe_divide"]
opaque zigSafeDivide (a b : Nat) : IO (Except String Nat)

def main : IO Unit := do
  -- Test Option handling
  let someValue ← zigOptionGetOrZero (some 42)
  IO.println s!"Processing Some(42): value is {someValue}"

  let noneValue ← zigOptionGetOrZero none
  IO.println s!"Processing None: no value (got {noneValue})"

  -- Test Result/Except handling
  match ← zigSafeDivide 84 2 with
  | .ok result => IO.println s!"Safe divide 84 / 2: Ok {result}"
  | .error msg => IO.println s!"Safe divide 84 / 2: Error: {msg}"

  match ← zigSafeDivide 42 0 with
  | .ok result => IO.println s!"Safe divide 42 / 0: Ok {result}"
  | .error msg => IO.println s!"Safe divide 42 / 0: Error: {msg}"
