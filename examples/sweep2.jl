using Makeitso
using DataFrames

@target ore (;seed) -> begin
    @show seed
    return seed + 1
end

@sweep solutions (!ore, ;seed in seed) -> begin
    @show seed
    return (;sol = sqrt(ore))
end

@target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seed=[1,2,3])
