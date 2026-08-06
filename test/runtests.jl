using Makeitso
using Test
using DataFrames

@target A ()->1:10
@target B ()->[-4,-3,-2,-1,0,1,2,3,4,5]
@target C (A,B)->A.+B
@target D (A,B,C)->A.+B.+C

x = make(D)[end]
@test x == 30

@target B ()->pi
println("--- Recipe for B modified! ---")

x = make(D)[end]
@test x ≈ (20+2pi)

@target W1 (;h) -> h + 1
@target W2 (;p) -> p + 2

@target WTarget (~W1, ~W2; h, p) -> W1 + W2
@test make(WTarget; h=3, p=10) == 16

@sweep WSweep (~W1, ~W2; h = [], p = []) -> (;result=W1 + W2, h=h, p=p)
df = make(WSweep; h=[1, 2], p=[10, 20])

expected = Set([(h=1, p=10, result=14), (h=1, p=20, result=24), (h=2, p=10, result=15), (h=2, p=20, result=25)])
observed = Set([(h=r.h, p=r.p, result=r.result) for r in eachrow(df)])
@test observed == expected
