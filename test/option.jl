# The options that change how scalars are spelled: C23 float types, and an integer as bool.
module Option
using Test, StaticArrays
import Main: Case, check, csource
import LegibleC: transpile

mix(x::Float64, y::Float32) = x * 2 + Float64(sqrt(y))
flag(x::Float64) = x > 0
pick(b::Bool, x::Float64) = b ? x : -x
same(a::Bool, b::Bool) = a == b
tally(b::Bool, n::Int64) = Int64(b) + n
truth() = true
masked(m::SVector{3,Bool}) = sum(m)
printed(b::Bool) = println(b)

check("boolint", [Case(flag, 2.0), Case(flag, -1.0), Case(pick, true, 3.0), Case(pick, false, 3.0), Case(same, true, true), Case(same, true, false),
                  Case(tally, true, 5), Case(truth), Case(masked, SVector(true, false, true))]; bool=Int32)
@testset "option" begin
    # C23 float types, wherever a double or float was: text only, since the compiler
    # here doesn't know them.
    dir = mktempdir()
    path = transpile(mix; project="c23", outpath=dir, c23floattypes=true, scope=@__MODULE__)
    src = read(path, String) * read(joinpath(dirname(path), "c23.h"), String)
    @test occursin("_Float64 mix(_Float64 x, _Float32 y)", src) && occursin("return x * 2 + (_Float64)sqrtf(y);", src)
    @test !occursin("double", src) && !occursin(r"\bfloat\b", src)
    # An integer as bool: the type wherever a Bool was, the names with it, writes of 0
    # and 1, and a stored value read as nonzero where it enters arithmetic or a comparison.
    src = csource("boolint", flag, pick, same, tally, truth, masked, printed; bool=Int32)
    @test occursin("int32_t flag(double x)", src) && occursin("return x > 0;", src)
    @test occursin("double pick(int32_t b, double x)", src) && occursin("if (b) {", src)
    @test occursin("int32_t same(int32_t a, int32_t b)", src) && occursin("return (a != 0) == (b != 0);", src)
    @test occursin("return (int64_t)(b != 0) + n;", src)
    @test occursin("int32_t truth(void)", src) && occursin("return 1;", src)
    @test occursin("int64_t masked(const int32_t m[3])", src) && occursin("sum += (a[i] != 0);", src) && occursin("sum_3I32", src)
    @test occursin("int32_t truth(void) {\n    // true\n    return 1;\n}", src)
    @test occursin("printf(\"%d\\n\", b != 0);", src) && !occursin("stdbool.h", src)
    @test_throws ArgumentError csource("boolfloat", flag; bool=Float64)
end
# The number types that go unmarked in a name, and numbers forced to them.
using LinearAlgebra: dot
struct Mass
    pos::SVector{3,Float64}
    mass::Float64
    count::Int32
end
halved(x::Float64) = x / 2
energy(m::Float64, v::SVector{3,Float64}) = halved(m * dot(v, v)) + 0.5
energy32(m::Float32, v::SVector{3,Float32}) = m * dot(v, v) / 2
advanced(b::Mass, dt::Float64) = Mass(b.pos + dt * b.pos, b.mass * 2.0, b.count + Int32(1))
small(x::Float32, n::Int8, u::UInt16) = sqrt(x) * n + u ÷ 3 + gcd(n, Int8(4))
squares(v::SVector{3,Float32}) = sum(x -> x^2, v) + sin(1.5)
twotypes(x::Float64, y::Float32) = halved(x) + halved(Float64(y))        # one Julia method at one type, called twice
flipped(x::Float64, on::Bool) = on ? x : -x
@testset "default types" begin
    v = SVector(1.0, 2.0, 3.0)
    # The real that goes unmarked: `Float64` unless told. Nothing but the names changes.
    plain = csource("realplain", energy, energy32, small)
    @test occursin("dot_3(v, v)", plain) && occursin("dot_3F32(v, v)", plain) && occursin("gcdI8(n, ", plain)
    single = csource("realsingle", energy, energy32, small; real=Float32)
    @test occursin("dot_3F64(v, v)", single) && occursin(r"m \* dot_3\(v, v\) / 2", single) && occursin("double energy(double m, const double v[3])", single)
    @test occursin("gcdI8(n, ", single)                                    # an integer helper answers to `int`
    @test occursin("gcd(n, ", csource("intsmall", small; int=Int8))        # and `Int8` unmarked when it is the default
    # Forced: every real the one real, every integer the one integer, in signatures, arrays, structs, numbers written out and helpers' names.
    src = check("forced", [Case(energy, 2.0, v), Case(advanced, Mass(v, 2.0, Int32(3)), 0.5), Case(small, 9f0, Int8(6), UInt16(10)),
                           Case(squares, SVector(1f0, 2f0, 3f0)), Case(twotypes, 3.0, 5f0), Case(flipped, 2.0, true), Case(flipped, 2.0, false)];
                force=true, real=Float32, int=Int32)
    @test occursin("float energy(float m, const float v[3]) {", src) && occursin("return halved(m * dot_3(v, v)) + 0.5f;", src)
    @test occursin("float small(float x, int32_t n, int32_t u) {", src) && occursin("return sqrtf(x) * n + u / 3 + gcd(n, 4);", src)
    @test occursin("result.mass = b.mass * 2.0f;", src) && occursin("result.count = b.count + 1;", src) && occursin("sinf(1.5f)", src)
    @test occursin("return halved(x) + halved(y);", src) && count("float halved(float x) {", src) == 1          # a conversion that converts nothing is gone
    @test occursin("float flipped(float x, bool on) {", src)                # a `Bool` is no number here: it has an option of its own
    @test !occursin("double", src) && !occursin("int8_t", src) && !occursin("uint16_t", src)
    # Forced to the defaults: `Float64` and `Int64` throughout.
    wide = check("forcedwide", [Case(small, 9f0, Int8(6), UInt16(10)), Case(squares, SVector(1f0, 2f0, 3f0))]; force=true)
    @test occursin("double small(double x, int64_t n, int64_t u) {", wide) && occursin("double squares(const double v[3]) {", wide) && !occursin("float", wide)
    @test_throws ArgumentError csource("realint", halved; real=Int64)
    @test_throws ArgumentError csource("intfloat", halved; int=Float64)
end

end
