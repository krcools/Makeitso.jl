# Makeitso.jl

Make-like behavior to facilitate writing long-running scripts. The idea is that the user supplies the dependencies between targets and recipes for how to make a target from those dependencies. If changes happen to one recipe (cf. if one edits one source file in a make project), only affected variables will be recomputed.

Upon computation, a backup is written to disk. This means that even when the work on the script is resumed in a different session (because you went home, julia crashed, you ran out of memory, you share the data with coworkers over e.g. Dropbox), only missing and out-of-date targets will be recomputed.

This saves a lot of time and unnecessary reruns of computations. It also relieves the programmer of having to track all dependencies and keep a clear picture of the workspace in their head.

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
println("--- Recipe for B modified! ---")

x = (@make D)[end]
@assert x ≈ (20+2pi)

```

This script describes the dependencies between targets `A,B,C,D`. Upon calling `@make D` all targets `D` depends on are built. Copies are written to disk in case we want to continue work in a future julia session. Assuming this is the first run ever (i.e. no copies on disk exist), the script results in the following output:

```
[ Info: level 1 dep A: computed from dependencies [initial computation].
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [initial computation].
[ Info: level 0 dep D: computed from dependencies [initial computation].
--- Recipe for B modified! ---
[ Info: level 1 dep A: retrieved from memory cache.
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [memory cache out-of-date].
[ Info: level 0 dep D: computed from dependencies [memory cache out-of-date]
```

Note in particular that modifiying target `B` has the desired effect of recomputing `B,C,D`. An immediate second run will not require `A` to be recomputed, but `B,C,D` will, because we reverted to the original recipe for `B`:

```
[ Info: level 1 dep A: retrieved from memory cache.
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [memory cache out-of-date].
[ Info: level 0 dep D: computed from dependencies [memory cache out-of-date].
--- Recipe for B modified! ---
[ Info: level 1 dep A: retrieved from memory cache.
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [memory cache out-of-date].
[ Info: level 0 dep D: computed from dependencies [memory cache out-of-date].
```

Likewise, killing the session and running the script again will see `A` restored from disk, but the other targets are recomputed twice (one for each version of the recipe for `B`):

```
Julia has exited. Press Enter to start a new session.
Starting Julia...
julia> include("examples/hello.jl")
[ Info: level 1 dep A: restored from disk.
[ Info: level 1 dep B: computed from dependencies [recipe modified].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [store out-of-date].
[ Info: level 0 dep D: computed from dependencies [store out-of-date].
--- Recipe for B modified! ---
[ Info: level 1 dep A: retrieved from memory cache.
[ Info: level 1 dep B: computed from dependencies [initial computation].
[ Info: level 2 dep A: retrieved from memory cache.
[ Info: level 2 dep B: retrieved from memory cache.
[ Info: level 1 dep C: computed from dependencies [memory cache out-of-date].
[ Info: level 0 dep D: computed from dependencies [memory cache out-of-date].
```

## Notes

* Recipe validity is tracked by storing the hash of the corresponding julia `Expr`
* The `@target` macro creates a variable `target_A` etc. in the module namespace, excluding these names as valid variable names in your script.
* Recipes resulting in `nothing` are not valid as `nothing` indicates absence of an in-memory cached value.
* Up-dates to *normal* non-target variables are not tracked and changes to them will not trigger recomputation of dependents. Functions taking zero arguments and returning a constant value are the appropriate way to allow for changeable parameters.
