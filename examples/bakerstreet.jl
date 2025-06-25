using Makeitso
using BakerStreet
using DataFrames

@target data (;seeds) -> begin
    function payload(;seed)
        println(seed)
        return (;sol=sqrt(seed + pi))
    end

    println(seeds)
    # @show @which runsims(payload, "solutions"; seed=seeds)
    # runsims(payload, "solutions"; seed=seeds)
    @runsims payload seed=seeds
end

@target average12 (data,;seeds)->sum(data.sol)

println(make(average12; seeds=collect(1:10)))