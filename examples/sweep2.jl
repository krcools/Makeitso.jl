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

@sweep solutions (!ore, ;seed in seeds, p) -> begin
    @show seed
    return (;sol = Mod.square_root(ore))
end

@target average (solutions,;seeds, p) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

df = make(solutions; seeds=[1,2,3], p=π)
x = make(average; seeds=[1,2,3], p=π)
@assert x ≈ 5.146264369941973

Base.remove_linenums!(@macroexpand @sweep solutions (!ore, ;seed in seeds, p) -> begin
    @show seed
    return (;sol = Mod.square_root(ore))
end)