# deptfirst build
# test of filename for parameters that cannot be rendered as well

using Makeitso
using DataFrames

@target ore (;seeds) -> begin
    @show seeds
    return seeds .+ 1
end

@target solutions (ore, ;seeds) -> begin
    @show seeds
    return (;sol = sqrt.(ore))
end

@target average (solutions,;seeds) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seeds=[1,2,3])
make(average; seeds=[6,5,4])
