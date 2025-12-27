import Lake
open Lake DSL

package «strings-demo» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «strings-demo» where
  root := `Main

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
