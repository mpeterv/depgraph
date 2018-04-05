local argparse = require "argparse"
local lfs = require "lfs"
local depgraph = require "depgraph"
local utils = require "depgraph.luacheck.utils"

local function fail(err)
   io.stderr:write("Error: ", err, "\n")
   os.exit(1)
end

local function main(argv)
   local version = "depgraph v" .. depgraph._VERSION

   local parser = argparse("luadepgraph", version .. ", dependency analyzer and visualizer for Lua packages.")

   parser:option("-m --modules", [[Add files, directories or rockspecs
to the graph as modules.]])
      :args("*"):count("*"):action("concat"):argname("<path>")
   parser:option("-e --ext-files", [[Add files or directories to the graph
as external files that can depend on modules.]])
      :args("*"):count("*"):action("concat"):argname("<path>")
   parser:option("-p --prefix", "Infer module names relatively to <prefix>.")

   parser:mutex(
      parser:flag("--list", "List all modules and external files. (default)"),
      parser:option("--show", [[Show all information about a module
or an external file.]])
         :argname("<module>"),
      parser:flag("--deps", "Show external dependencies of the graph."),
      parser:flag("--cycles", "Show circular dependencies."),
      parser:option("--dot", "Print graph representation in .dot format.", "depgraph")
         :defmode("arg"):argname("<title>"):show_default(false)
   )

   parser:flag("--strict", "Ignore lazy dependencies.")
   parser:option("--root", [[Select only dependencies of <root> module
or external file, recursively.]])

   parser:flag("-v --version", "Show version info and exit.")
      :action(function() print(version) os.exit(0) end)

   local args = parser:parse(argv)

   if #args.modules == 0 and #args.ext_files == 0 then
      for path in lfs.dir(".") do
         if path:match("%.rockspec$") and lfs.attributes(path, "mode") == "file" then
            table.insert(args.modules, path)
         end
      end

      if #args.modules > 1 then
         args.modules = {}
      end
   end

   local graph, err = depgraph.make_graph(args.modules, args.ext_files, args.prefix, args.strict, args.root)

   if not graph then
      fail(err)
   end

   local output

   if args.show then
      output, err = depgraph.show(graph, args.show)
   elseif args.deps then
      output = depgraph.deps(graph)
   elseif args.cycles then
      output = depgraph.show_cycles(depgraph.get_cycles(graph))
   elseif args.dot then
      output = depgraph.render(graph, args.dot)
   else
      output = depgraph.list(graph)
   end

   if output then
      print(output)
      os.exit(0)
   else
      fail(err)
   end
end

local function pmain(argv)
   local _, error_wrapper = utils.try(main, argv)

   local err = error_wrapper.err
   local traceback = error_wrapper.traceback

   if type(err) == "string" and err:match("interrupted!$") then
      fail("Interrupted")
   else
      fail(("Luadepgraph %s bug (please report at https://github.com/mpeterv/depgraph/issues):\n%s\n%s"):format(
         depgraph._VERSION, err, traceback))
   end
end

return pmain
