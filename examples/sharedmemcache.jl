using Makeitso
using Test

module SharedPart
using Makeitso
export base
numbuilds = [0]
@target base () -> begin
    println("Computing base")
    numbuilds[1] += 1
    3
end
end

SharedPart.numbuilds[1] = 0

module Sim1
using ..SharedPart
using Makeitso
@target product (base) -> base^2
end

module Sim2
using ..SharedPart
using Makeitso
@target product (base) -> base^3
end

x1 = make(Sim1.product)
x2 = make(Sim2.product)

@test x1 == 9
@test x2 == 27
@test SharedPart.numbuilds[1] < 2
