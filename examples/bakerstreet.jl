using Makeitso
using BakerStreet

using DrWatson
using DataFrames

@target solutions (;seeds) -> begin
    function payload(;seed)
        println(seed)
        return (;sol=sqrt(seed + pi))
    end
    runsims(payload, "bakerstreet/data.dir"; seed=seeds)
end

@target average (solutions,;seeds)->sum(solutions.sol)

println(make(average; seeds=collect(1:12)))


Makeitso.@sweep solutions (;seed in seeds) -> begin
    return (;sol= sqrt(seed + pi))
end

recipe = :( (A,B;a,bi in b, c) -> "solution" )
recipe = :( (;seed in seeds) -> "solution" )
xp = Makeitso.sweep_expr(:solutions, recipe)
