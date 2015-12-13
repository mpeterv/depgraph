package = "rock"
version = "1-1"
build = {
   type = "builtin",
   modules = {
      rock = "spec/samples/rock.lua",
      ["rock.foo"] = "spec/samples/rock/foo.lua",
      ["rock.bar"] = "spec/samples/rock/bar.lua"
   },
   install = {
      bin = {
         rock = "spec/samples/bin/rock.lua"
      }
   }
}
