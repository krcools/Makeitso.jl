using Makeitso
using DataFrames

@target bigchunk (;seed) -> begin
    @show seed
    return (;ore = seed + 1)
end

@sweep solutions (bigchunk, ;seed in seed) -> begin
    @show seed
    # c = make(;seed=seed)
    return (;sol = sqrt(r.ore))
end

@target average (solutions,;seed) -> begin
    println(length(solutions.sol))
    sum(solutions.sol)
end

make(average; seed=[1,2,3])


# recipe = :( (A,B;a,bi in b, c) -> "solution" )
# recipe = :( (;seed in seeds) -> "solution" )
# xp = Makeitso.sweep_expr(:solutions, recipe)
# nothing