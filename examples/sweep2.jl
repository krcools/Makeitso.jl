using Makeitso
using DataFrames

@target ore (;seed, p) -> begin
    @show seed
    @show p
    return seed + 1
end

@sweep solutions (!ore, ;seed in seeds, p) -> begin
    @show seed
    return (;sol = sqrt(ore))
end

@target average (solutions,;seeds, p) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

df = make(solutions; seeds=[1,2,3], p=π)
make(average; seeds=[1,2,3], p=π)

Base.remove_linenums!(@macroexpand @sweep solutions (!ore, ;seed in seeds, p) -> begin
    @show seed
    return (;sol = sqrt(ore))
end)