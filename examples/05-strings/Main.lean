-- Example 05: Strings - Working with text

/-- Create a greeting string in Zig -/
@[extern "zig_create_greeting"]
opaque zigCreateGreeting : IO String

/-- Get string length (bytes and chars) -/
@[extern "zig_string_length"]
opaque zigStringLength (s : @& String) : IO (Nat × Nat)

/-- Reverse a string byte-wise -/
@[extern "zig_reverse_string"]
opaque zigReverseString (s : String) : IO String

/-- Compare two strings -/
@[extern "zig_strings_equal"]
opaque zigStringsEqual (s1 s2 : @& String) : IO Bool

/-- Lexicographic comparison -/
@[extern "zig_string_less_than"]
opaque zigStringLessThan (s1 s2 : @& String) : IO Bool

def main : IO Unit := do
  -- Create string
  let greeting ← zigCreateGreeting
  IO.println s!"Greeted: {greeting}"

  -- Get length
  let (bytes, chars) ← zigStringLength greeting
  IO.println s!"Length: {bytes} bytes, {chars} chars"

  -- Reverse
  let reversed ← zigReverseString greeting
  IO.println s!"Reversed: {reversed}"

  -- Compare strings
  let equal ← zigStringsEqual greeting reversed
  IO.println s!"Strings equal: {equal}"

  -- Lexicographic comparison
  let lt ← zigStringLessThan "apple" "banana"
  IO.println s!"'apple' < 'banana': {lt}"
