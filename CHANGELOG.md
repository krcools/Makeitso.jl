# Version 1.0

- Exported function `getrow` allows for finding a row in a `DataFrame` using
keyword syntax.
- Sweeps support declaring a combination of shared dependencies and dependencies
that are computed for each iteration, pametrised by the iteration variables.
- Output file names are computed based on the hash of the recipe and the paramters
at which it is executed. This allows for backups of many versions and parameter
choices to coexist.
