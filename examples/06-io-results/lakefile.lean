import Lake
open Lake DSL

package «io-results-demo» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «io-results-demo» where
  root := `Main

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
