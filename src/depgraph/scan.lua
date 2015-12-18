local parse = require "depgraph.luacheck.parser"
local linearize = require "depgraph.luacheck.linearize"
local utils = require "depgraph.luacheck.utils"

local function get_name(node)
   if not node then
      return
   elseif node.tag == "Id" then
      return node[1]
   elseif node.tag == "Index" and node[1].tag == "Id" and (node[1][1] == "_G" or node[1][1] == "_ENV") then
      if node[2].tag == "String" then
         return node[2][1]
      end
   end
end

local function add_require(requires, req_node, arg_node, nested, protected, cond)
   local name

   if arg_node then
      if arg_node.tag == "String" then
         name = arg_node[1]
      elseif arg_node.tag == "Op" and arg_node[1] == "concat" and arg_node[2].tag == "String" then
         name = (arg_node[2][1]:match("^(.*%.)") or "") .. "*"
      end
   end

   table.insert(requires, {
      name = name or "*",
      line = req_node.location.line,
      column = req_node.location.column,
      lazy = nested,
      conditional = cond,
      protected = protected
   })
end

local scan_exprs, scan_function

local function scan_expr(requires, local_to_funcs, node, nested, protected, cond)
   if node.tag == "Function" then
      scan_function(requires, local_to_funcs, node, true, protected, cond)
   else
      if node.tag == "Call" then
         local callee = get_name(node[1])

         if callee == "require" then
            add_require(requires, node[1], node[2], nested, protected, cond)
         elseif callee == "pcall" or callee == "xpcall" then
            if node[2] and local_to_funcs[node[2].var] then
               for _, func in ipairs(local_to_funcs[node[2].var]) do
                  func.nested = nested
                  func.protected = true
                  func.cond = cond
               end
            elseif node[2] and node[2].tag == "Function" then
               scan_function(requires, local_to_funcs, node[2], nested, true, cond)
            else
               local protected_callee = get_name(node[2])

               if protected_callee == "require" then
                  add_require(requires, node[2], callee == "xpcall" and node[4] or node[3], nested, true, cond)
               end
            end
         end
      end

      scan_exprs(requires, local_to_funcs, node, nested, protected, cond)
   end
end

function scan_exprs(requires, local_to_funcs, nodes, nested, protected, cond)
   for _, node in ipairs(nodes) do
      if type(node) == "table" then
         scan_expr(requires, local_to_funcs, node, nested, protected, cond)
      end
   end
end

local function register_local_func(local_to_funcs, local_node, func, protected, cond)
   local var = local_node.var
   local_to_funcs[var] = local_to_funcs[var] or {}
   table.insert(local_to_funcs[var], func)
   func.nested = true
   func.protected = protected
   func.cond = cond
end

local function scan_block(requires, local_to_funcs, nodes, nested, protected, cond)
   for _, node in ipairs(nodes) do
      if node.tag == "Do" then
         scan_block(requires, local_to_funcs, node, nested, protected, cond)
      elseif node.tag == "While" then
         scan_expr(requires, local_to_funcs, node[1], nested, protected, cond)
         scan_block(requires, local_to_funcs, node[2], nested, protected, cond)
      elseif node.tag == "Repeat" then
         scan_block(requires, local_to_funcs, node[1], nested, protected, cond)
         scan_expr(requires, local_to_funcs, node[2], nested, protected, cond)
      elseif node.tag == "Fornum" then
         scan_block(requires, local_to_funcs, node[5] or node[4], nested, protected, cond)
      elseif node.tag == "Forin" then
         scan_block(requires, local_to_funcs, node[3], nested, protected, cond)
      elseif node.tag == "If" then
         for i = 1, #node - 1, 2 do
            scan_expr(requires, local_to_funcs, node[i], nested, protected, i ~= 1 or cond)
            scan_block(requires, local_to_funcs, node[i + 1], nested, protected, true)
         end

         if #node % 2 == 1 then
            scan_block(requires, local_to_funcs, node[#node], nested, protected, true)
         end
      elseif node.tag == "Local" or node.tag == "Set" then
         local lhs, rhs = node[1], node[2]

         if rhs then
            for i, rhs_node in ipairs(rhs) do
               if rhs_node.tag == "Function" and lhs[i] and lhs[i].tag == "Id" and lhs[i].var then
                  register_local_func(local_to_funcs, lhs[i], rhs_node, protected, cond)
               else
                  scan_expr(requires, local_to_funcs, rhs_node, nested, protected, cond)
               end
            end
         end
      elseif node.tag == "Localrec" then
         register_local_func(local_to_funcs, node[1], node[2], protected, cond)
      elseif node.tag == "Call" or node.tag == "Invoke" then
         scan_expr(requires, local_to_funcs, node, nested, protected, cond)
      elseif node.tag == "Return" then
         scan_exprs(requires, local_to_funcs, node, nested, protected, cond)
      end
   end
end

function scan_function(requires, local_to_funcs, node, nested, protected, cond)
   if not node.scanned then
      node.scanned = true
      nested = nested or node.nested
      protected = protected or node.protected
      cond = cond or node.cond
      scan_block(requires, local_to_funcs, node[2], nested, protected, cond)
   end
end

local chstate_stub = setmetatable({}, {__index = function() return function() end end})

local function location_comparator(req1, req2)
   return req1.line < req2.line or (req1.line == req2.line and req1.column < req2.column)
end

local function scan_or_throw_syntax_error(src)
   local ast = parse(src)
   linearize(chstate_stub, ast)

   local requires = {}
   local local_to_funcs = {}
   scan_block(requires, local_to_funcs, ast)

   for _, funcs in pairs(local_to_funcs) do
      for _, func in ipairs(funcs) do
         scan_function(requires, local_to_funcs, func)
      end
   end

   table.sort(requires, location_comparator)
   return requires
end

-- Find all 'require' calls in source string.
-- Return an array of tables corresponding to calls.
-- Each require call table has keys 'line' and 'column' with call location,
-- 'name' key with the name of the required module, with '.*' suffix if the call may
-- refer to a subtree of modules,
-- 'lazy' key with true value for a call inside a function,
-- 'conditional' key with true value for a call inside an 'if' branch,
-- 'protected' key with true value for a call using 'pcall' or 'xpcall'.
-- On syntax error return nil, error message.
local function scan(src)
   local modules, err = utils.pcall(scan_or_throw_syntax_error, src)

   if modules then
      return modules
   else
      return nil, ("syntax error on line %d, column %d: %s"):format(err.line, err.column, err.msg)
   end
end

return scan
