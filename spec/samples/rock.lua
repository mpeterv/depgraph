require "rock.foo"
pcall(require, "dep." .. something)
xpcall(require, handler, "rock.foo")

if cond() then
   require("this")
else
   require("that")
   pcall(require, "rock.bar")
end
