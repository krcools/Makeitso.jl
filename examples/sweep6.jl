# Example of a multi-parameter sweep
using Makeitso

@target seed () -> 1.0
@target solution (;h, k) -> h + k
@sweep sims (seed, !solution; h = [], k = []) -> (;sol=seed + solution)


make(sims; h=[1.0,2.0,3.0], k=[30.0,40.0])