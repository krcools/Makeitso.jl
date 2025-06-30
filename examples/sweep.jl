using Makeitso
using DataFrames

Makeitso.@sweep solutions (;seed in seeds) -> begin
    return (;sol= sqrt(seed + pi))
end

@target average (solutions,;seeds) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seeds=[1,2,3])