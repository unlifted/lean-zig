-- Example 09: Complete Application - CSV data processor

/-- CSV record with name and value -/
structure Record where
  name : String
  value : Nat
  deriving Repr

/-- Processing statistics -/
structure Statistics where
  count : Nat
  total : Nat
  average : Float
  min : Nat
  max : Nat
  deriving Repr

/-- Parse CSV line into record -/
@[extern "zig_parse_csv_line"]
opaque zigParseCsvLine (line : String) : IO Record

/-- Filter records by minimum value -/
@[extern "zig_filter_records"]
opaque zigFilterRecords (records : Array Record) (minValue : Nat) : IO (Array Record)

/-- Compute statistics from records -/
@[extern "zig_compute_statistics"]
opaque zigComputeStatistics (records : Array Record) : IO Statistics

/-- Find top N records by value -/
@[extern "zig_top_records"]
opaque zigTopRecords (records : Array Record) (n : Nat) : IO (Array Record)

def sampleData : List String := [
  "Alice,80",
  "Bob,20",
  "Charlie,10",
  "David,40",
  "Invalid,xyz"  -- Will fail parsing
]

def main : IO Unit := do
  IO.println "Processing CSV data..."
  IO.println ""

  -- Parse all lines (collecting successes and failures)
  let mut records : Array Record := #[]
  let mut validCount := 0
  let mut invalidCount := 0

  for line in sampleData do
    try
      let record ← zigParseCsvLine line
      records := records.push record
      validCount := validCount + 1
    catch _ =>
      invalidCount := invalidCount + 1

  IO.println s!"Input records: {sampleData.length}"
  IO.println s!"Valid records: {validCount}"
  IO.println s!"Invalid records: {invalidCount}"
  IO.println ""

  -- Filter records (value >= 20)
  let filtered ← zigFilterRecords records 20
  
  -- Compute statistics
  let stats ← zigComputeStatistics filtered
  IO.println "Statistics:"
  IO.println s!"  Total: {stats.total}"
  IO.println s!"  Average: {stats.average}"
  IO.println s!"  Min: {stats.min}"
  IO.println s!"  Max: {stats.max}"
  IO.println ""

  -- Get top 2 records
  let top ← zigTopRecords records 2
  IO.println "Top records:"
  for record in top do
    IO.println s!"  {record.name}: {record.value}"
