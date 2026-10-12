# LegibleC

[![CI](https://github.com/JoelHarter/LegibleC/actions/workflows/ci.yml/badge.svg)](https://github.com/JoelHarter/LegibleC/actions/workflows/ci.yml)

Write numerical code in Julia. Get the C you would have written by hand.

## The problem it solves

Numerical work gets written twice. Once in a language made for thinking —
Julia, Python, MATLAB — where an idea becomes a working function in an
afternoon. Then again in C, because the code has to run on a
microcontroller, inside a flight computer, in a library someone else links,
or anywhere a reviewer must read what ships. The second writing takes weeks,
introduces its own bugs, and produces a file nobody wants to own. From then
on there are two versions, and they drift.

LegibleC removes the second writing. You keep the Julia — it still runs,
tests and plots as before — and the C is generated from it: fixed-size
arrays on the stack, small helpers named for the mathematics they do, your
comments and docstrings carried across, no allocation, no runtime, nothing
to link but the C standard library. It reads as if a careful engineer wrote
it, because that is the standard it is held to.

## A taste

Three lines of Julia, and the C each becomes. In each pair, the first box is
the Julia as its author wrote it, and the second is what LegibleC wrote from
nothing but that — every character of it, the comments included. Nothing in
the C boxes was added by a person: the `// @orbit.jl:18:` lines, the
`// beta = temp1 \ temp2` steps, and the `///` helper descriptions
are all the transpiler's.

**Julia:** a physicist's line, names and all.

```julia
ẍ = -2ζ * ω₀ * ẋ - ω₀^2 * x
```

<p align="center"><b>⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇</b></p>

**C:** generated from only the Julia above, comment included — the
transpiler wrote that too.

```c
// @showcase.jl:7: ẍ = -2ζ * ω₀ * ẋ - ω₀^2 * x
double xddot = -2 * zeta * omega0 * xdot - omega0 * omega0 * x;
```

---

**Julia:** linear algebra, solve included — the normal equations of a
least-squares fit.

```julia
β = (X' * X) \ (X' * y)
```

<p align="center"><b>⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇ ⬇</b></p>

**C:** generated from only the Julia above. Every comment is generated
too: the source line above the block, and after each call the step it
performs, in the C names — so you can follow the line's work through the
temps without losing the thread.

```c
// @orbit.jl:18: β = (X' * X) \ (X' * y)
double temp1[2][2];
mul_T4x2_4x2(X, X, temp1);  // temp1 = Xᵀ * X
double temp2[2];
mul_T4x2_4(X, y, temp2);  // temp2 = Xᵀ * y
double beta[2];
solve_2x2_2(temp1, temp2, beta);  // beta = temp1 \ temp2
```

**The helpers**, generated beside the functions in `helper.h`, each under
a two-line comment, also generated: what it does in words, then as the
formula. The everyday ones are a few lines:

```c
/// 4×2-matrix * 2-vector multiplication
/// out = A * b
static inline void mul_4x2_2(const double A[4][2], const double b[2], double out[restrict 4]) {
    for (int i = 0; i < 4; i++) {
        double sum = 0.0;
        for (int k = 0; k < 2; k++) {
            sum += A[i][k] * b[k];
        }
        out[i] = sum;
    }
}
```

A solve at 2×2 or 3×3 is written out the way a person writes it. From 4×4
on, at whatever size the matrix is, it's LU with partial pivoting: three
generated helpers, `pivot_4x4`, `lu_4x4` and `solve_4x4_4`, each commented
like the ones above. Transpile an `A \ b` at 4×4 to read them. Everything
stays on the stack at its static size; this is for the small dense systems
of control and simulation, not for the BLAS-sized ones.

**The whole thing** is in [demo/](demo/README.md): each folder is one
Julia file. Run `julia showcase.jl` there and an `out/` appears beside it
with the C — a header a caller includes, the functions, the helpers. Do the
same for your own code:

```julia
using LegibleC
transpile(f, g; project="name")
```

## What you get

- **C you can read, review and sign off.** Every helper says what it
  computes. Every function carries its docstring as a Doxygen block, in a
  header a caller can include. The Julia line each statement came from sits
  above it. Nothing betrays a machine's bookkeeping.
- **Your names, your structure.** `ω₀` is `omega0`, `ẋ` is `xdot`, `ħ` is
  `hbar` — the name you typed to get the character, from Julia's own table,
  or your own spelling if you prefer. A function returning `x, ẋ` returns a
  `step_t` with fields `x` and `xdot`. A constant a function reads becomes a
  named C constant; a name from another module keeps the module in front.
- **Speed a C programmer would accept.** Static sizes, stack arrays,
  `static inline` helpers, `restrict` where it is safe, `sincos` as the two
  calls the compiler fuses. The compiler is given what it would have been
  given by hand.
- **No runtime.** Nothing to allocate, initialize or link. The folder
  compiles on its own, on anything with a C compiler.
- **Errors at transpile time, never wrong C.** Julia the transpiler doesn't
  understand is refused with a message. What comes out carries out the
  Julia's logical intent: the same calculation, the same steps, the same
  order.
- **One source of truth.** The Julia is the program; the C is a view of it.
  Change the Julia, regenerate, and the two never drift.

## Where it fits

Embedded and real-time control. Flight and vehicle software. Simulation
kernels that must run where there is no runtime. Numerical libraries exposed
through a C ABI to every other language. Anywhere the code that ships has to
be read by a person who didn't write it.

## How it differs

- **From compiling to a binary** — `juliac`, PackageCompiler, StaticCompiler,
  and their counterparts for other languages. They run the language's own
  compiler, so what they produce is the program exactly, and they take far
  more of the language than this does. But what they produce is machine
  code: nothing to read, nothing to review, nothing to keep when the
  toolchain moves on. And it comes with the language's runtime on board —
  trimming it down is possible and hard — where this needs nothing but the
  C standard library. This produces source, and source is the artifact
  every other tool in an engineering process knows what to do with. And
  sometimes source is not a preference but a requirement: a team, a
  company or a certifying authority rules that what ships must exist as C
  that a person can review. A binary cannot meet that. This can, because
  the C is there, and it is legible.
- **From generic C generators** — MATLAB Coder, Cython, f2c. Their C is
  correct and complete, and it will compile years from now. It also reads
  like it was generated: names nobody chose, arrays behind a runtime of
  their own, control flow no person would write. Here legibility is a
  design tenet, behind only correctness and speed: the output is held to
  the standard of hand-written C, and it shows.
- **From writing the C yourself.** Nothing beats it, which is why the goal
  here is to be indistinguishable from it: this is what a competent C
  programmer would have written, generated for you, and generated again
  every time the Julia changes, so keeping the two in sync costs nothing.
  The one thing you give up is editing the C by hand, since the next run
  writes over it — the Julia is where changes go.
- **From asking an AI.** Models are astonishing at code, and any of them
  will turn what you paste into C on request. What comes back depends on
  the model, the day, the wording, and whether the bill was paid. This is
  deterministic: the same input gives the same output, every time, offline,
  in a CI job, with no model and no network — and where it can't translate
  something, it says so instead of guessing.

## What it is not

- **Not a Julia compiler.** No garbage collector, dynamic dispatch, strings
  built at run time, growing arrays, closures or exceptions. Every size is
  known at transpile time. Code that needs Julia's runtime needs Julia.
- **Not bit-exact.** The C computes the same thing by the same steps; the
  last bit of a rounded result may differ.
- **Not a way to make Julia faster.** Julia is already fast. This is for
  when the code has to leave Julia.

## Using it

```julia
] add LegibleC
using LegibleC
transpile(f, g, (h, Float64, 3, Float64, 2, 3); project="name", outpath=dir)
```

A target is a function with one concrete method, or a function with its
argument types spelled out, where a type followed by integers is an array of
that element type and size. Arrays are `StaticArrays` types, or `Array`s
given a size in the call. An `out/` folder comes out: a `.c` and a `.h` for
every function, named after it, a header for every struct, `<project>_common.h` for
the constants and globals, `<project>.h` for callers, which includes them all,
and `helper.h` and `helper.c` with
the generated helpers they need — and anything a listed function calls
comes with it. With `split=false`, it is all in `<project>.h` and `<project>.c`. Constants a function reads come along too, and any you list
by keyword, `transpile(f; g, μ)`; `@transpile` does the same from inside a
module. `transpile` and `@transpile` are the package's only exported names,
so your own functions can be named anything.

[doc/guide/](doc/guide/README.md) is the user guide: what's accepted,
targets, every option, calling the C, how names come out and how to
override them.

## Version

LegibleC is at `0.x`. What a version promises: the C computes what the Julia
computes, by the same steps, and a case where it quietly differs is a bug.
`transpile`, `@transpile` and their options change only with a minor
version, `0.2`; what the C looks like — names, file layout, how a construct
is spelled — may change with any version while `0.x` lasts, since that is
what this project is still deciding. If you check the generated C into a
repository, regenerate it when you update, and read the diff.

## Documentation

- [doc/philosophy.md](doc/philosophy.md) — the tenets behind every
  decision: logic, speed, craft, generality, in that order.
- [doc/guide/](doc/guide/README.md) — the user guide.
- [doc/](doc/) — how the transpiler works, one topic per file; its README
  gives a reading order.
- [doc/dev/](doc/dev/) — the decision log, and the survey of what could
  still map between Julia and C.
- [extra/stackmath/](extra/stackmath/stackmath.jl) — a script that generates a
  library of static linear algebra in C, every operation at every size from
  2 to 10, one file per operation: what the operator targets are for.

## Tests

```
julia test/runtests.jl
```

Every test transpiles a few Julia functions, builds a C program that calls
them on fixed inputs, and compares what C prints with what Julia computes
for the same calls.

## Authorship

A note from me, the author. LegibleC is my idea and my work, made in my
free time. I saw that numerical code was being written twice and decided it
did not have to be; I decided what the generated C should look like and why;
and every decision about the architecture — what the transpiler accepts,
what it refuses, how names, types, memory and control flow come out — was
mine, thought through for its consequences before I made it and argued in
[doc/dev/decision.md](doc/dev/decision.md), and I held the result to the
standard each decision set.

I used an AI assistant as the tool for building it fast: it drafted and
refactored code under my direction. Without it, a project of this size could
never have fit in the free time I had; with it, my time went where it
should, on the thinking rather than the typing. The tests above are what
vouch for the code: every function in them is transpiled, compiled and run
against Julia on every push, under GCC and Clang.

-*Joel T Harter*
