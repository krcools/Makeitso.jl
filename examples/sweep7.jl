#test joint storage for targets and sweeps
using Makeitso
using DataFrames

@target A (;h, p) -> 2h + p

A2 = make(A; h=2, p=5)
As = sweep(A, over(:h); h=[1,2,3], p=5)
A4 = make(A; h=4, p=5)

df = Makeitso.collect(A)

