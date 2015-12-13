local scan = require "depgraph.scan"

local function dedent(src)
   local indentation = src:match("^(%s*)")
   local lines = {}

   for line in src:gmatch("[^\n]+") do
      table.insert(lines, line:sub(#indentation + 1))
   end

   return table.concat(lines, "\n")
end

describe("scan", function()
   it("returns nil, error on syntax error", function()
      local requires, err = scan("If you're happy and you know it, syntax error!")
      assert.is_nil(requires)
      assert.equals("syntax error on line 1, column 4: expected '=' near 'you'", err)
   end)

   it("returns empty array on empty source", function()
      assert.same({}, scan(""))
   end)

   it("detects require with literal argument", function()
      assert.same({{line = 1, column = 1, name = "foo"}}, scan("require 'foo'; unrelated 'bar'"))
   end)

   it("detects require with literal prefix argument", function()
      assert.same({{line = 1, column = 1, name = "foo.*"}}, scan("require('foo.'..x); unrelated 'bar'"))
      assert.same({{line = 1, column = 1, name = "*"}}, scan("require('foo'..x); unrelated 'bar'"))
      assert.same({{line = 1, column = 1, name = "foo.*"}}, scan("require('foo.bar'..x); unrelated 'bar'"))
      assert.same({{line = 1, column = 1, name = "foo.bar.*"}}, scan("require('foo.bar.'..x); unrelated 'bar'"))
   end)

   it("detects require with any argument", function()
      assert.same({{line = 1, column = 1, name = "*"}}, scan("require(x); unrelated 'bar'"))
   end)

   it("detects require caled using _G and _ENV", function()
      assert.same({{line = 1, column = 1, name = "foo"}}, scan("_G.require 'foo'"))
      assert.same({{line = 1, column = 1, name = "foo"}}, scan("_ENV.require 'foo'"))
   end)

   it("detects multiple requires", function()
      assert.same({
         {line = 1, column = 1, name = "foo"},
         {line = 2, column = 1, name = "bar"}
      }, scan("require 'foo'\nrequire 'bar'"))
   end)

   it("detects requires protected using pcall", function()
      assert.same({
         {line = 1, column = 23, name = "lib", protected = true}
      }, scan("local ok, lib = pcall(require, 'lib')"))
   end)

   it("detects requires protected using xpcall", function()
      assert.same({
         {line = 1, column = 24, name = "lib", protected = true}
      }, scan("local ok, lib = xpcall(require, err_handler, 'lib')"))
   end)

   it("detects requires protected using _G.pcall, _ENV.pcall, _G.xpcall, _ENV.xpcall", function()
      assert.same({
         {line = 1, column = 22, name = "gplib", protected = true},
         {line = 2, column = 24, name = "eplib", protected = true},
         {line = 3, column = 24, name = "gxplib", protected = true},
         {line = 4, column = 26, name = "explib", protected = true}
      }, scan(dedent([[
         ok, gplib = _G.pcall(_G.require, "gplib")
         ok, eplib = _ENV.pcall(require, "eplib")
         ok, gxplib = _G.xpcall(require, "gxplib")
         ok, explib = _ENV.xpcall(require, "explib")
      ]])))
   end)

   it("detects protected requires in functions passed to pcall and xpcall", function()
      assert.same({
         {line = 2, column = 4, name = "foo", protected = true},
         {line = 3, column = 4, name = "bar", protected = true}
      }, scan(dedent([[
         pcall(function()
            require "foo"
            require "bar"
         end)
      ]])))
   end)

   it("detects protected requires in functions passed to pcall and xpcall using locals", function()
      assert.same({
         {line = 2, column = 16, name = "lib", protected = true}
      }, scan(dedent([[
         local function get_lib()
            local lib = require "lib"
            assert(semver.version(lib._VERSION) > "1.0.0")
            monkey_patch(lib)
            return lib
         end

         local ok, lib = pcall(get_lib)
      ]])))
   end)

   it("detects conditional requires", function()
      assert.same({
         {line = 2, column = 4, name = "foo", conditional = true},
         {line = 3, column = 14, name = "bar", protected = true, conditional = true},
         {line = 4, column = 4, name = "bar.baz", conditional = true}
      }, scan(dedent([[
         if foo then
            require "foo"
         elseif pcall(require, "bar") then
            require "bar.baz"
         end
      ]])))
   end)

   it("detects conditional requires with local function as argument to pcall", function()
      assert.same({
         {line = 2, column = 18, name = "lib", protected = true, conditional = true}
      }, scan(dedent([[
         local function get_lib()
            return assert(require("lib").subtable)
         end

         if why_not() then
            local ok, lib = pcall(get_lib)
         end
      ]])))
   end)

   it("detects lazy requires within functions", function()
      assert.same({
         {line = 2, column = 16, name = "lib", lazy = true}
      }, scan(dedent([[
         local function f()
            local lib = require "lib"
         end
      ]])))
   end)

   it("detects lazy conditional requires", function()
      assert.same({
         {line = 3, column = 19, name = "lib", lazy = true, conditional = true}
      }, scan(dedent([[
         function t.f(x)
            if x then
               local lib = require "lib"
            end
         end
      ]])))
   end)
end)
