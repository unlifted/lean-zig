-- Example 01: Hello FFI - Basic foreign function call

/-- External Zig function that returns a magic number -/
@[extern "zig_get_magic_number"]
opaque zigGetMagicNumber : IO Nat

def main : IO Unit := do
  let num ← zigGetMagicNumber
  IO.println s!"Magic number from Zig: {num}"
