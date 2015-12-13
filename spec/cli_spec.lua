local lua = "lua"
local i = -1

while arg[i] do
   lua = arg[i]
   i = i - 1
end

if package.loaded["luacov.runner"] then
   lua = lua .. " -lluacov"
   local runner = require "luacov.runner"
   setup(runner.pause)
   teardown(runner.resume)
end

local function run(cmd)
   local handler = io.popen(("%s bin/lua-depgraph.lua %s 2>&1"):format(lua, cmd))
   local output = handler:read("*a")
   handler:close()
   return output
end

local function dedent(src)
   local indentation = src:match("^(%s*)")
   local lines = {}

   for line in src:gmatch("[^\n]+") do
      table.insert(lines, line:sub(#indentation + 1))
   end

   return table.concat(lines, "\n")
end

describe("cli", function()
   describe("list", function()
      it("lists", function()
         assert.equal(dedent([[
            1 module, 1 external file.
            Modules:
               rock in spec/samples/rock.lua
            External files:
               spec/samples/bin/rock.lua in spec/samples/bin/rock.lua
         ]]), run("-m spec/samples/rock.lua -e spec/samples/bin -p spec/samples list"))

         assert.equal(dedent([[
            1 module, 0 external files.
            Modules:
               rock in spec/samples/rock.lua
         ]]), run("-m spec/samples/rock.lua -p spec/samples list"))

         assert.equal(dedent([[
            0 modules, 1 external file.
            External files:
               spec/samples/bin/rock.lua in spec/samples/bin/rock.lua
         ]]), run("-e spec/samples/bin/rock.lua list"))

         assert.equal(dedent([[
            3 modules, 1 external file.
            Modules:
               rock in spec/samples/rock.lua
               rock.bar in spec/samples/rock/bar.lua
               rock.foo in spec/samples/rock/foo.lua
            External files:
               rock in spec/samples/bin/rock.lua
         ]]), run("-m spec/samples/rock-1-1.rockspec list"))

         assert.equal(dedent([[
            7 modules, 1 external file.
            Modules:
               depgraph in src/depgraph/init.lua
               depgraph.cli in src/depgraph/cli.lua
               depgraph.luacheck.lexer in src/depgraph/luacheck/lexer.lua
               depgraph.luacheck.linearize in src/depgraph/luacheck/linearize.lua
               depgraph.luacheck.parser in src/depgraph/luacheck/parser.lua
               depgraph.luacheck.utils in src/depgraph/luacheck/utils.lua
               depgraph.scan in src/depgraph/scan.lua
            External files:
               lua-depgraph in bin/lua-depgraph.lua
         ]]), run("list"))
      end)

      it("handles errors", function()
         assert.equal(dedent([[
            Error: Could not open missing.lua: No such file or directory
         ]]), run("-m missing.lua list"))
      end)
   end)
   
   describe("show", function()
      it("shows", function()
         assert.equal(dedent([[
            Module rock in spec/samples/rock.lua
            Dependencies:
               dep.* on line 2, column 7 (protected)
               rock.bar on line 9, column 10 (conditional, protected)
               rock.foo (2 times)
                  on line 1, column 1
                  on line 3, column 8 (protected)
               that on line 8, column 4 (conditional)
               this on line 6, column 4 (conditional)
            Depended on by:
               rock.bar on line 1, column 1
               rock.foo on line 2, column 4 (lazy)
               rock in spec/samples/bin/rock.lua on line 1, column 1
         ]]), run("-m spec/samples/rock-1-1.rockspec show rock"))

         assert.equal(dedent([[
            Module rock.foo in spec/samples/rock/foo.lua
            Dependencies:
               rock on line 2, column 4 (lazy)
               rock.* on line 3, column 10 (lazy, protected)
            Depended on by:
               rock (2 times)
                  on line 1, column 1
                  on line 3, column 8 (protected)
               rock.foo as rock.* on line 3, column 10 (lazy, protected)
         ]]), run("-m spec/samples/rock-1-1.rockspec show rock.foo"))

         assert.equal(dedent([[
            External file rock in spec/samples/bin/rock.lua
            Dependencies:
               rock on line 1, column 1
         ]]), run("-m spec/samples/rock-1-1.rockspec show spec/samples/bin/rock.lua"))
      end)

      it("prints error on missing module", function()
         assert.equal(dedent([[
            Error: rock.baz is not a module or an external file.
         ]]), run("-m spec/samples/rock-1-1.rockspec show rock.baz"))
      end)
   end)

   describe("deps", function()
      it("shows external deps", function()
         assert.equal(dedent([[
            3 external dependencies.
            dep.* required by:
               rock on line 2, column 7 (protected)
            that required by:
               rock on line 8, column 4 (conditional)
            this required by:
               rock on line 6, column 4 (conditional)
         ]]), run("-m spec/samples/rock-1-1.rockspec deps"))
      end)
   end)

   describe("cycles", function()
      it("shows cycles", function()
         assert.equal(dedent([[
            2 circular dependencies found.
            The shortest circular dependency has length 2:
               rock depends on rock.bar on line 9, column 10 (conditional, protected)
               rock.bar depends on rock on line 1, column 1
            The next shortest circular dependency has length 2:
               rock depends on rock.foo (2 times)
                  on line 1, column 1
                  on line 3, column 8 (protected)
               rock.foo depends on rock on line 2, column 4 (lazy)
         ]]), run("-m spec/samples/rock-1-1.rockspec cycles"))

         assert.equal(dedent([[
            No circular dependencies found.
         ]]), run("-m spec/samples/rock.lua -p spec/samples cycles"))
      end)

      it("shows cycles without lazy deps with --strict", function()
         assert.equal(dedent([[
            1 circular dependency found.
            The shortest circular dependency has length 2:
               rock depends on rock.bar on line 9, column 10 (conditional, protected)
               rock.bar depends on rock on line 1, column 1
         ]]), run("-m spec/samples/rock-1-1.rockspec cycles --strict"))
      end)
   end)

   describe("dot", function()
      it("exports graph into .dot format", function()
         assert.equal(dedent([[
            digraph "depgraph" {
            1 [color = blue label = "rock"]
            2 [color = black label = "rock"]
            1 -> 2 [color = black style = solid]
            3 [color = yellow label = "dep.*"]
            2 -> 3 [color = green style = solid]
            4 [color = black label = "rock.bar"]
            2 -> 4 [color = green style = dashed]
            5 [color = black label = "rock.foo"]
            2 -> 5 [color = black style = solid]
            6 [color = yellow label = "that"]
            2 -> 6 [color = black style = dashed]
            7 [color = yellow label = "this"]
            2 -> 7 [color = black style = dashed]
            4 -> 2 [color = black style = solid]
            5 -> 2 [color = black style = dotted]
            8 [color = yellow label = "rock.*"]
            5 -> 8 [color = green style = dotted]
            }
         ]]), run("-m spec/samples/rock-1-1.rockspec dot"))
      end)

      it("allows setting graph title", function()
         assert.equal(dedent([[
            digraph "hey" {
            1 [color = blue label = "rock"]
            2 [color = black label = "rock"]
            1 -> 2 [color = black style = solid]
            3 [color = yellow label = "dep.*"]
            2 -> 3 [color = green style = solid]
            4 [color = black label = "rock.bar"]
            2 -> 4 [color = green style = dashed]
            5 [color = black label = "rock.foo"]
            2 -> 5 [color = black style = solid]
            6 [color = yellow label = "that"]
            2 -> 6 [color = black style = dashed]
            7 [color = yellow label = "this"]
            2 -> 7 [color = black style = dashed]
            4 -> 2 [color = black style = solid]
            5 -> 2 [color = black style = dotted]
            8 [color = yellow label = "rock.*"]
            5 -> 8 [color = green style = dotted]
            }
         ]]), run("-m spec/samples/rock-1-1.rockspec dot hey"))
      end)

      it("exports a subtree using --root", function()
         assert.equal(dedent([[
            digraph "depgraph" {
            1 [color = black label = "rock.foo"]
            2 [color = black label = "rock"]
            3 [color = yellow label = "dep.*"]
            2 -> 3 [color = green style = solid]
            4 [color = black label = "rock.bar"]
            4 -> 2 [color = black style = solid]
            2 -> 4 [color = green style = dashed]
            2 -> 1 [color = black style = solid]
            5 [color = yellow label = "that"]
            2 -> 5 [color = black style = dashed]
            6 [color = yellow label = "this"]
            2 -> 6 [color = black style = dashed]
            1 -> 2 [color = black style = dotted]
            7 [color = yellow label = "rock.*"]
            1 -> 7 [color = green style = dotted]
            }
         ]]), run("-m spec/samples/rock-1-1.rockspec dot --root rock.foo"))
      end)
   end)
end)