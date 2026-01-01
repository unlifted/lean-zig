/-
  Lean-Zig Project Initializer

  Creates a new Lean project with Zig FFI support.
  Can be run via: lake script run init [project-name] [path]
-/

import Lean

open System IO Lean

/-- Get user input with a prompt -/
def prompt (msg : String) : IO String := do
  IO.print s!"{msg}: "
  let input ← (← IO.getStdin).getLine
  pure input.trim

/-- Check if a command exists in PATH -/
def commandExists (cmd : String) : IO Bool := do
  match (← IO.Process.run { cmd := "which", args := #[cmd] }) with
  | "" => pure false
  | _ => pure true

/-- Create a directory if it doesn't exist -/
def ensureDir (path : FilePath) : IO Unit := do
  if !(← path.pathExists) then
    FS.createDirAll path

/-- Main initialization logic -/
def initProject (projectName : String) (targetDir : FilePath) : IO Unit := do
  let fullPath := targetDir / projectName

  println! "═══════════════════════════════════════════════════════════"
  println! "  Lean-Zig Project Initializer"
  println! "═══════════════════════════════════════════════════════════"
  println! ""

  -- Check dependencies
  unless (← commandExists "lake") do
    println! "❌ ERROR: 'lake' command not found"
    println! "   Please install Lean 4 first: https://leanprover.github.io/lean4/doc/quickstart.html"
    IO.Process.exit 1

  unless (← commandExists "zig") do
    println! "⚠️  WARNING: 'zig' command not found"
    println! "   You'll need Zig 0.14.0+ to build. Install from: https://ziglang.org/download/"
    println! ""

  println! s!"Creating project: {projectName}"
  println! s!"Location: {fullPath}"
  println! ""

  -- Create project with Lake
  let createResult ← IO.Process.run {
    cmd := "lake"
    args := #["new", projectName, "exe"]
    cwd := targetDir
  }

  if createResult != "" then
    println! s!"Lake output: {createResult}"

  println! "✓ Created Lake project"

  -- Create initial lakefile with lean-zig dependency (needed for lake update)
  let initialLakefile := String.join [
    "import Lake\n",
    "open Lake DSL\n\n",
    s!"package «{projectName}» where\n",
    "  version := v!\"0.1.0\"\n\n",
    "require «lean-zig» from git\n",
    "  \"https://github.com/unlifted/lean-zig\" @ \"main\"\n"
  ]
  FS.writeFile (fullPath / "lakefile.lean") initialLakefile

  -- Download lean-zig dependency (to access template files)
  println! ""
  println! "Downloading lean-zig dependency..."

  let _ ← IO.Process.spawn {
    cmd := "lake"
    args := #["update"]
    cwd := fullPath
  } >>= fun p => p.wait

  -- Verify lean-zig downloaded
  let leanZigPath := fullPath / ".lake" / "packages" / "lean-zig"
  unless (← leanZigPath.pathExists) do
    println! "❌ ERROR: Failed to download lean-zig dependency"
    println! "   Try running 'lake update' manually in the project directory"
    IO.Process.exit 1

  println! "✓ Downloaded lean-zig"

  -- Create zig source directory
  ensureDir (fullPath / "zig")

  -- Copy and customize template files
  let templateDir := leanZigPath / "template"

  -- Copy zig/ffi.zig
  let zigTemplate ← FS.readFile (templateDir / "ffi.zig.template")
  FS.writeFile (fullPath / "zig" / "ffi.zig") zigTemplate
  println! "✓ Created zig/ffi.zig"

  -- Copy and customize lakefile.lean
  let lakefileTemplate ← FS.readFile (templateDir / "lakefile.lean.template")
  let lakefileContent := lakefileTemplate.replace "PROJECT_NAME" projectName
  FS.writeFile (fullPath / "lakefile.lean") lakefileContent
  println! "✓ Created lakefile.lean with lean-zig dependency"

  -- Copy Main.lean
  let mainTemplate ← FS.readFile (templateDir / "Main.lean.template")
  FS.writeFile (fullPath / "Main.lean") mainTemplate
  println! "✓ Created Main.lean with FFI declaration"

  -- Copy and customize build.zig template
  let buildZigTemplate ← FS.readFile (templateDir / "build.zig")
  let buildZigCustomized := buildZigTemplate.replace "zig/CHANGE_ME.zig" "zig/ffi.zig"
  FS.writeFile (fullPath / "build.zig") buildZigCustomized
  println! "✓ Copied and customized build.zig"

  -- Copy .gitignore
  let gitignoreTemplate ← FS.readFile (templateDir / "gitignore.template")
  FS.writeFile (fullPath / ".gitignore") gitignoreTemplate
  println! "✓ Created .gitignore"

  println! ""
  println! "═══════════════════════════════════════════════════════════"
  println! "  ✅ Project initialized successfully!"
  println! "═══════════════════════════════════════════════════════════"
  println! ""
  println! "Next steps:"
  println! s!"  1. cd {fullPath}"
  println! "  2. lake build"
  println! s!"  3. lake exe {projectName}"
  println! ""
  println! "Expected output:"
  println! "  Hello from Zig, World!"
  println! ""
  println! "To customize:"
  println! "  - Edit zig/ffi.zig to add your Zig functions"
  println! "  - Edit Main.lean to call your functions"
  println! "  - See https://github.com/unlifted/lean-zig/blob/main/doc/usage.md"
  println! ""

/-- Main entry point -/
def main (args : List String) : IO Unit := do
  let projectName ← match args[0]? with
    | some name => pure name
    | none => prompt "Enter project name (e.g., my-zig-project)"

  if projectName == "" then
    println! "❌ ERROR: Project name cannot be empty"
    IO.Process.exit 1

  -- Validate project name (alphanumeric, hyphens, underscores)
  if !projectName.toList.all (fun c => c.isAlphanum || c == '-' || c == '_') then
    println! "❌ ERROR: Project name must contain only letters, numbers, hyphens, and underscores"
    IO.Process.exit 1

  let targetDirStr ← match args[1]? with
    | some path => pure path
    | none => prompt s!"Enter target directory (default: ..)"

  let targetDir := if targetDirStr == "" then
    ".."  -- Sibling directory by default
  else
    targetDirStr

  let targetPath : FilePath := ⟨targetDir⟩

  -- Create target directory if it doesn't exist
  ensureDir targetPath

  -- Check if project already exists
  let projectPath := targetPath / projectName
  if (← projectPath.pathExists) then
    println! s!"❌ ERROR: Directory {projectPath} already exists"
    println! "   Please choose a different name or location"
    IO.Process.exit 1

  initProject projectName targetPath
