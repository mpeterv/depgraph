local lfs = require "lfs"
local scan = require "depgraph.scan"

local depgraph = {}

depgraph._VERSION = "0.0.1"

local function normalize_io_error(name, err)
   if err:sub(1, #name + 2) == (name .. ": ") then
      err = err:sub(#name + 3)
   end

   return err
end

local bom = "\239\187\191"

local function read_file(name)
   local handler, err = io.open(name)

   if not handler then
      return nil, ("Could not open %s: %s"):format(name, normalize_io_error(name, err))
   end

   local contents
   contents, err = handler:read("*a")

   if not contents then
      return nil, ("Could not read %s: %s"):format(name, normalize_io_error(name, err))
   end

   handler:close()

   if contents:sub(1, bom:len()) == bom then
      contents = contents:sub(bom:len() + 1)
   end

   return contents
end

local function error_handler(err)
   return tostring(err) .. "\n" .. debug.traceback("", 2):sub(2)
end

local function load_file(name, chunk_name)
   local src, err = read_file(name)

   if not src then
      return nil, err
   end

   local env = {}
   local func

   -- luacheck: push
   -- luacheck: compat
   if _VERSION == "Lua 5.1" then
      func, err = loadstring(src, chunk_name)

      if func then
         setfenv(func, env)
      end
   else
      func, err = load(src, chunk_name, "t", env)
   end
   -- luacheck: pop

   if not func then
      return nil, ("Could not compile %s: %s"):format(name, err)
   end

   local ok
   ok, err = xpcall(func, error_handler)

   if not ok then
      return nil, ("Could not load %s: %s"):format(name, err)
   end

   return env
end

local function name_comparator(t1, t2)
   return t1.name < t2.name
end

-- Group array of require calls as returned by depgraph.scan into
-- array of dependencies.
-- Each dependency has same fields as a require call except for location info.
-- Additionally 'requires' key maps to array of require calls sharing the module name.
local function group_by_module(requires)
   local deps = {}
   local name_to_dep = {}

   for _, require_table in ipairs(requires) do
      local dep = name_to_dep[require_table.name]

      if not dep then
         dep = {
            name = require_table.name,
            requires = {},
            protected = true,
            lazy = true
         }
         table.insert(deps, dep)
         name_to_dep[require_table.name] = dep
      end

      table.insert(dep.requires, require_table)

      if not require_table.lazy then
         dep.lazy = nil
      end

      if not require_table.protected then
         dep.protected = nil
      end
   end

   table.sort(deps, name_comparator)
   return deps
end

local function make_file_object(name, file)
   local src, err = read_file(file)

   if not src then
      return nil, err
   end

   local requires
   requires, err = scan(src)

   if not requires then
      return nil, err
   end

   return {
      name = name,
      file = file,
      deps = group_by_module(requires)
   }
end

local function add_ext_file(graph, file, name)
   local obj, err = make_file_object(type(name) == "string" and name or file, file)
   table.insert(graph.ext_files, obj)
   return obj, err
end

local function add_module(graph, file, name)
   local obj, err = make_file_object(name, file)
   table.insert(graph.modules, obj)
   graph.modules[name] = obj
   return obj, err
end

local function add_file(graph, file_name, prefix_dir)
   local module_name = file_name

   if prefix_dir then
      if file_name:sub(1, #prefix_dir) ~= prefix_dir then
         return nil, ("File name '%s' does not start with '%s'"):format(file_name, prefix_dir)
      end

      module_name = file_name:sub(#prefix_dir + 2)
   end

   module_name = module_name:gsub("^%.[/\\]", ""):gsub("%.lua$", "")

   if module_name:find("%.") then
      return nil, ("File name '%s' contains too many dots"):format(file_name)
   elseif module_name:find("%*") then
      return nil, ("File name '%s' contains an asterisk"):format(file_name)
   end

   module_name = module_name:gsub("[/\\]", "."):gsub("%.init$", "")
   return add_module(graph, file_name, module_name)
end

local function add_lua_files_from_table(graph, t, ext)
   if type(t) == "table" then
      for module_name, file in pairs(t) do
         if type(file) == "string" and (file:match("%.lua$") or ext and loadfile(file)) then
            local ok, err

            if ext or type(module_name) ~= "string" then
               ok, err = add_ext_file(graph, file, module_name)
            else
               ok, err = add_module(graph, file, module_name)
            end

            if not ok then
               return nil, err
            end
         end
      end
   end

   return true
end

local function add_rockspec(graph, rockspec_name)
   local rockspec = load_file(rockspec_name, "rockspec")

   if type(rockspec) ~= "table" or type(rockspec.build) ~= "table" then
      return nil, ("Rockspec %s does not contain build table"):format(rockspec_name)
   end

   local ok, err = true

   if rockspec.build.type == "builtin" then
      ok, err = add_lua_files_from_table(graph, rockspec.build.modules)
   end

   if ok and type(rockspec.build.install) == "table" then
      ok, err = add_lua_files_from_table(graph, rockspec.build.install.lua)

      if ok then
         ok, err = add_lua_files_from_table(graph, rockspec.build.install.bin, true)
      end
   end

   return ok, err
end

local dir_sep = package.config:sub(1, 1)

local function add_lua_files_from_dir(graph, dir, prefix_dir, ext)
   if not dir:match("[/\\]$") then
      dir = dir .. dir_sep
   end

   for path in lfs.dir(dir) do
      if path ~= "." and path ~= ".." then
         local full_path = dir .. path

         local ok, err

         if lfs.attributes(full_path, "mode") == "directory" then
            ok, err = add_lua_files_from_dir(graph, full_path, prefix_dir, ext)
         elseif lfs.attributes(full_path, "mode") == "file" and (path:match("%.lua$") or ext and loadfile(full_path)) then
            if ext then
               ok, err = add_ext_file(graph, full_path)
            else
               ok, err = add_file(graph, full_path, prefix_dir)
            end
         end

         if not ok and err then
            return nil, err
         end
      end
   end

   return true
end

-- Scan dependencies in modules (passed as an array of file, directory, and rockspec paths)
-- and external files (passed as an array of file and directory paths).
-- Module names will be inferred relatively to given prefix or current directory.
-- Return graph table or nil, error message.
function depgraph.make_graph(files, ext_files, prefix_dir)
   if prefix_dir then
      prefix_dir = prefix_dir:match("^(.-)[/\\]*$")
   end

   local graph = {
      modules = {},
      ext_files = {}
   }

   local ok, err

   for _, file in ipairs(files) do
      if lfs.attributes(file, "mode") == "directory" then
         ok, err = add_lua_files_from_dir(graph, file, prefix_dir)
      elseif file:match("%.rockspec$") then
         ok, err = add_rockspec(graph, file)
      else
         ok, err = add_file(graph, file, prefix_dir)
      end

      if not ok then
         return nil, err
      end
   end

   for _, file in ipairs(ext_files) do
      if lfs.attributes(file, "mode") == "directory" then
         ok, err = add_lua_files_from_dir(graph, file, prefix_dir, true)
      else
         ok, err = add_ext_file(graph, file)
      end

      if not ok then
         return nil, err
      end
   end

   table.sort(graph.modules, name_comparator)
   table.sort(graph.ext_files, name_comparator)
   return graph
end

-- Return listing of modules and external files in the graph as a string.
function depgraph.list(graph)
   local lines = {}

   local function add_lines(file_objects)
      for _, file_object in ipairs(file_objects) do
         table.insert(lines, ("   %s in %s"):format(file_object.name, file_object.file))
      end
   end

   if #graph.modules > 0 then
      table.insert(lines, "Modules:")
      add_lines(graph.modules)
   end

   if #graph.ext_files > 0 then
      table.insert(lines, "External files:")
      add_lines(graph.ext_files)
   end

   return table.concat(lines, "\n")
end

local function require_to_string(req)
   local res = ("on line %d, column %d"):format(req.line, req.column)

   if req.lazy then
      if req.protected then
         return res .. " (lazy, protected)"
      else
         return res .. " (lazy)"
      end
   elseif req.protected then
      return res .. " (protected)"
   else
      return res
   end
end

local function add_deps(lines, deps, bases)
   for i, dep in ipairs(deps) do
      if #dep.requires == 1 then
         table.insert(lines, ("   %s %s"):format(bases and bases[i] or dep.name, require_to_string(dep.requires[1])))
      else
         table.insert(lines, ("   %s (%d times)"):format(bases and bases[i] or dep.name, #dep.requires))

         for _, req in ipairs(dep.requires) do
            table.insert(lines, "      " .. require_to_string(req))
         end
      end
   end
end

-- Return all information about a module or an external file as a string.
function depgraph.show(graph, name)
   local lines = {}

   local file_object = graph.modules[name]

   if not file_object then
      for _, ext_file in ipairs(graph.ext_files) do
         if ext_file.name == name then
            file_object = ext_file
            break
         end
      end
   end

   if not file_object then
      return name .. " is not a module or an external file."
   end

   table.insert(lines, ("%s %s in %s"):format(
      graph.modules[name] and "Module" or "External file", file_object.name, file_object.file))

   if #file_object.deps > 0 then
      table.insert(lines, "Dependencies:")
      add_deps(lines, file_object.deps)
   end

   if graph.modules[name] then
      local matching_deps = {}
      local bases = {}

      for _, file_list in ipairs({graph.modules, graph.ext_files}) do
         for _, dependant in ipairs(file_list) do
            for _, dep in ipairs(dependant.deps) do
               if dep.name == name or (dep.name:match("%.%*$") and dep.name:sub(1, -2) == name:sub(1, #dep.name - 1)) then
                  table.insert(matching_deps, dep)
                  local base = dependant.name

                  if file_list == graph.ext_files then
                     base = base .. " in " .. dependant.file
                  end

                  if dep.name ~= name then
                     base = base .. " as " .. dep.name
                  end

                  table.insert(bases, base)
               end
            end
         end
      end

      if #matching_deps > 0 then
         table.insert(lines, "Depended on by:")
         add_deps(lines, matching_deps, bases)
      end
   end

   return table.concat(lines, "\n")
end

-- Return array of modules forming the shortest cycle or nil.
-- Each module in the array depends on the next one, and the last one depends on the first one.
function depgraph.get_cycle(graph)
   local modules = graph.modules
   local name_to_index = {}

   for i, m in ipairs(modules) do
      name_to_index[m.name] = i
   end

   local best_dist
   local best_root
   local best_parents

   for _, root_module in ipairs(modules) do
      -- Simple path-tracking breadth-first search for the root node.
      local parents = {}
      local queue = {root_module}
      local i, j = 1, 1
      local dists = {}

      while i <= j do
         local current_module = queue[i]
         i = i + 1

         for _, dep in ipairs(current_module.deps) do
            local dep_module = modules[dep.name]

            if dep_module and not dists[dep_module] then
               dists[dep_module] = (dists[current_module] or 0) + 1
               parents[dep_module] = current_module
               j = j + 1
               queue[j] = dep_module
            end
         end
      end

      if parents[root_module] then
         if not best_dist or dists[root_module] < best_dist then
            best_dist = dists[root_module]
            best_root = root_module
            best_parents = parents
         end
      end
   end

   if best_dist then
      local cycle = {}
      local m = best_root

      repeat
         m = best_parents[m]
         table.insert(cycle, 1, m)
      until m == best_root

      return cycle
   end
end

-- Return string representation of a cycle.
function depgraph.show_cycle(cycle)
   if not cycle then
      return "No circular dependencies found."
   end

   local lines = {("Shortest circular dependency has length %d:"):format(#cycle)}
   local deps = {}
   local bases = {}

   for i, current_module in ipairs(cycle) do
      local next_module = cycle[i + 1] or cycle[1]

      for _, dep in ipairs(current_module.deps) do
         if dep.name == next_module.name then
            table.insert(deps, dep)
            table.insert(bases, ("%s depends on %s"):format(current_module.name, next_module.name))
         end
      end
   end

   add_deps(lines, deps, bases)
   return table.concat(lines, "\n")
end

local normal_module_color = "black"
local external_file_color = "blue"
local external_module_color = "yellow"
local normal_dep_color = "black"
local protected_dep_color = "green"
local normal_dep_style = "solid"
local lazy_dep_style = "dashed"

-- Return graph representation in .dot format.
function depgraph.render(graph, title)
   local lines = {("digraph %q {"):format(title)}
   local ids = {}
   local next_id = 1

   local function add_node(file_object, color)
      if not ids[file_object] then
         ids[file_object] = next_id
         table.insert(lines, ("%d [color = %s label = %q]"):format(next_id, color, file_object.name))
         next_id = next_id + 1
      end
   end

   local function add_edges(file_object)
      for _, dep in ipairs(file_object.deps) do
         if not ids[dep.name] then
            local dep_file = graph.modules[dep.name] or {name = dep.name}
            add_node(dep_file, dep_file.deps and normal_module_color or external_module_color)
            ids[dep.name] = ids[dep_file]
         end

         table.insert(lines, ("%d -> %d [color = %s style = %s]"):format(
            ids[file_object], ids[dep.name],
            dep.protected and protected_dep_color or normal_dep_color,
            dep.lazy and lazy_dep_style or normal_dep_style))
      end
   end

   for _, file_object in ipairs(graph.ext_files) do
      add_node(file_object, external_file_color)
      add_edges(file_object)
   end

   for _, file_object in ipairs(graph.modules) do
      add_node(file_object, normal_module_color)
      add_edges(file_object)
   end

   table.insert(lines, "}")
   return table.concat(lines, "\n")
end

return depgraph
