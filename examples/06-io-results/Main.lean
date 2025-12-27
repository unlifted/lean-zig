-- Example 06: IO Results - Error handling

/-- Safe division with error handling -/
@[extern "zig_safe_divide"]
opaque zigSafeDivide (a b : Nat) : IO Nat

/-- Parse number from string -/
@[extern "zig_parse_number"]
opaque zigParseNumber (s : String) : IO Nat

/-- Chain operations (may fail at any step) -/
@[extern "zig_chain_operations"]
opaque zigChainOperations (n : Nat) : IO Nat

def main : IO Unit := do
  -- Safe division
  try
    let result ← zigSafeDivide 10 2
    IO.println s!"Divide 10 / 2 = ok: {result}"
  catch e =>
    IO.println s!"Divide 10 / 2 = error: {e}"

  try
    let result ← zigSafeDivide 10 0
    IO.println s!"Divide 10 / 0 = ok: {result}"
  catch e =>
    IO.println s!"Divide 10 / 0 = error: {e}"

  -- Parse numbers
  try
    let result ← zigParseNumber "42"
    IO.println s!"Parse '42' = ok: {result}"
  catch e =>
    IO.println s!"Parse '42' = error: {e}"

  try
    let result ← zigParseNumber "xyz"
    IO.println s!"Parse 'xyz' = ok: {result}"
  catch e =>
    IO.println s!"Parse 'xyz' = error: {e}"

  -- Chained operations
  try
    let result ← zigChainOperations 10
    IO.println s!"Chain success: {result}"
  catch e =>
    IO.println s!"Chain failure: {e}"

  try
    let result ← zigChainOperations 0
    IO.println s!"Chain success: {result}"
  catch e =>
    IO.println s!"Chain failure: {e}"
