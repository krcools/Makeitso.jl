using Makeitso
using DataFrames

@target ore (;seed) -> begin
    @show seed
    return seed + 1
end

@sweep solutions (!ore, ;seed in seed) -> begin
    @show seed
    # @show ore
    # c = make(;seed=seed)
    return (;sol = sqrt(temp))
end

@target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seed=[1,2,3])


# recipe = :( (A,!B;a, b in B, c) -> "solution" )
# xp = Makeitso.sweep_expr(:solutions, recipe)

# @show xp