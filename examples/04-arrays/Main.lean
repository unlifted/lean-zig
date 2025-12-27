-- Example 04: Arrays - Working with collections

/-- Create an array [1,2,3,4,5] in Zig -/
@[extern "zig_create_array"]
opaque zigCreateArray : IO (Array Nat)

/-- Sum all elements in an array -/
@[extern "zig_sum_array"]
opaque zigSumArray (arr : Array Nat) : IO Nat

/-- Double each element in an array -/
@[extern "zig_map_double"]
opaque zigMapDouble (arr : Array Nat) : IO (Array Nat)

/-- Filter for even numbers only -/
@[extern "zig_filter_evens"]
opaque zigFilterEvens (arr : Array Nat) : IO (Array Nat)

def main : IO Unit := do
  -- Create array
  let arr ← zigCreateArray
  IO.println s!"Created array: {arr}"

  -- Sum array
  let sum ← zigSumArray arr
  IO.println s!"Sum of array: {sum}"

  -- Map: double each element
  let doubled ← zigMapDouble arr
  IO.println s!"Doubled array: {doubled}"

  -- Filter: keep only evens
  let evens ← zigFilterEvens arr
  IO.println s!"Evens only: {evens}"
