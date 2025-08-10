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

@target base () -> 10

module Mod
    function f(x)
        return x + 1
    end

    function square_root(x)
        return sqrt(x)
    end
end

@target ore (;seed, p) -> begin
    y= Mod.f(seed) + p
    return y
end

@sweep solutions (base, !ore, ;seed = seed, p) -> begin
    return (;sol = Mod.square_root(ore) + base)
end

@target average (solutions,;seed, p) -> begin
    sum(solutions.sol)
end

x = make(average; seed=[1.0,2.0,3.0], p=3.14)
y = make(solutions; seed=[1.0,2.0,3.0], p=3.14)

z1 = sweep(average; seed=Ref([1.0,2.0,3.0]), p=[2.78, 3.14])
z2 = sweep(average; seed=[[1.0,2.0,3.0], [4.0,5.0,6.0]], p=[2.78, 3.14])
```

The toplevel `@target` is `average`, which computes the sum of all entries in the column `sol` of the `DataFrame` computed by the `@sweep` `solutions`. The `@sweep` `solutions` has two dependencies: one named `base` which is shared among all iterations (which should and will only be computed once), and another named `ore` which depends on the swept over variable `seed`. Iteration specific dependencies are declared by an exclamation mark.

Running this script the first time in a new Julia session results in

```
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\average.63678zPY2rK.dir\p=3.14.CoXCiMub8Ro.jld2.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14.DxZMoriX5cF.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: target base at NamedTuple(): cache empty.
[ Info: target base at NamedTuple(): no backup at data\examples\sweep5\base.BrKrFd0kr39.dir\9hXKeOK7BYa.jld2.
[ Info: target base at NamedTuple(): cache empty.
[ Info: !!! target base at NamedTuple(): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 1.0): cache empty.
[ Info: iteration solutions at (seed = 1.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=1.0.4a4MWlZncdu.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): cache empty.
[ Info: target ore at (p = 3.14, seed = 1.0): cache empty.
[ Info: target ore at (p = 3.14, seed = 1.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=1.0.zNZMKtM5eu.jld2.
[ Info: target ore at (p = 3.14, seed = 1.0): cache empty.
[ Info: !!! target ore at (p = 3.14, seed = 1.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 1.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 2.0): parameters changed.
[ Info: iteration solutions at (seed = 2.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=2.0.K7yRD6aDT1W.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 2.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 2.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=2.0.H4R2N6UhyO.jld2.
[ Info: target ore at (p = 3.14, seed = 2.0): parameters changed.
[ Info: !!! target ore at (p = 3.14, seed = 2.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 2.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 3.0): parameters changed.
[ Info: iteration solutions at (seed = 3.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=3.0.5ykZTSxVHcI.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 3.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 3.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=3.0.8TEnXyWUMx2.jld2.
[ Info: target ore at (p = 3.14, seed = 3.0): parameters changed.
[ Info: !!! target ore at (p = 3.14, seed = 3.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 3.0): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 3 entries.
[ Info: !!! target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): computing from deps.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache up-to-date.
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\Ed6y2mjGtoh.jld2
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): cache empty.
[ Info: iteration average.sweep at (p = 2.78,): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): cache empty.
[ Info: target average at (p = 2.78, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: target average at (p = 2.78, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\average.63678zPY2rK.dir\p=2.78.1nF5HKz03Py.jld2.
[ Info: target average at (p = 2.78, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 2.78, :seed => [1.0, 2.0, 3.0]): parameters changed.
[ Info: sweep solutions at (p = 2.78, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78.HdKjxsMOmcr.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 2.78, :seed => [1.0, 2.0, 3.0]): parameters changed.
[ Info: target base at NamedTuple(): cache up-to-date.
[ Info: iteration solutions at (p = 2.78, seed = 1.0): parameters changed.
[ Info: iteration solutions at (seed = 1.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=1.0.3KQV8mN5Rhl.jld2
[ Info: iteration solutions at (p = 2.78, seed = 1.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 1.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 1.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=1.0.3IA3pEDIKAh.jld2.
[ Info: target ore at (p = 2.78, seed = 1.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 1.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 1.0): computing from deps.
[ Info: iteration solutions at (p = 2.78, seed = 2.0): parameters changed.
[ Info: iteration solutions at (seed = 2.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=2.0.5pavstnysqS.jld2
[ Info: iteration solutions at (p = 2.78, seed = 2.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 2.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 2.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=2.0.3ZOzuLvcGIY.jld2.
[ Info: target ore at (p = 2.78, seed = 2.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 2.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 2.0): computing from deps.
[ Info: iteration solutions at (p = 2.78, seed = 3.0): parameters changed.
[ Info: iteration solutions at (seed = 3.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=3.0.3xBcrncVwDs.jld2
[ Info: iteration solutions at (p = 2.78, seed = 3.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 3.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 3.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=3.0.8FHnvLU9m86.jld2.
[ Info: target ore at (p = 2.78, seed = 3.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 3.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 3.0): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 6 entries.
[ Info: !!! target average at (p = 2.78, seed = [1.0, 2.0, 3.0]): computing from deps.
[ Info: !!! iteration average.sweep at Dict(:p => 2.78): computing from deps.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): parameters changed.
[ Info: iteration average.sweep at (p = 3.14,): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): parameters changed.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.63678zPY2rK.dir\p=3.14.CoXCiMub8Ro.jld2.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache up-to-date.
[ Info: !!! iteration average.sweep at Dict(:p => 3.14): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 2 entries.
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\43CGkbnRcMc.jld2
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.7OlQWfYVHko.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: target average at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: target average at (p = 2.78, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\average.63678zPY2rK.dir\p=2.78.5hPMAUVKJFb.jld2.
[ Info: target average at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 2.78, :seed => [4.0, 5.0, 6.0]): parameters changed.
[ Info: sweep solutions at (p = 2.78, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78.90Nt8ootwAE.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 2.78, :seed => [4.0, 5.0, 6.0]): parameters changed.
[ Info: target base at NamedTuple(): cache up-to-date.
[ Info: iteration solutions at (p = 2.78, seed = 4.0): parameters changed.
[ Info: iteration solutions at (seed = 4.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=4.0.4l907SzgE7T.jld2
[ Info: iteration solutions at (p = 2.78, seed = 4.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 4.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 4.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=4.0.8KpxOdrOhEH.jld2.
[ Info: target ore at (p = 2.78, seed = 4.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 4.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 4.0): computing from deps.
[ Info: iteration solutions at (p = 2.78, seed = 5.0): parameters changed.
[ Info: iteration solutions at (seed = 5.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=5.0.BcRxkq47v75.jld2
[ Info: iteration solutions at (p = 2.78, seed = 5.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 5.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 5.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=5.0.4DH70LVr2lx.jld2.
[ Info: target ore at (p = 2.78, seed = 5.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 5.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 5.0): computing from deps.
[ Info: iteration solutions at (p = 2.78, seed = 6.0): parameters changed.
[ Info: iteration solutions at (seed = 6.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=2.78_seed=6.0.3Hd7aI1DeWL.jld2
[ Info: iteration solutions at (p = 2.78, seed = 6.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 6.0): parameters changed.
[ Info: target ore at (p = 2.78, seed = 6.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=2.78_seed=6.0.HwIz9PLreBb.jld2.
[ Info: target ore at (p = 2.78, seed = 6.0): parameters changed.
[ Info: !!! target ore at (p = 2.78, seed = 6.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 6.0): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 9 entries.
[ Info: !!! target average at (p = 2.78, seed = [4.0, 5.0, 6.0]): computing from deps.
[ Info: !!! iteration average.sweep at Dict{Symbol, Any}(:p => 2.78, :seed => [4.0, 5.0, 6.0]): computing from deps.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.4fg2RrLKQ4G.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: target average at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: target average at (p = 3.14, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\average.63678zPY2rK.dir\p=3.14.6blorQZib97.jld2.
[ Info: target average at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [4.0, 5.0, 6.0]): parameters changed.
[ Info: sweep solutions at (p = 3.14, seed = [4.0, 5.0, 6.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14.G1pA6VpUbNo.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [4.0, 5.0, 6.0]): parameters changed.
[ Info: target base at NamedTuple(): cache up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 4.0): parameters changed.
[ Info: iteration solutions at (seed = 4.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=4.0.EWXe5G4FB3Z.jld2
[ Info: iteration solutions at (p = 3.14, seed = 4.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 4.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 4.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=4.0.4XHk9VI5czL.jld2.
[ Info: target ore at (p = 3.14, seed = 4.0): parameters changed.
[ Info: !!! target ore at (p = 3.14, seed = 4.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 4.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 5.0): parameters changed.
[ Info: iteration solutions at (seed = 5.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=5.0.230IfUT4MQy.jld2
[ Info: iteration solutions at (p = 3.14, seed = 5.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 5.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 5.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=5.0.KFCTtJy5XEo.jld2.
[ Info: target ore at (p = 3.14, seed = 5.0): parameters changed.
[ Info: !!! target ore at (p = 3.14, seed = 5.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 5.0): computing from deps.
[ Info: iteration solutions at (p = 3.14, seed = 6.0): parameters changed.
[ Info: iteration solutions at (seed = 6.0,): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=6.0.FoXrrIT8wAW.jld2
[ Info: iteration solutions at (p = 3.14, seed = 6.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 6.0): parameters changed.
[ Info: target ore at (p = 3.14, seed = 6.0): no backup at data\examples\sweep5\ore.CrdBumEWCwZ.dir\p=3.14_seed=6.0.9YzboOuffEc.jld2.
[ Info: target ore at (p = 3.14, seed = 6.0): parameters changed.
[ Info: !!! target ore at (p = 3.14, seed = 6.0): computing from deps.
[ Info: !!! iteration solutions at Dict(:seed => 6.0): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 12 entries.
[ Info: !!! target average at (p = 3.14, seed = [4.0, 5.0, 6.0]): computing from deps.
[ Info: !!! iteration average.sweep at Dict{Symbol, Any}(:p => 3.14, :seed => [4.0, 5.0, 6.0]): computing from deps.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 4 entries.
4×3 DataFrame
 Row │ average   seed             p        
     │ Float64?  Array…?          Float64?
─────┼─────────────────────────────────────
   1 │  38.8797  [4.0, 5.0, 6.0]      2.78
   2 │  37.1943  [1.0, 2.0, 3.0]      2.78
   3 │  39.0606  [4.0, 5.0, 6.0]      3.14
   4 │  37.4171  [1.0, 2.0, 3.0]      3.14
```

This output is rather verbose, but the important part are the lines containing `!!!`, indicating acutal  computations. Asking to make target `average` results in 9 computations: 1 copy of `base`, 3 of `ore` (for the 3 values of `seed`), 3 where `base` and `ore` are processed in the iterations for sweep `solution`, 1 for solution itself, which collects the information computed in its iterations, and finally one for the toplevel target `average`.

Note that when explicitly making the sweep `solutions`, no new computations are triggered, since all required results are computed already by making `average`.

The last two lines ask for `average` to be built w.r.t. a range of parameters. This could have been achieved by defining another `@sweep`, but because this scenario is so common, it is supported in this lightweight format as well. The `sweep` function used a heuristic to determine which of the keyword arguments are to be considered _atomic_ parameters, and which to be considered variable ranges. Iterable containers meant as parameters should be protected by boxing them in a `Ref`.

Upon completion the contents of `DrWatson.datadir()` will look like this:

```
└───examples
    ├───algo1
    │   ├───algo.5Y5boI4Y5YW.dir
    │   └───algo.GElrzKDPE2t.dir
    ├───hello
    │   ├───A.17171136936184495823.dir
    │   ├───B.12519468891243541516.dir
    │   ├───B.13395166280708594831.dir
    │   ├───C.15360683730267352014.dir
    │   ├───C.17987775898662511959.dir
    │   ├───D.17289309569934157171.dir
    │   └───D.3868354253241197441.dir
    ├───inputs1
    │   └───input.BrKrFd0kr39.dir
    ├───inputs2
    │   └───input.FcfX3HzrEjm.dir
    ├───params
    │   ├───A.1048535322258453061.dir
    │   ├───B.14336788928509918508.dir
    │   ├───B.15488351015771593206.dir
    │   ├───C.12735428060590766293.dir
    │   ├───C.16190114322375790387.dir
    │   ├───D.13619359724233510674.dir
    │   └───D.6579483135526923798.dir
    ├───params2
    │   ├───A.15245690565313990735.dir
    │   ├───B.478396206930035304.dir
    │   └───C.16138613138270301665.dir
    ├───params3
    │   ├───A.12993895845110424235.dir
    │   ├───B.7233780367540734804.dir
    │   └───C.7665541436761705068.dir
    ├───params4
    │   ├───A.15245690565313990735.dir
    │   ├───B.498605587738026360.dir
    │   └───C.4656133660043096536.dir
    ├───sweep
    │   ├───average.6927412273851932204.dir
    │   └───solutions.2021731420090844376.dir
    ├───sweep2
    │   ├───average.8556888268172572070.dir
    │   ├───ore.1675915613269632117.dir
    │   └───solutions.6874929957534190746.dir
    ├───sweep3
    │   ├───average.3661881455838019953.dir
    │   ├───ore.3808047874501286615.dir
    │   └───solutions.1452067140952804965.dir
    ├───sweep4
    │   ├───average.15216166707148747960.dir
    │   ├───base.9954312946933418887.dir
    │   ├───ore.1675915613269632117.dir
    │   └───solutions.10230478802174878851.dir
    └───sweep5
        ├───average.63678zPY2rK.dir
        ├───average.sweep.6Lh9bApq4vd.dir
        ├───base.BrKrFd0kr39.dir
        ├───ore.CrdBumEWCwZ.dir
        └───solutions.1YvXce9RGRZ.dir
```

A second run of the scripts results in:

```
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.63678zPY2rK.dir\p=3.14.CoXCiMub8Ro.jld2.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache up-to-date.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): parameters changed.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14.DxZMoriX5cF.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): parameters changed.
[ Info: target base at NamedTuple(): cache up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 1.0): parameters changed.
[ Info: iteration solutions at (seed = 1.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=1.0.4a4MWlZncdu.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 2.0): parameters changed.
[ Info: iteration solutions at (seed = 2.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=2.0.K7yRD6aDT1W.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 3.0): parameters changed.
[ Info: iteration solutions at (seed = 3.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=3.0.5ykZTSxVHcI.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 12 entries.
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\Ed6y2mjGtoh.jld2
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): cache empty.
[ Info: iteration average.sweep at (p = 2.78,): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): up-to-date.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): parameters changed.
[ Info: iteration average.sweep at (p = 3.14,): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 4 entries.
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\43CGkbnRcMc.jld2
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.7OlQWfYVHko.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): up-to-date.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.4fg2RrLKQ4G.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 4 entries.
4×3 DataFrame
 Row │ average   seed             p        
     │ Float64?  Array…?          Float64?
─────┼─────────────────────────────────────
   1 │  38.8797  [4.0, 5.0, 6.0]      2.78
   2 │  37.1943  [1.0, 2.0, 3.0]      2.78
   3 │  39.0606  [4.0, 5.0, 6.0]      3.14
   4 │  37.4171  [1.0, 2.0, 3.0]      3.14
```

This time around, no computations were performed at all!

Let's kill julia and run the file again:

```
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.63678zPY2rK.dir\p=3.14.CoXCiMub8Ro.jld2.
[ Info: target average at (p = 3.14, seed = [1.0, 2.0, 3.0]): cache up-to-date.
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: sweep solutions at (p = 3.14, seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14.DxZMoriX5cF.jld2
[ Info: Sweep solutions at Dict{Symbol, Any}(:p => 3.14, :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: target base at NamedTuple(): cache empty.
[ Info: target base at NamedTuple(): read data\examples\sweep5\base.BrKrFd0kr39.dir\9hXKeOK7BYa.jld2.
[ Info: target base at NamedTuple(): cache up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 1.0): cache empty.
[ Info: iteration solutions at (seed = 1.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=1.0.4a4MWlZncdu.jld2
[ Info: iteration solutions at (p = 3.14, seed = 1.0): up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 2.0): parameters changed.
[ Info: iteration solutions at (seed = 2.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=2.0.K7yRD6aDT1W.jld2
[ Info: iteration solutions at (p = 3.14, seed = 2.0): up-to-date.
[ Info: iteration solutions at (p = 3.14, seed = 3.0): parameters changed.
[ Info: iteration solutions at (seed = 3.0,): read data\examples\sweep5\solutions.1YvXce9RGRZ.dir\p=3.14_seed=3.0.5ykZTSxVHcI.jld2
[ Info: iteration solutions at (p = 3.14, seed = 3.0): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\solutions.1YvXce9RGRZ.dir for result files.
[ Info: Added 12 entries.
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [1.0, 2.0, 3.0]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\Ed6y2mjGtoh.jld2
[ Info: Sweep average.sweep at Dict(:p => [2.78, 3.14], :seed => [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): cache empty.
[ Info: iteration average.sweep at (p = 2.78,): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 2.78): up-to-date.
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): parameters changed.
[ Info: iteration average.sweep at (p = 3.14,): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (seed = [1.0, 2.0, 3.0], p = 3.14): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 4 entries.
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: sweep average.sweep at (p = [2.78, 3.14], seed = [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): no backup at data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\43CGkbnRcMc.jld2
[ Info: Sweep average.sweep at Dict{Symbol, Vector}(:p => [2.78, 3.14], :seed => [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): cache empty.
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.J7GFC87U3Fh.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.824AT3Qr5iR.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [1.0, 2.0, 3.0]): up-to-date.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=2.78.7OlQWfYVHko.jld2
[ Info: iteration average.sweep at (p = 2.78, seed = [4.0, 5.0, 6.0]): up-to-date.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): parameters changed.
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): read data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir\p=3.14.4fg2RrLKQ4G.jld2
[ Info: iteration average.sweep at (p = 3.14, seed = [4.0, 5.0, 6.0]): up-to-date.
[ Info: Scanning folder c:\Users\krcools\.julia\dev\Makeitso\data\examples\sweep5\average.sweep.6Lh9bApq4vd.dir for result files.
[ Info: Added 4 entries.
4×3 DataFrame
 Row │ average   seed             p        
     │ Float64?  Array…?          Float64?
─────┼─────────────────────────────────────
   1 │  38.8797  [4.0, 5.0, 6.0]      2.78
   2 │  37.1943  [1.0, 2.0, 3.0]      2.78
   3 │  39.0606  [4.0, 5.0, 6.0]      3.14
   4 │  37.4171  [1.0, 2.0, 3.0]      3.14
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
