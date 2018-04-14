package = "depgraph"
version = "scm-1"
source = {
   url = "git://github.com/mpeterv/depgraph"
}
description = {
   summary = "Dependency analyzer and visualizer for Lua packages",
   detailed = [[
depgraph is a command-line tool for building, analyzing, and visualizing
graph of dependencies between Lua modules within a package.

depgraph scans Lua files for all usages of 'require' and can distinguish
normal, lazy (from within a function), conditional, and protected calls.

depgraph command-line tool named 'luadepgraph' can show gathered data in
textual form or export it in .dot format, which can be turned into an
image using GraphViz. It can also detect circular and external dependencies.
]],
   homepage = "https://github.com/mpeterv/depgraph",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "argparse >= 0.6.0",
   "luafilesystem >= 1.6.3"
}
build = {
   type = "builtin",
   modules = {
      ["depgraph"] = "src/depgraph/init.lua",
      ["depgraph.scan"] = "src/depgraph/scan.lua",
      ["depgraph.cli"] = "src/depgraph/cli.lua",
      ["depgraph.luacheck.lexer"] = "src/depgraph/luacheck/lexer.lua",
      ["depgraph.luacheck.parser"] = "src/depgraph/luacheck/parser.lua",
      ["depgraph.luacheck.linearize"] = "src/depgraph/luacheck/linearize.lua",
      ["depgraph.luacheck.utils"] = "src/depgraph/luacheck/utils.lua"
   },
   install = {
      bin = {
         ["luadepgraph"] = "bin/luadepgraph.lua"
      }
   }
}
