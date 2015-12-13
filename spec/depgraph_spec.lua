local depgraph = require "depgraph"

describe("depgraph", function()
   describe("make_graph", function()
      it("returns empty graph when there are no files", function()
         assert.same({modules = {}, ext_files = {}}, depgraph.make_graph({}, {}))
      end)

      it("returns nil, error on missing file", function()
         local graph, err = depgraph.make_graph({"spec/samples/missing.lua"}, {})
         assert.is_nil(graph)
         assert.match("^Could not open spec/samples/missing.lua:", err)
      end)

      it("returns nil, error on syntactically incorrect file", function()
         local graph, err = depgraph.make_graph({"spec/samples/syntax_error.lua"}, {})
         assert.is_nil(graph)
         assert.match("^Could not scan spec/samples/syntax_error.lua: syntax error", err)
      end)

      it("returns nil, error on file name with too many dots", function()
         local graph, err = depgraph.make_graph({"spec/samples/...lua"}, {})
         assert.is_nil(graph)
         assert.equal("File name 'spec/samples/...lua' contains too many dots", err)
      end)

      it("returns nil, error on file name containing an asterisk", function()
         local graph, err = depgraph.make_graph({"spec/samples/*.lua"}, {})
         assert.is_nil(graph)
         assert.equal("File name 'spec/samples/*.lua' contains an asterisk", err)
      end)

      it("returns nil, error on invalid prefix", function()
         local graph, err = depgraph.make_graph({"spec/samples/rock.lua"}, {}, "prefix")
         assert.is_nil(graph)
         assert.equal("File name 'spec/samples/rock.lua' does not start with 'prefix'", err)
      end)

      it("returns nil, error on problematic file within a directory", function()
         local graph, err = depgraph.make_graph({"spec/samples"}, {})
         assert.is_nil(graph)
         assert.match("^Could not scan spec/samples/syntax_error.lua:", err)

         graph, err = depgraph.make_graph({}, {"spec/samples"})
         assert.is_nil(graph)
         assert.match("^Could not scan spec/samples/syntax_error.lua:", err)
      end)

      it("returns nil, error on invalid rockspecs", function()
         local graph, err = depgraph.make_graph({"spec/samples/missing.rockspec"}, {})
         assert.is_nil(graph)
         assert.match("^Could not open spec/samples/missing.rockspec:", err)

         graph, err = depgraph.make_graph({"spec/samples/syntax_error.rockspec"}, {})
         assert.is_nil(graph)
         assert.match("^Could not compile spec/samples/syntax_error.rockspec:", err)

         graph, err = depgraph.make_graph({"spec/samples/run_error.rockspec"}, {})
         assert.is_nil(graph)
         assert.match("^Could not load spec/samples/run_error.rockspec:", err)

         graph, err = depgraph.make_graph({"spec/samples/no_build.rockspec"}, {})
         assert.is_nil(graph)
         assert.equal("Rockspec spec/samples/no_build.rockspec does not contain build table", err)

         graph, err = depgraph.make_graph({"spec/samples/bad_file.rockspec"}, {})
         assert.is_nil(graph)
         assert.match("^Could not open missing.lua:", err)
      end)

      it("returns lists of modules and external files", function()
         local graph = depgraph.make_graph({"spec/samples/rock/bar.lua"}, {"spec/samples/bin"}, "spec/samples")

         assert.same({
            {file = "spec/samples/bin/rock.lua", name = "spec/samples/bin/rock.lua", deps = {{
               name = "rock",
               requires = {
                  {name = "rock", line = 1, column = 1}
               }
            }}}
         }, graph.ext_files)
         local rock = graph.modules[1]
         assert.same({file = "spec/samples/rock/bar.lua", name = "rock.bar", deps = {{
            name = "rock",
            requires = {
               {name = "rock", line = 1, column = 1}
            }
         }}}, rock)
         assert.equal(rock, graph.modules["rock.bar"])
      end)
   end)
end)
