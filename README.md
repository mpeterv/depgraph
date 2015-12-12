# depgraph

depgraph is a library and a command-line tool for building and analyzing graph of dependencies between Lua modules within a package.

## Status

It works, but it's not tested. Lua API is not documented. The first official release is coming sooner or later.

## Installation

Using LuaRocks: clone this repo, `cd` into it, run `luarocks make`.

## Usage

Command-line tool is called `lua-depgraph` to avoid conflicts.

An invocation of `lua-depgraph` consists of two parts.

The first is to tell it how to find Lua modules to be added to the graph using `-m` option. It can be used several times, and accepts files, directories, and rockspecs. If not using a rockspec, pass prefix directory from where modules can be loaded using `-p`, e.g. if modules `foo.*` are in `src/foo/*.lua`, pass `-m src/foo -p src`. On the other hand, if there is a single rockspec in current directory, skip this step completely, it will be used automatically.

You can also add external files that are not Lua modules themselves but can depend on modules, e.g. examples, tests, scripts, using `-e` option. It can accept directories, too.

The second part is to tell `lua-depgraph` what it should do with the graph. Currently you can print list of all nodes using `list` command,
show all information about a particular module using `show`, show external dependencies using `deps`, look for circular dependencies using `cycles`, and export the graph into .dot format using `dot`.

## Examples

From Penlight root directory:

```
lua-depgraph list
39 modules, 0 external files.
Modules:
   pl in lua/pl/init.lua
   pl.Date in lua/pl/Date.lua
   pl.List in lua/pl/List.lua
   pl.Map in lua/pl/Map.lua
   pl.MultiMap in lua/pl/MultiMap.lua
   pl.OrderedMap in lua/pl/OrderedMap.lua
   pl.Set in lua/pl/Set.lua
   pl.app in lua/pl/app.lua
   pl.array2d in lua/pl/array2d.lua
   pl.class in lua/pl/class.lua
   pl.compat in lua/pl/compat.lua
   pl.comprehension in lua/pl/comprehension.lua
   pl.config in lua/pl/config.lua
   pl.data in lua/pl/data.lua
   pl.dir in lua/pl/dir.lua
   pl.file in lua/pl/file.lua
   pl.func in lua/pl/func.lua
   pl.import_into in lua/pl/import_into.lua
   pl.input in lua/pl/input.lua
   pl.lapp in lua/pl/lapp.lua
   pl.lexer in lua/pl/lexer.lua
   pl.luabalanced in lua/pl/luabalanced.lua
   pl.operator in lua/pl/operator.lua
   pl.path in lua/pl/path.lua
   pl.permute in lua/pl/permute.lua
   pl.pretty in lua/pl/pretty.lua
   pl.seq in lua/pl/seq.lua
   pl.sip in lua/pl/sip.lua
   pl.strict in lua/pl/strict.lua
   pl.stringio in lua/pl/stringio.lua
   pl.stringx in lua/pl/stringx.lua
   pl.tablex in lua/pl/tablex.lua
   pl.template in lua/pl/template.lua
   pl.test in lua/pl/test.lua
   pl.text in lua/pl/text.lua
   pl.types in lua/pl/types.lua
   pl.url in lua/pl/url.lua
   pl.utils in lua/pl/utils.lua
   pl.xml in lua/pl/xml.lua
```

```
lua-depgraph show pl.utils
Module pl.utils in lua/pl/utils.lua
Dependencies:
   * on line 82, column 13 (lazy)
   pl.compat on line 5, column 16
   pl.operator on line 329, column 31 (lazy)
Depended on by:
   pl.Date on line 11, column 15
   pl.List on line 26, column 15
   pl.Map on line 13, column 15
   pl.MultiMap on line 8, column 15
   pl.OrderedMap on line 9, column 15
   pl.Set on line 26, column 15
   pl.app on line 8, column 15
   pl.array2d on line 12, column 15
   pl.comprehension on line 33, column 15
   pl.data on line 20, column 15
   pl.dir on line 7, column 15
   pl.file on line 6, column 15
   pl.func on line 23, column 15
   pl.import_into as pl.* (2 times)
      on line 37, column 17 (lazy)
      on line 65, column 26 (lazy)
   pl.import_into on line 33, column 21 (lazy)
   pl.input on line 16, column 15
   pl.operator on line 15, column 15
   pl.path on line 18, column 15
   pl.permute on line 6, column 15
   pl.pretty on line 10, column 15
   pl.seq on line 12, column 15
   pl.stringx on line 11, column 15
   pl.tablex on line 7, column 15
   pl.template on line 31, column 15
   pl.test on line 12, column 15
   pl.text on line 23, column 15
   pl.types on line 6, column 15
   pl.xml on line 32, column 15
```

```
lua-depgraph dot | dot -Tgif -o pl.gif
```

[![Penlight dependency graph](http://i.imgur.com/UyZG3y4.gif)](http://i.imgur.com/UyZG3y4.gif)

From LuaRocks root directory:

```
lua-depgraph -m src/luarocks -p src -e src/bin cycles
11 circular dependencies found.
The shortest circular dependency has length 1:
   luarocks.fetch depends on luarocks.fetch on line 374, column 15 (lazy)
The next shortest circular dependency has length 2:
   luarocks.build depends on luarocks.install on line 380, column 23 (lazy)
   luarocks.install depends on luarocks.build on line 172, column 21 (lazy)
The next shortest circular dependency has length 2:
   luarocks.cfg depends on luarocks.util on line 20, column 14
   luarocks.util depends on luarocks.cfg (2 times)
      on line 268, column 16 (lazy)
      on line 486, column 16 (lazy)
The next shortest circular dependency has length 2:
   luarocks.deps depends on luarocks.fetch on line 697, column 18 (lazy)
   luarocks.fetch depends on luarocks.deps on line 11, column 14
The next shortest circular dependency has length 2:
   luarocks.deps depends on luarocks.install on line 419, column 20 (lazy)
   luarocks.install depends on luarocks.deps on line 12, column 14
The next shortest circular dependency has length 2:
   luarocks.deps depends on luarocks.search on line 418, column 19 (lazy)
   luarocks.search depends on luarocks.deps on line 11, column 14
The next shortest circular dependency has length 2:
   luarocks.fs depends on luarocks.fs.lua on line 66, column 16
   luarocks.fs.lua depends on luarocks.fs on line 7, column 12
The next shortest circular dependency has length 2:
   luarocks.manif depends on luarocks.repos on line 18, column 15
   luarocks.repos depends on luarocks.manif on line 12, column 15
The next shortest circular dependency has length 2:
   luarocks.manif depends on luarocks.search on line 14, column 16
   luarocks.search depends on luarocks.manif on line 10, column 15
The next shortest circular dependency has length 3:
   luarocks.deps depends on luarocks.manif_core on line 19, column 20
   luarocks.manif_core depends on luarocks.type_check on line 9, column 20
   luarocks.type_check depends on luarocks.deps on line 9, column 14
The next shortest circular dependency has length 4:
   luarocks.cfg depends on luarocks.persist on line 42, column 17
   luarocks.persist depends on luarocks.util on line 10, column 14
   luarocks.util depends on luarocks.fs on line 49, column 15 (lazy)
   luarocks.fs depends on luarocks.cfg on line 14, column 13
```

```
lua-depgraph -m src/luarocks -p src -e src/bin deps
12 external dependencies.
debug required by:
   luarocks.util on line 13, column 15
lfs required by:
   luarocks.fs.lua on line 22, column 24 (conditional, protected)
ltn12 required by:
   luarocks.fs.lua on line 558, column 15 (conditional)
   luarocks.upload.api on line 123, column 31 (protected)
luarocks.site_config required by:
   luarocks.cfg on line 28, column 28 (conditional, protected)
md5 required by:
   luarocks.fs.lua on line 23, column 24 (conditional, protected)
mimetypes required by:
   luarocks.upload.multipart on line 19, column 45 (lazy, protected)
posix required by:
   luarocks.fs.lua on line 24, column 28 (conditional, protected)
socket.ftp required by:
   luarocks.fs.lua on line 19, column 19 (conditional, protected)
socket.http required by:
   luarocks.fs.lua on line 18, column 28 (conditional, protected)
   luarocks.upload.api (2 times)
      on line 208, column 32 (lazy, protected)
      on line 214, column 29 (lazy, protected)
ssl.https required by:
   luarocks.fs.lua on line 559, column 32 (conditional, protected)
   luarocks.upload.api on line 200, column 29 (lazy, protected)
zip required by:
   luarocks.fs.lua on line 21, column 29 (conditional, protected)
zlib required by:
   luarocks.tools.zip on line 7, column 14
```

## License

MIT.
