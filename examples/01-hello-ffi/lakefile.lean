import Lake
open Lake DSL

package «hello-ffi» where
  version := v!"0.1.0"

require «lean-zig» from ".." / ".."

@[default_target]
lean_exe «hello-ffi» where
  root := `Main

extern_lib libleanzig where
  name := "leanzig"
  srcDir := "zig"
  moreLinkArgs := #["-lleanrt", "-lleanshared"]
