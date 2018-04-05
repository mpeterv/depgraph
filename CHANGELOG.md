# Changelog

## 0.2.0 (unreleased)

### Improvements

* `require` calls using slashes instead of dots to separate module name parts
  are now supported (slashes are replaced with dots).
* When loading modules from a rockspec, `module` build.type is supported
  as an alias for `builtin`.
* Better error message when `luadepgraph` is interrupted with `^C`.
* Better error message on internal errors.

## 0.1.1 (2016-01-25)

### Improvements

* Updated Lua parser to Luacheck 0.13.0, improving syntax error messages.

## 0.1.0

Initial release.
