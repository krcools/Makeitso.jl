# Version 2.2.1

- Expand colorscheme: blue is cached, purple is on-disk, amber is compute.

# Version 2.2

= Fix parsing issues on Julia 1.12

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
