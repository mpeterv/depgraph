local argparse = require "argparse"
local lfs = require "lfs"
local depgraph = require "depgraph"

local version = "depgraph v" .. depgraph._VERSION

local cli = argparse("lua-depgraph", version .. ", dependency analyzer and visualizer for Lua packages.")

cli:command("list", "List all modules and external files.")
cli:command("show", "Show all information about a module or an external file.")
   :argument("name", "Module or external file name.")
cli:command("dot", "Print graph representation in .dot format.")
   :argument("title", "Title of the graph.", "depgraph")

cli:option("-m --modules", "Add files, directories, and rockspecs\nto the graph as modules.", {})
   :args("*"):argname("<path>")
cli:option("-e --ext-files", "Add files and directories to the graph\nas external files that can depend on modules.", {})
   :args("*"):argname("<path>")
cli:option("-p --prefix", "Infer module names relatively to <prefix>.")
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

   local graph, err = depgraph.make_graph(args.modules, args.ext_files, args.prefix)

   if not graph then
      io.stderr:write("Error: ", err, "\n")
      os.exit(1)
   end

   if args.list then
      print(depgraph.list(graph))
   elseif args.show then
      print(depgraph.show(graph, args.name))
   else
      print(depgraph.render(graph, args.title))
   end

   os.exit(0)
end

cli:action(main)
return cli
