- Fixed bug where parameters for weak dependencies where not propagated to their dependents
- Only load requested iterations for sweeps (instead of loading all and then filtering the DF)
- Methods `sweep(target, over; pars...)` for the ad-hoc creation of sweeps

# Version 3.0

- [BREAKING]: updated compat section might mean that computed hashes differ and that outputs stored by a previous version of `Makeitso` might not be found automatically.
- Support for weak dependencies. Weak dependencies are indicated by a tilde in front of their name in the dependency specification. When making the depending target, they are not automatically recursively made, but their recipe is included in the recursive computation of the target hash. This means that changes in the recipe for the weak dependencies will result in invalidation of results for the dependant. Weak dependencies can be used in the recipe of the dependant by explicitly calling `make`. This allows for runtime branching in the dependency tree and for generic parameter transformations. For more information, see `examples/weakdepsi.jl`

# Version 2.2.1

- Expand colorscheme: blue is cached, purple is on-disk, amber is compute.

# Version 2.2

- Fix parsing issues on Julia 1.12

# Version 2.1

- Support parameter transformation. This allows a single target to be built against different parameter values. It is now even possible to on one hand build a sweep and on the other hand build a single instantiation. The motivating example is convergence analyysis for numerical methods. This requires a reference solution that plays a distinct role in the build process. See `examples/errors.jl` for how to use this feature.

# Version 2.0

- Support for the very common case of sweeps for a top level target without the necessity to make an explicit `Sweep`.
- Hashes are represented in base 62 to shorten filenames
- Dirnames are now based on just the tree recipe, filenames on the parameters

# Version 1.1

- Deep dependencies are not constructed if a valid cache or backup is available for
the toplevel target
- Introduction of options `memonly` for the `@target` macro disables writing backups
to disk.

# Version 1.0

- Exported function `getrow` allows for finding a row in a `DataFrame` using
keyword syntax.
- Sweeps support declaring a combination of shared dependencies and dependencies
that are computed for each iteration, pametrised by the iteration variables.
- Output file names are computed based on the hash of the recipe and the paramters
at which it is executed. This allows for backups of many versions and parameter
choices to coexist.
