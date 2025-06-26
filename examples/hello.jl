using Makeitso

@target A ()->1:10
@target B ()->[-4,-3,-2,-1,0,1,2,3,4,5]
@target C (A,B)->A.+B
@target D (A,B,C)->A.+B.+C

x = make(D)[end]
@assert x == 30

@target B ()->pi
println("--- Recipe for B modified! ---")

x = make(D)[end]
@assert x ≈ (20+2pi)


