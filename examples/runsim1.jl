# the same target used in two dep-trees should not save to the same file

using Makeitso

module M1
include("inputs1.jl")
include("algo1.jl")
end

module M2
include("inputs2.jl")
include("algo1.jl")
end

x1 = make(M1.algo)
x2 = make(M2.algo)

@assert x1 == 20
@assert x2 == 40

x1 = make(M1.algo)
x2 = make(M2.algo)

@assert x1 == 20
@assert x2 == 40
