# ALERT

This software is pretty raw and code is trash. When I first started this
project, I didn't think that developing a good debugger is THIS HARD. I mean, it
works somewhat good with Lua but it was created to work good with Fennel.

It'll be rewritten from scratch some day. Remember that, although you can open
an issue if found a bug, it probably wouldn't be fixed until v2.

# Features

- Remote debug support (via `fnldbg --serve` and `fnldbg --connect`)
- Debug repl is just an extended Fennel repl (fennel module included)
- Can step to the start or the end of a function
- Can step any count of instructions or lines
- Of course can just run code until it terminates
- Tracebacks
- Accessing locals (you can even modify them!)

# Problems

- Works bad with tail call optimisation. I mean, it's almost impossible to
  generate good tracebacks when programm has TCO.
- Although it's a Fennel debugger, mangling isn't supported. I tried to
  add support of it but code is too clumsy.
- Locations (file and line) are sometimes wrong. Everything should be fine
  unless you are using metadata files but even in this case bugs are rare.
- While remote debugging, you can't access functions because I've used JSON as
  message format.
- You can't step to the end of foreign function because of hooks limitations.

# Installation

```sh
$ git clone --depth 1 https://codeberg.org/pluffie/fnldbg && cd fnldbg
$ make deps && make && make install
```
