# One file for everything, or every function and struct in a file of its own.
module File
using Test, StaticArrays
import Main: Case, check, csource
import LegibleC: transpile

const g = 9.81   # gravity, m/s²
struct Point
    x::Float64
    y::Float64
end
"Squared."
square(x::Float64) = x * x
fall(t::Float64) = 0.5 * g * square(t)
height(t::Float64) = 100.0 - fall(t)
far(p::Point) = square(p.x) + square(p.y)
alone(x::Float64) = x + 1.0
doubled(v::SVector{3,Float64}) = v + v
point(p::Point) = p.x
function step(x::Float64, ẋ::Float64, dt::Float64)
    ẋ += dt * -x
    x += dt * ẋ
    return x, ẋ
end
function twice(x::Float64, ẋ::Float64, dt::Float64)
    x, ẋ = step(x, ẋ, dt)
    return step(x, ẋ, dt)
end

check("lib", [Case(fall, 2.0), Case(far, Point(3.0, 4.0)), Case(alone, 1.0), Case(twice, 1.0, 0.0, 0.1)]; split=true)
@testset "file" begin
    dir = mktempdir()
    # Split: every function in its own file, listed or not, every struct in its own
    # header, the constant in the base header, which includes all the others.
    paths = transpile(height, far, alone; project="lib", split=true, outpath=dir, scope=@__MODULE__)
    @test basename.(paths) == ["height.c", "far.c", "alone.c", "fall.c", "square.c"]
    out = dirname(paths[1])
    @test sort(readdir(out)) == ["Point.h", "alone.c", "alone.h", "fall.c", "fall.h", "far.c", "far.h", "height.c", "height.h", "lib.h", "lib_common.h", "square.c", "square.h"]
    text(f) = read(joinpath(out, f), String)
    @test occursin("// @file.jl:7: const g = 9.81   # gravity, m/s²\nstatic const double g = 9.81;", text("lib_common.h"))
    @test all(occursin("#include \"$h\"", text("lib.h")) for h in ("lib_common.h", "height.h", "far.h", "alone.h", "fall.h", "square.h", "Point.h"))
    @test occursin("#ifndef LIB_H\n#define LIB_H\n\n#include", text("lib.h")) && !occursin("static const", text("lib.h"))
    @test occursin("#include \"lib_common.h\"\n#include \"square.h\"\n#include \"fall.h\"\n", text("fall.c")) && occursin("return 0.5 * g * square(t);", text("fall.c"))
    @test occursin("#include \"fall.h\"\n#include \"height.h\"\n", text("height.c"))
    @test occursin("#include \"Point.h\"\n\n/**", text("far.h")) && occursin("typedef struct {\n    double x;\n    double y;\n} Point;", text("Point.h"))
    @test occursin("/**\n * Squared.", text("square.h"))
    # A function's file holds the function alone; a type the Julia never named, the struct
    # its tuple is returned in, has no file of its own: it sits in the header of the first
    # function that mentions it, which a pass-through's header includes.
    paths = transpile(twice; project="lib", split=true, outpath=dir, scope=@__MODULE__)
    @test basename.(paths) == ["twice.c", "step.c"]
    @test occursin("} step_t;", text("step.h")) && !occursin("} step_t;", text("twice.h")) && !isfile(joinpath(out, "step_t.h"))
    @test occursin("#include \"step.h\"\n\n/**", text("twice.h"))
    # Split is what happens unless told otherwise.
    @test basename.(transpile(height, far, alone; project="lib", outpath=mktempdir(), scope=@__MODULE__)) == ["height.c", "far.c", "alone.c", "fall.c", "square.c"]
    # Names that differ only in case share a file, named in lowercase.
    fresh = mktempdir()
    @test transpile(point; project="lib", split=true, outpath=fresh, scope=@__MODULE__) == joinpath(fresh, "out", "point.c")
    @test sort(readdir(joinpath(fresh, "out"))) == ["lib.h", "point.c", "point.h"]
    merged = read(joinpath(fresh, "out", "point.h"), String)
    @test occursin("} Point;", merged) && occursin("double point(Point p);", merged)
    # One file, when asked for.
    @test transpile(height, far; project="both", split=false, outpath=dir, scope=@__MODULE__) == joinpath(out, "both.c")
    @test occursin("double square(double x)", text("both.c")) && occursin("static const double g = 9.81;", text("both.h"))
    @test_throws ArgumentError transpile(height; project="helper", outpath=dir, scope=@__MODULE__)
    @test occursin("#ifndef LIB_HEIGHT_H\n#define LIB_HEIGHT_H\n", text("height.h")) && occursin("#endif  // LIB_HEIGHT_H", text("height.h"))
    @test occursin("#ifndef LIB_H\n#define LIB_H\n", text("lib.h")) && occursin("#endif  // LIB_H", text("lib.h"))
    # The helper files by another name, so two calls into one `out/` keep both sets.
    path = transpile(doubled; project="geo", helper="geohelper", split=false, outpath=dir, scope=@__MODULE__)
    @test isfile(joinpath(out, "geohelper.h")) && occursin("#include \"geohelper.h\"", text("geo.c")) && occursin("GEO_GEOHELPER_H", text("geohelper.h"))
    @test_throws ArgumentError transpile(far; project="same", helper="same", outpath=dir, scope=@__MODULE__)
    # Without the header that includes all the others: a caller includes each function's.
    bare = mktempdir()
    @test basename.(transpile(far, alone; project="bare", include=false, outpath=bare, scope=@__MODULE__)) == ["far.c", "alone.c", "square.c"]
    @test sort(readdir(joinpath(bare, "out"))) == ["Point.h", "alone.c", "alone.h", "far.c", "far.h", "square.c", "square.h"]
    @test occursin("#ifndef BARE_FAR_H\n", read(joinpath(bare, "out", "far.h"), String))
    # The globals keep their file either way; the project header is the only thing left out.
    bare = mktempdir()
    @test basename.(transpile(height; include=false, outpath=bare, scope=@__MODULE__)) == ["height.c", "fall.c", "square.c"]
    @test sort(readdir(joinpath(bare, "out"))) == ["fall.c", "fall.h", "height.c", "height.h", "lib_common.h", "square.c", "square.h"]
    @test occursin("#include \"lib_common.h\"\n", read(joinpath(bare, "out", "fall.c"), String))
    # The globals' file is named after the project, with the project's name once in its guard.
    @test occursin("#ifndef LIB_COMMON_H\n#define LIB_COMMON_H\n", text("lib_common.h"))
    @test_throws ArgumentError transpile(height; helper="lib_common", outpath=bare, scope=@__MODULE__)
end
end
