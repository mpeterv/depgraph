local parse = require "depgraph.luacheck.parser"
local linearize = require "depgraph.luacheck.linearize"
local utils = require "depgraph.luacheck.utils"

local chstate_stub = setmetatable({}, {__index = function() return function() end end})

local function scan_or_throw_syntax_error(src)
   local ast = parse(src)
   linearize(chstate_stub, ast)
   return {}
end

-- Find all 'require' calls in source string.
-- Return an array of tables corresponding to calls.
-- Each require call table has keys 'line' and 'column' with call location,
-- 'name' key with the name of the required module, with '.*' suffix if the call may
-- refer to a subtree of modules,
-- 'lazy' key with true value for a call inside a function,
-- 'protected' key with true value for a call using 'pcall' or 'xpcall'.
-- On syntax error return nil, {line = line, column = column, message = message}.
local function scan(src)
   local modules, err = utils.pcall(scan_or_throw_syntax_error, src)

   if modules then
      return modules
   else
      return nil, {
         line = err.line,
         column = err.column,
         message = err.msg
      }
   end
end

return scan
