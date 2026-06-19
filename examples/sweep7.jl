#test joint storage for targets and sweeps
using Makeitso

@target A (;h) -> 2h

A2 = make(A; h=2)
As = sweep(A; h=[1,2,3])
