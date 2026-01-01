#!/usr/bin/env bash
# Initialize a new Lean project with Zig FFI support
# Usage: ./scripts/init-project.sh <project-name> [directory]

set -e

PROJECT_NAME="${1:-my-zig-ffi}"
PROJECT_DIR="${2:-./$PROJECT_NAME}"

echo "═══════════════════════════════════════════════════════════"
echo "  Lean-Zig Project Initializer"
echo "═══════════════════════════════════════════════════════════"
echo

# Check if Lake is available
if ! command -v lake &> /dev/null; then
    echo "❌ ERROR: 'lake' command not found"
    echo "   Please install Lean 4 first: https://leanprover.github.io/lean4/doc/quickstart.html"
    exit 1
fi

# Check if Zig is available
if ! command -v zig &> /dev/null; then
    echo "⚠️  WARNING: 'zig' command not found"
    echo "   You'll need Zig 0.14.0+ to build. Install from: https://ziglang.org/download/"
    echo
fi

echo "Creating project: $PROJECT_NAME"
echo "Location: $PROJECT_DIR"
echo

# Create project with Lake
cd "$(dirname "$PROJECT_DIR")"
lake new "$PROJECT_NAME" exe

cd "$PROJECT_NAME"

echo "✓ Created Lake project"

# Create zig source directory
mkdir -p zig

# Create sample Zig FFI code
cat > zig/ffi.zig << 'EOF'
const lean = @import("lean");

/// Sample FFI function that returns a greeting
export fn zig_greet(name: lean.obj_arg, world: lean.obj_arg) lean.obj_res {
    _ = world;
    defer lean.lean_dec_ref(name);
    
    // Get the name string from Lean
    const name_cstr = lean.stringCstr(name);
    const name_len = lean.stringSize(name) - 1; // Exclude null terminator
    
    // Create greeting
    const greeting_prefix = "Hello from Zig, ";
    const greeting_suffix = "!";
    
    // Allocate buffer for full greeting
    const total_len = greeting_prefix.len + name_len + greeting_suffix.len;
    var buffer: [256]u8 = undefined;
    
    if (total_len >= buffer.len) {
        const err = lean.lean_mk_string_from_bytes("name too long", 13);
        return lean.ioResultMkError(err);
    }
    
    // Build greeting
    @memcpy(buffer[0..greeting_prefix.len], greeting_prefix);
    @memcpy(buffer[greeting_prefix.len..][0..name_len], name_cstr[0..name_len]);
    @memcpy(buffer[greeting_prefix.len + name_len..][0..greeting_suffix.len], greeting_suffix);
    
    const result = lean.lean_mk_string_from_bytes(&buffer, total_len);
    return lean.ioResultMkOk(result);
}
EOF

echo "✓ Created zig/ffi.zig"

# Update lakefile to include lean-zig dependency
cat > lakefile.lean << 'EOF'
import Lake
open Lake DSL

package «PROJECT_NAME_PLACEHOLDER» where
  version := v!"0.1.0"
  leanOptions := #[
    ⟨`pp.unicode.fun, true⟩,
    ⟨`pp.proofs.withType, false⟩
  ]

require «lean-zig» from git
  "https://github.com/unlifted/lean-zig" @ "main"

extern_lib libleanzig pkg := do
  let name := nameToStaticLib "leanzig"
  let oFile := pkg.buildDir / name
  
  proc {
    cmd := "zig"
    args := #["build"]
    cwd := pkg.dir
  }
  
  let srcFile := pkg.dir / "zig-out" / "lib" / name
  IO.FS.writeBinFile oFile (← IO.FS.readBinFile srcFile)
  
  return Job.pure oFile

@[default_target]
lean_exe «PROJECT_NAME_PLACEHOLDER» where
  root := `Main
  supportInterpreter := true
  extern_lib := #[`libleanzig]
EOF

# Replace placeholder with actual project name (portable across GNU/BSD sed)
sed "s/PROJECT_NAME_PLACEHOLDER/$PROJECT_NAME/g" lakefile.lean > lakefile.lean.tmp
mv lakefile.lean.tmp lakefile.lean

echo "✓ Updated lakefile.lean with lean-zig dependency"

# Create sample Main.lean
cat > Main.lean << 'EOF'
-- FFI function declaration
@[extern "zig_greet"]
opaque zigGreet (name : String) : IO String

def main : IO Unit := do
  let greeting ← zigGreet "World"
  IO.println greeting
EOF

echo "✓ Created Main.lean with FFI declaration"

# Download lean-zig and copy template
echo
echo "Downloading lean-zig dependency..."
lake build 2>&1 | grep -E "(Cloning|Downloaded|Package)" || true

if [ ! -f ".lake/packages/lean-zig/template/build.zig" ]; then
    echo "❌ ERROR: Failed to download lean-zig dependency"
    echo "   Try running 'lake build' manually"
    exit 1
fi

echo "✓ Downloaded lean-zig"

# Copy and customize build.zig template
cp .lake/packages/lean-zig/template/build.zig ./

# Customize the template to point to our zig/ffi.zig (portable, no sed -i)
tmp_build_zig="$(mktemp build.zig.XXXXXX)"
sed 's|zig/CHANGE_ME\.zig|zig/ffi.zig|g' build.zig > "$tmp_build_zig"
mv "$tmp_build_zig" build.zig

echo "✓ Copied and customized build.zig"

# Create .gitignore
cat > .gitignore << 'EOF'
# Lean
.lake/
build/
lake-packages/

# Zig
zig-out/
zig-cache/
.zig-cache/

# Editor
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db
EOF

echo "✓ Created .gitignore"

echo
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ Project initialized successfully!"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Next steps:"
echo "  1. cd $PROJECT_NAME"
echo "  2. lake build"
echo "  3. lake exe $PROJECT_NAME"
echo
echo "Expected output:"
echo "  Hello from Zig, World!"
echo
echo "To customize:"
echo "  - Edit zig/ffi.zig to add your Zig functions"
echo "  - Edit Main.lean to call your functions"
echo "  - See https://github.com/unlifted/lean-zig/blob/main/doc/usage.md"
echo
