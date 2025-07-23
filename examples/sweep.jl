using Makeitso
using DataFrames


@sweep solutions (;seed = seeds) -> begin
    return (;sol= sqrt(seed + pi))
end

@target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

a = make(average; seed=[1,2,3])


Base.remove_linenums!(@macroexpand @target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end)

nothing

# Improvement: first check if the sweep is up-to-date before loading all deps from disk