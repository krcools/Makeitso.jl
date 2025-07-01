using Makeitso
using DataFrames

@target ore (;seeds) -> begin
    @show seeds
    return seeds .+ 1
end

@sweep solutions (ore, ;seed in seeds) -> begin
    @show seed
    return (;sol = sqrt(ore))
end

@target average (solutions,;seeds) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seeds=[1,2,3])
