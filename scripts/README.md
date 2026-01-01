# Project Initialization Scripts

This directory contains helper scripts for working with lean-zig.

## InitProject.lean (Recommended)

**Native Lean script** for automated project initialization. Creates a new Lean project with Zig FFI support.

### Usage

```bash
# From within the lean-zig directory:
lake script run init [project-name] [target-directory]

# Interactive mode (prompts for name and location):
lake script run init

# Specify project name only (creates in parent directory):
lake script run init my-zig-project

# Specify both name and location:
lake script run init my-project ~/code
```

**Default behavior**: Creates project as a **sibling** directory (in `..`) rather than a subdirectory.

### Interactive Prompts

If you don't provide command-line arguments, the script will prompt for:
- **Project name**: Alphanumeric, hyphens, and underscores allowed
- **Target directory**: Where to create the project (default: `..`)

### What It Does

1. Validates dependencies (checks for `lake` and `zig`)
2. Creates a new Lean project with Lake (`lake new`)
3. Creates minimal lakefile with lean-zig dependency
4. Downloads lean-zig to access template files (`lake update`)
5. Copies template files from `template/` directory:
   - `lakefile.lean.template` → Customizes with project name
   - `Main.lean.template` → Sample FFI declaration
   - `ffi.zig.template` → Sample Zig implementation
   - `build.zig` → Customizes ZIG_FFI_SOURCE path
   - `gitignore.template` → Git ignore configuration
6. All templates are under source control for easy maintenance

### Sample Output

The generated project includes a working "Hello from Zig" example that demonstrates:
- String passing between Lean and Zig
- Proper reference counting with `defer`
- IO result handling
- String manipulation with buffer management

### Requirements

- Lean 4.25.0+ (with Lake)
- Zig 0.14.0+ (optional at init time, required for building)

### After Initialization

```bash
cd ../my-zig-project  # Note: sibling directory by default
lake build
lake exe my-zig-project
# Expected: Hello from Zig, World!
```

---

## init-project.sh (Legacy)

**Bash version** of the initialization script. Kept for compatibility.

### Usage

```bash
./scripts/init-project.sh <project-name> [directory]
```

**Examples:**
```bash
# Create project in current directory
./scripts/init-project.sh my-zig-project

# Create project in specific location
./scripts/init-project.sh my-project ~/code/my-project
```

### What It Does

1. Creates a new Lean project with Lake
2. Adds lean-zig as a dependency
3. Creates `zig/ffi.zig` with a sample FFI function
4. Configures `lakefile.lean` with `extern_lib` target
5. Creates `Main.lean` with FFI function declaration
6. Downloads lean-zig and copies customized `build.zig` template
7. Sets up `.gitignore`

### Sample Output

The generated project includes a working "Hello from Zig" example that demonstrates:
- String passing between Lean and Zig
- Proper reference counting with `defer`
- IO result handling
- Basic string manipulation in Zig

### Requirements

- Lean 4.25.0+ (with Lake)
- Zig 0.14.0+ (optional at init time, required for building)

### After Initialization

```bash
cd <project-name>
lake build
lake exe <project-name>
```

Expected output:
```
Hello from Zig, World!
```

See [Usage Guide](../doc/usage.md) for next steps.
