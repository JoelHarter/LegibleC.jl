# Option

Every keyword option of `transpile`.

| option | default | what it does |
|---|---|---|
| `project` | `"lib"` | the name of the library the output is: the header a caller includes, `<project>.h`, which includes all the others; with `split` off, the two files that hold everything; and the first word of every macro the output invents, `LIB_PI`, `LIB_ENERGY_H`, so two generated libraries keep out of each other's way. Several `transpile` calls into one `out/` each name their own, as with `helper` |
| `include` | `true` | write `<project>.h`, the header that includes every other, so a caller can include one file; nothing else is in it. Off, a caller includes the headers it uses. With `split` off there is no other header and the option does nothing |
| `helper` | `"helper"` | the name of the helper files, `helper.h` and `helper.c`; give each `transpile` call into one `out/` its own, and each keeps its helpers |
| `split` | `true` | every function in a file of its own, named after it, listed or not, with its header, and nothing else in it; every struct of yours in a header of its own; a type the C needed and you never named — a tuple held as a value, the struct a tuple is returned in — in the header of the first function or struct that mentions it; the globals in `<project>_common.h` and `<project>_common.c` — the constants as `static const`, the other globals as `extern` with their definitions in the `.c`, and the declarations of C functions called through `ccall`, written only when there are any; and `<project>.h`, which includes every other header, so a caller can still include one file. Names that differ only in case, `point` and `Point`, share a file named in lowercase. Off, everything is in `<project>.h` and `<project>.c` |
| `outpath` | `pwd()` | the folder |
| `source` | `true` | copy each Julia line above its C as a comment, `// β = (X' * X) \ (X' * y)` |
| `line` | `false` | put the locator in front of each copied line, `// @orbit.jl:18: …`, and after the Julia signature in the Doxygen block. Off: line numbers move with every edit |
| `comment` | `true` | carry the author's own comments and docstrings into the C |
| `precise` | `false` | print floats with every digit (`%.17g`) instead of `%g` |
| `posix` | `false` | write `pi` and `ℯ` as `M_PI` and `M_E` from `math.h`, which are POSIX rather than ISO C; a file that uses one defines it under `#ifndef`, since glibc's `<math.h>` leaves them out under a strict `-std=c11`. Off, they are `LIB_PI` and `LIB_E`, as every irrational — `Base.MathConstants.catalan`, one of your own by `Base.@irrational` — is a macro named after it, defined in the helper header to 128-bit precision, only where used — see [constant.md](constant.md) |
| `goto` | `false` | may the C contain a `goto`? It is wanted for one thing only: a `break` that leaves a whole nest of loops, `for i in 1:n, j in 1:m`, which C has no other word for. On, that is `goto done;` and a label after the nest, as many C programmers write it by hand. Off, it is a flag that the outer loops test, `i <= n && !done`, which the coding guidelines for safety-critical C prefer, and the output has no `goto` anywhere |
| `c23floattypes` | `false` | write `Float64` and `Float32` as C23's `_Float64` and `_Float32` instead of `double` and `float` |
| `bool` | `Bool` | the C type for a `Bool`: `Bool` for C's `bool`, or one of Julia's integer types for that integer wherever a `Bool` appears, names included; the C then writes `0` and `1` and reads any nonzero value as true |
| `real` | `Float64` | the real type that goes unmarked in a name: `add_3` is its helper, and another type's is `add_3F32`. `Float64` or `Float32`. Nothing but names changes |
| `int` | `Int64` | the same for integers: `gcd` is its helper, and another type's is `gcdI32`. Any of Julia's eight integer types |
| `force` | `false` | write every real as the `real` type and every integer as the `int` type, whatever the Julia says: parameters, results, fields, elements, numbers written out, and so every helper's name unmarked. Which method a call runs is still decided by the Julia's own types. The arithmetic is then no longer the Julia's: a `Float32` rounds where a `Float64` didn't, an `Int8` no longer wraps at 128, an unsigned number is signed, and a function of a number's bits, `leading_zeros`, counts the new width. A `Bool` is left to the `bool` option, and a `Char` is a `char` |
| `width` | `100` | the longest line; a long scalar expression wraps at its loosest operators |
| `templimit` | `40` | the longest name a temporary may be given before its descriptive suffix is dropped |
| `tempsuffix` | `false` | on, temporaries carry what they were computed from, `temp1_a_b = a + b`, and an unnamed lambda what it captured, `fun3_a_b`; off, they are `temp1`, `temp2`, … and `fun1`, `fun2`, … |
| `spelling` | `Dict()` | your own C spellings for characters in names — see [name.md](name.md) |
| `scope` | `Main` | the module a keyword variable's name is looked up in, to decide `const`; `@transpile` sets it to the module the call is written in |
| any other keyword | | a variable to include, named after the keyword — see [target.md](target.md) |
