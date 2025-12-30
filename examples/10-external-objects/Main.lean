-- Example 10: External Objects - File I/O with native resource management
--
-- This example demonstrates:
-- - Wrapping native file handles as Lean objects
-- - Automatic cleanup via finalizers
-- - Type-safe access to native data
-- - Proper error handling with IO results

-- Initialize the external class (must be called before using FileHandle)
@[extern "initFileClass"]
opaque initFileClass : IO Unit

-- Opaque file handle type (wraps native Zig file descriptor)
opaque FileHandle : Type

-- Open a file and wrap it as an external object
@[extern "openFile"]
opaque openFile (path : String) : IO FileHandle

-- Read n bytes from the file
@[extern "readBytes"]
opaque readBytes (file : FileHandle) (n : USize) : IO String

-- Write string to the file
@[extern "writeBytes"]
opaque writeBytes (file : FileHandle) (data : String) : IO Unit

-- Get file statistics (bytes read/written)
@[extern "getFileStats"]
opaque getFileStats (file : @& FileHandle) : IO (USize × USize)

-- Close file explicitly (optional - happens automatically when refcount reaches 0)
@[extern "closeFile"]
opaque closeFile (file : FileHandle) : IO Unit

def main : IO Unit := do
  -- Initialize the file class (registers finalizer)
  initFileClass

  IO.println "=== External Objects Example: File I/O ==="
  IO.println ""

  -- Create a test file
  IO.println "1. Creating test file..."
  let writeFile ← openFile "test-output.txt"
  writeBytes writeFile "Hello from Lean via Zig FFI!\n"
  writeBytes writeFile "External objects provide automatic resource management.\n"
  writeBytes writeFile "The file will be closed automatically when no longer needed.\n"

  let (_, bytesWritten) ← getFileStats writeFile
  IO.println s!"   Wrote {bytesWritten} bytes"

  -- File automatically closed when writeFile goes out of scope

  IO.println ""
  IO.println "2. Reading test file..."
  let readFile ← openFile "test-output.txt"
  let content ← readBytes readFile 1024

  let (bytesRead, _) ← getFileStats readFile
  IO.println s!"   Read {bytesRead} bytes"
  IO.println ""
  IO.println "Content:"
  IO.println content

  -- Demonstrate explicit close (optional)
  closeFile readFile
  IO.println ""
  IO.println "3. File closed explicitly"

  IO.println ""
  IO.println "✓ External object finalizer will clean up resources automatically!"
