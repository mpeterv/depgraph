# depgraph

[![Build Status](https://travis-ci.org/mpeterv/depgraph.svg?branch=master)](https://travis-ci.org/mpeterv/depgraph) [![Coverage Status](https://coveralls.io/repos/mpeterv/depgraph/badge.svg?branch=master&service=github)](https://coveralls.io/github/mpeterv/depgraph?branch=master)

depgraph provides `luadepgraph` command-line tool for building, analyzing, and visualizing graph of dependencies between Lua modules within a package. To install it using [LuaRocks](https://luarocks.org), open terminal and run `luarocks install depgraph` or `sudo luarocks install depgraph`.

`luadepgraph` scans all passed files, looking for [`require`](http://www.lua.org/manual/5.3/manual.html#pdf-require) calls. It distinguishes several types of dependencies based on call context:

* A dependency is *lazy* if `require` is called inside a function;
* A dependency is *conditional* if `require` is called within a branch of an `if` statement;
* A dependency is *protected* if `require` is called using [`pcall`](http://www.lua.org/manual/5.3/manual.html#pdf-pcall) or [`xpcall`](http://www.lua.org/manual/5.3/manual.html#pdf-xpcall).

Dependency target is inferred from the argument passed to `require` if it's a literal string or a concatenation of a string and another expression.

## Specifying Lua files

`luadepgraph` needs to know which Lua files are part of the package and have to be included in its dependency graph. It can handle two types of files: regular modules and external files that can't be imported from other files, but can depend on modules, e.g. scripts and test files.

Modules are specified using `-m/--modules` option and external files are added using `-e/--ext-files`. Both options accept several files or directories. `-m/--modules` also accepts rockspecs; if no modules are added but there is a single rockspec in current directory, it will be used automatically.

Unless using a rockspec, pass prefix directory from where Lua modules can be loaded using `-p/--prefix`.

## Graph actions

`luadepgraph` can perform several actions on the graph:

* `--list`: print a listing of modules and external files in the graph. This is the default action.
* `--show <module>`: print all information about a module, which includes its location, dependencies and dependents. External files can be passed by file name.
* `--deps`: print a listing of all external dependencies of the graph.
* `--cycles`: look for circular dependencies and show the shortest ones.
* `--dot [<title>]`: export the graph in .dot format, which can be turned into an image using [Graphviz](http://www.graphviz.org/).
    - Nodes with black border are modules, blue borders - external files, yellow - unresolved and external dependencies.
    - Solid edges are normal dependencies, dashed edges - conditional dependencies, dotted - lazy ones.
    - Black edges are unprotected dependencies, green ones are protected.

There are some options that can preprocess or filter the graph before executing an action, run `luadepgraph -h` for more info.

## Examples

List all modules in `src` directory:

```
luadepgraph -m src -p src
```

Show dependencies and dependents of module `rock.foo`:

```
luadepgraph -m src -p src --show rock.foo
```

List all modules used by unit test `spec/foo_spec.lua`:

```
luadepgraph -m src -p src -e spec --root spec/foo_spec.lua
```

Show external dependencies of a package given a rockspec:

```
luadepgraph -m rockspecs/rock-1.0-1.rockspec --deps
```

Look for circular dependencies:

```
luadepgraph -m rockspecs/rock-1.0-1.rockspec --cycles
```

Same, but ignore lazy dependencies:

```
luadepgraph -m rockspecs/rock-1.0-1.rockspec --cycles --strict
```

Turn the graph into an image (`dot` command-line tool is a part of Graphviz):

```
luadepgraph -m rockspecs/rock-1.0-1.rockspec --dot | dot -Tgif -o rock.gif
```
