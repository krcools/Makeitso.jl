using Makeitso
using DataFrames

module Mod
    function f(x)
        return x + 1
    end

    function square_root(x)
        return sqrt(x)
    end
end

@target ore (;seed, p) -> begin
    @show seed
    @show p
    y= Mod.f(seed)
    return y
end

@sweep solutions (!ore, ;seed = seeds, p) -> begin
    @show seed
    return (;sol = Mod.square_root(ore))
end

@target average (solutions,;seed, p) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

@target base () -> 10

df = make(solutions; seed=[1.0,2.0,3.0], p=3.14)
x = make(average; seed=[1.0,2.0,3.0], p=3.14)
# @assert x ≈ 5.146264369941973
@show x

Base.remove_linenums!(@macroexpand @sweep solutions (base, !ore, ;seed = seeds, p) -> begin
    @show seed
    return (;sol = base + Mod.square_root(ore))
end)

nothing