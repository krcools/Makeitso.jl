using Makeitso
using BakerStreet

using DataFrames

@target data (;seeds) -> begin
    function payload(;seed)
        println(seed)
        return (;sol=sqrt(seed + pi))
    end
    runsims(payload, "bakerstreet/data.dir"; seed=seeds)
end

@target average (data,;seeds)->sum(data.sol)

println(make(average; seeds=collect(1:12)))