import Lake
open Lake DSL

package «closures-demo» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «closures-demo» where
  root := `Main

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
