import Lake
open Lake DSL

package «05-strings» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «05-strings» where
  root := `Main

extern_lib libleanzig pkg := do
  let name := nameToStaticLib "leanzig"
  let oFile := pkg.buildDir / name

  -- Build with Zig
  proc {
    cmd := "zig"
    args := #["build"]
    cwd := pkg.dir
  }

  -- Copy built library to Lake's expected location
  let srcFile := pkg.dir / "zig-out" / "lib" / name
  IO.FS.writeBinFile oFile (← IO.FS.readBinFile srcFile)

  return Job.pure oFile
