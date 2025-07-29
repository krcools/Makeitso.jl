# test the combination of shared and iteration dependencies

using Makeitso
# using DataFrames

@target base () -> 10

module Mod
    function f(x)
        return x + 1
    end

    function square_root(x)
        return sqrt(x)
    end
end

@target ore (;seed, p) -> begin
    y= Mod.f(seed)
    return y
end

@sweep solutions (base, !ore, ;seed = seed, p) -> begin
    return (;sol = Mod.square_root(ore) + base)
end

@target average (solutions,;seed, p) -> begin
    # println(length(solutions.sol))
    sum(solutions.sol)
end




@show x = make(average; seed=[1.0,2.0,3.0], p=3.14)
@show y = make(solutions; seed=[1.0,2.0,3.0], p=3.14)
# @assert x ≈ 5.146264369941973

# Base.remove_linenums!(@macroexpand @sweep2 solutions (base, !ore, ;seed = seeds, p) -> begin
#     @show seed
#     return (;sol = base + Mod.square_root(ore))
# end)

# df = make(solutions; seed=[1.0,2.0,3.0], p=3.14)
