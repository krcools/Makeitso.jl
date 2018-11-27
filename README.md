# JLMake.jl

Make like behavior to facilitate writing long-running scripts

## Example

```julia
using Makeitso

@target A ()->1:10
@target B ()->[-4,-3,-2,-1,0,1,2,3,4,5]
@target C (A,B)->A.+B


@target D (A,B,C)->A.+B.+C

x = (@make D)[end]

@assert x == 30
@target B ()->pi

x = (@make D)[end]
@assert x ≈ (20+2pi)
```

This script describes the dependencies between targets `A,B,C,D`. Upon calling `@make D` all targets are built depth first. Copies are written to disk in case we want to continue work in a future julia session. Assuming this is the first run ever (i.e. no copies on disk exist), the script results in the following output:

```
[ Info: level 1 dep A: computed from dependencies [initial computation].
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [initial computation].
[ Info: level 0 dep D: computed from dependencies [initial computation].
[ Info: level 1 dep A: retrieved from memory cache.
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [memory cache out-of-date].
[ Info: level 0 dep D: computed from dependencies [memory cache out-of-date].
```

Note in particular that modifiying target `B` has the desired effect of recomputing `B,C,D`.
