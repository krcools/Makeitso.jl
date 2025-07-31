# Makeitso.jl

Make-like behavior to facilitate writing long-running scripts. The idea is that the user supplies the dependencies between targets and recipes for how to make a target from those dependencies. If changes happen to one recipe (cf. if one edits one source file in a make project), only affected variables will be recomputed.

Upon computation, a backup is written to disk. This means that even when the work on the script is resumed in a different session (because you went home, julia crashed, you ran out of memory, you share the data with coworkers over e.g. Dropbox), only missing and out-of-date targets will be recomputed.

This saves a lot of time and unnecessary reruns of computations. It also relieves the programmer of having to track all dependencies and keep a clear picture of the workspace in their head.

Files for backups are based of the hash of both the target recipe and the parameter values at which the build is requested. This allows for multiple versions to coexist on disk, leading to a further reduction of the number of computed variables.

Makeitso suppports the computation of atomic targets and of sweeps over the Cartesian product of provided variable ranges. The return value of such a `@sweep` should always be a named tuple. Upon building, sweeps return a `DataFrame` with one row for each value of the set of variables that were swept over. The columns of the `DataFrame` will correspond to the fields of the returned named tuple. In addition, the parameter values used for each iteration of the sweep will be included as well. The following names currently cannot be used as either parameter names or field names in the returned value of the sweep recipe: `[timestamp, hash, tree_hash, path, params]`.

## Example

Consider the script in file `DrWatson.projectdir("examples","sweep4.jl")`

```julia
using Makeitso

module Mod
    function f(x)
        return x + 1
    end
    function square_root(x)
        return sqrt(x)
    end
end

@target base () -> 10

@target ore (;seed, p) -> begin
    y= Mod.f(seed)
    return y
end

@sweep solutions (base, !ore, ;seed = seed, p) -> begin
    return (;sol = Mod.square_root(ore) + base)
end

@target average (solutions,;seed, p) -> begin
    sum(solutions.sol)
end

@show x = make(average; seed=[1.0,2.0,3.0], p=3.14)
@show y = make(solutions; seed=[1.0,2.0,3.0], p=3.14)
```

The toplevel `@target` is `average`, which computes the sum of all entries in the column `sol` of the `DataFrame` computed by the `@sweep` `solutions`. The `@sweep` `solutions` has two dependencies: one named `base` which is shared among all iterations (which should and will only be computed once), and another named `ore` which depends on the swept over variable `seed`. Iteration specific dependencies are declared by an exclamation mark.

Running this script the first time in a new Julia session results in

```
[ Info: target base at NamedTuple(): cache not valid.
[ Info: target base at NamedTuple(): no backup found.
[ Info: target base at NamedTuple(): cache empty.
[ Info: !!! target base at NamedTuple(): computing from deps.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): no backup found.
[ Info: target ore at (p = 3.14, seed = 1.0): cache empty.
[ Info: !!! target ore at (p = 3.14, seed = 1.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 1.0): cache not available.
[ Info: !!! iteration solutions at Dict(:seed => 1.0): computing from deps.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): no backup found.
[ Info: target ore at (p = 3.14, seed = 2.0): cache empty.
[ Info: !!! target ore at (p = 3.14, seed = 2.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 2.0): cache not available.
[ Info: !!! iteration solutions at Dict(:seed => 2.0): computing from deps.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): no backup found.
[ Info: target ore at (p = 3.14, seed = 3.0): cache empty.
[ Info: !!! target ore at (p = 3.14, seed = 3.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 3.0): cache not available.
[ Info: !!! iteration solutions at Dict(:seed => 3.0): computing from deps.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache not valid.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): not cached in memory.
[ Info: !!! sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): computing from deps.
[ Info: Scanning folder data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir for result files.
[ Info: Added 3 entries.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache not valid.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): no backup found.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: !!! target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): computing from deps.
x = make(average; seed = [1.0, 2.0, 3.0], p = 3.14) = 35.146264369941974
[ Info: target base at NamedTuple(): cache is up-to-date.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): loaded from data\examples\sweep4\ore.p=3.14_seed=1.0.10155953109734089458.jld2
[ Info: target ore at (p = 3.14, seed = 1.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 1.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=1.0.10313548746577572791.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): loaded from data\examples\sweep4\ore.p=3.14_seed=2.0.9556143532797230738.jld2
[ Info: target ore at (p = 3.14, seed = 2.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 2.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=2.0.967288288172012261.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): loaded from data\examples\sweep4\ore.p=3.14_seed=3.0.16435246169964622506.jld2
[ Info: target ore at (p = 3.14, seed = 3.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 3.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=3.0.16301960159939599385.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
y = make(solutions; seed = [1.0, 2.0, 3.0], p = 3.14) = 3×4 DataFrame
 Row │ sol       tree_hash             p         seed
     │ Float64?  UInt64?               Float64?  Float64?
─────┼────────────────────────────────────────────────────
   1 │  11.4142  10230478802174878851      3.14       1.0
   2 │  11.7321  10230478802174878851      3.14       2.0
   3 │  12.0     10230478802174878851      3.14       3.0
```

This output is rather verbose, but the important part are the lines containing `!!!`, indicating acutal  computations. Asking to make target `average` results in 9 computations: 1 copy of `base`, 3 of `ore` (for the 3 values of `seed`), 3 where `base` and `ore` are processed in the iterations for sweep `solution`, 1 for solution itself, which collects the information computed in its iterations, and finally one for the toplevel target `average`.

Note that when explicitly making the sweep `solutions`, no new computations are triggered, since all required results are computed already by making `average`.

Upon completion the contents of `DrWatson.datadir()` will look like this:

```
└───examples
    └───sweep4
        │   average.p=3.14.2447376696785551322.jld2
        │   base.8143066964374671252.jld2
        │   ore.p=3.14_seed=1.0.10155953109734089458.jld2
        │   ore.p=3.14_seed=2.0.9556143532797230738.jld2
        │   ore.p=3.14_seed=3.0.16435246169964622506.jld2
        │   solutions.p=3.14.2188912756489576653.jld2
        │
        └───solutions.p=3.14.6542551602648920450.dir
                seed=1.0.10313548746577572791.jld2
                seed=2.0.967288288172012261.jld2
                seed=3.0.16301960159939599385.jld2
```

A second run of the scripts results in:

```
[ Info: target base at NamedTuple(): cache is up-to-date.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): loaded from data\examples\sweep4\ore.p=3.14_seed=1.0.10155953109734089458.jld2
[ Info: target ore at (p = 3.14, seed = 1.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 1.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=1.0.10313548746577572791.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): loaded from data\examples\sweep4\ore.p=3.14_seed=2.0.9556143532797230738.jld2
[ Info: target ore at (p = 3.14, seed = 2.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 2.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=2.0.967288288172012261.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): loaded from data\examples\sweep4\ore.p=3.14_seed=3.0.16435246169964622506.jld2
[ Info: target ore at (p = 3.14, seed = 3.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 3.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=3.0.16301960159939599385.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
x = make(average; seed = [1.0, 2.0, 3.0], p = 3.14) = 35.146264369941974
[ Info: target base at NamedTuple(): cache is up-to-date.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): loaded from data\examples\sweep4\ore.p=3.14_seed=1.0.10155953109734089458.jld2
[ Info: target ore at (p = 3.14, seed = 1.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 1.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=1.0.10313548746577572791.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): loaded from data\examples\sweep4\ore.p=3.14_seed=2.0.9556143532797230738.jld2
[ Info: target ore at (p = 3.14, seed = 2.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 2.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=2.0.967288288172012261.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): loaded from data\examples\sweep4\ore.p=3.14_seed=3.0.16435246169964622506.jld2
[ Info: target ore at (p = 3.14, seed = 3.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 3.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=3.0.16301960159939599385.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
y = make(solutions; seed = [1.0, 2.0, 3.0], p = 3.14) = 3×4 DataFrame
 Row │ sol       tree_hash             p         seed
     │ Float64?  UInt64?               Float64?  Float64?
─────┼────────────────────────────────────────────────────
   1 │  11.4142  10230478802174878851      3.14       1.0
   2 │  11.7321  10230478802174878851      3.14       2.0
   3 │  12.0     10230478802174878851      3.14       3.0
```

This time around, no computations were performed at all! Since targets like `base` and `ore` only allow for a single copy to exist in memory, some disk loading needed to be done to accomodate this reconstruction.

Let's kill julia and run the file again:

```
[ Info: target base at NamedTuple(): cache not valid.
[ Info: target base at NamedTuple(): loaded from data\examples\sweep4\base.8143066964374671252.jld2
[ Info: target base at NamedTuple(): cache is up-to-date.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): loaded from data\examples\sweep4\ore.p=3.14_seed=1.0.10155953109734089458.jld2
[ Info: target ore at (p = 3.14, seed = 1.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 1.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=1.0.10313548746577572791.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): loaded from data\examples\sweep4\ore.p=3.14_seed=2.0.9556143532797230738.jld2
[ Info: target ore at (p = 3.14, seed = 2.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 2.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=2.0.967288288172012261.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): loaded from data\examples\sweep4\ore.p=3.14_seed=3.0.16435246169964622506.jld2
[ Info: target ore at (p = 3.14, seed = 3.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 3.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=3.0.16301960159939599385.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache not valid.
[ Info: Sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): loaded from data\examples\sweep4\solutions.p=3.14.2188912756489576653.jld2
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache not valid.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): loaded from data\examples\sweep4\average.p=3.14.2447376696785551322.jld2
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
x = make(average; seed = [1.0, 2.0, 3.0], p = 3.14) = 35.146264369941974
[ Info: target base at NamedTuple(): cache is up-to-date.
[ Info: target ore at (p = 3.14, seed = 1.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 1.0): loaded from data\examples\sweep4\ore.p=3.14_seed=1.0.10155953109734089458.jld2
[ Info: target ore at (p = 3.14, seed = 1.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 1.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=1.0.10313548746577572791.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 2.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 2.0): loaded from data\examples\sweep4\ore.p=3.14_seed=2.0.9556143532797230738.jld2
[ Info: target ore at (p = 3.14, seed = 2.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 2.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=2.0.967288288172012261.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: target ore at (p = 3.14, seed = 3.0): cache not valid.
[ Info: target ore at (p = 3.14, seed = 3.0): loaded from data\examples\sweep4\ore.p=3.14_seed=3.0.16435246169964622506.jld2
[ Info: target ore at (p = 3.14, seed = 3.0): cache is up-to-date.
[ Info: iteration solutions at (seed = 3.0,): loaded from data\examples\sweep4\solutions.p=3.14.6542551602648920450.dir\seed=3.0.16301960159939599385.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache is up-to-date.
y = make(solutions; seed = [1.0, 2.0, 3.0], p = 3.14) = 3×4 DataFrame
 Row │ sol       tree_hash             p         seed
     │ Float64?  UInt64?               Float64?  Float64?
─────┼────────────────────────────────────────────────────
   1 │  11.4142  10230478802174878851      3.14       1.0
   2 │  11.7321  10230478802174878851      3.14       2.0
   3 │  12.0     10230478802174878851      3.14       3.0
```

Now, all information has to be loaded from disk, but no new computations were required, since these have been done in the previous session.

## Notes

* The `@target` macro creates a variable `A` etc which has type `Target` and should not be used to hold the result of building target A. This is by design to discourage creating *untracked* variables. Similarly, `@sweep S` creates a variable `S` of type `Sweep`. 
* Recipes resulting in `nothing` are not valid as `nothing` indicates absence of an in-memory cached value.
* The correct way to supply parameters is to use keywords. For example `make(D; p=314)` will propagate this keyword to all recipes of `D` and its dependencies. See `examples/hello_kw.jl` for details. 
* The recipe supplied to `@target` and `@sweep` are hashed and this hash is used to track any changes done to the code, which would invalidate the computed values and all values that depend on them. This system can of course be fooled easily by having the recipes rely on untracked code. Perhaps in the future a pedantic mode can be introduced forcing the user the work in a clean git directory with a manifest containing only versioned dependencies.
* For savename generation and the collection of results files to build the `DataFrame` computed by `@sweep`, the package relies on `DrWatson`.
* `@target memonly=true A () -> 3` creates a target that does not write backups to disk. This will in general results in more computations, but it will avoid (especially in sweeps) that the disk is flooded by large intermediary results.
* A space is required between the target name and the parentheses containing the dependencies. In other words, the macro takes two arguments (or more if options are supplied) 
