local argparse = require "argparse"
local lfs = require "lfs"
local depgraph = require "depgraph"

local version = "depgraph v" .. depgraph._VERSION

local cli = argparse("lua-depgraph", version .. ", dependency analyzer and visualizer for Lua packages.")

cli:command("list", "List all modules and external files.")
cli:command("show", "Show all information about a module\nor an external file.")
   :argument("name", "Module or external file name.")
cli:command("cycles", "Show circular dependencies.")
   :flag("--strict", "Ignore lazy dependencies.")
cli:command("dot", "Print graph representation in .dot format.")
   :argument("title", "Title of the graph.", "depgraph")

cli:option("-m --module", "Add a file, a directory or a rockspec\nto the graph as a module.")
   :count("*"):argname("<path>"):target("modules")
cli:option("-e --ext-file", "Add a file or a directory to the graph\nas external file that can depend on modules.")
   :count("*"):argname("<path>"):target("ext_files")
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
   elseif args.cycles then
      print(depgraph.show_cycles(depgraph.get_cycles(graph, args.strict)))
   else
      print(depgraph.render(graph, args.title))
   end

   os.exit(0)
end

cli:action(main)
return cli
