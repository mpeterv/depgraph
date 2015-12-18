local argparse = require "argparse"
local lfs = require "lfs"
local depgraph = require "depgraph"

local version = "depgraph v" .. depgraph._VERSION

local cli = argparse("luadepgraph", version .. ", dependency analyzer and visualizer for Lua packages.")

cli:option("-m --modules", "Add files, directories or rockspecs\nto the graph as modules.")
   :args("*"):count("*"):action("concat"):argname("<path>")
cli:option("-e --ext-files", "Add files or directories to the graph\nas external files that can depend on modules.")
   :args("*"):count("*"):action("concat"):argname("<path>")
cli:option("-p --prefix", "Infer module names relatively to <prefix>.")

cli:mutex(
   cli:flag("--list", "List all modules and external files. (default)"),
   cli:option("--show", "Show all information about a module\nor an external file."):argname("<module>"),
   cli:flag("--deps", "Show external dependencies of the graph."),
   cli:flag("--cycles", "Show circular dependencies."),
   cli:option("--dot", "Print graph representation in .dot format.", "depgraph"):defmode("arg"):argname("<title>"):show_default(false)
)

cli:flag("--strict", "Ignore lazy dependencies.")
cli:option("--root", "Select only dependencies of <root> module\nor external file, recursively.")

cli:flag("-v --version", "Show version info and exit.")
   :action(function() print(version) os.exit(0) end)

local function main(args)
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
      io.stderr:write("Error: ", err, "\n")
      os.exit(1)
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
      io.stderr:write("Error: ", err, "\n")
      os.exit(1)
   end
end

cli:action(main)
return cli
