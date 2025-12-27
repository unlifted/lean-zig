import Lake
open Lake DSL

package «complete-app» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «complete-app» where
  root := `Main

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
