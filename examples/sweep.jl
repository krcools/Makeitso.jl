using Makeitso
using DataFrames


@sweep solutions (;seed = seeds) -> begin
    return (;sol= sqrt(seed + pi))
end

@target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

a = make(average; seed=[1.0,2.0,3.0])
b = make(average; seed=[3.0, 4.0])


Base.remove_linenums!(@macroexpand @target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end)

nothing

# Improvement: first check if the sweep is up-to-date before loading all deps from disk