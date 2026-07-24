module Makeitso

using JLD2
using FileIO
using DrWatson
using BakerStreet
using DataFrames
using MacroTools

export @target
export @sweep, @sweep2
export make, sweep
export over
export getrow
export verbosity


struct Over
    keys::Vector{Symbol}
end

struct Verbosity{Level}
    function Verbosity{Level}() where {Level}
        Level in (:short, :full) || throw(ArgumentError("Verbosity level must be :short or :full, got $(Level)"))
        new{Level}()
    end
end

function verbosity(s::Symbol)
    s === :short && return Verbosity{:short}()
    s === :full && return Verbosity{:full}()
    throw(ArgumentError("verbosity(s::Symbol) expects :short or :full, got $(s)"))
end

function over(keys...)
    syms = Symbol[]
    for k in keys
        if k isa Symbol
            push!(syms, k)
        elseif k isa AbstractString
            push!(syms, Symbol(k))
        else
            error("over(...) expects Symbols or Strings, got $(typeof(k))")
        end
    end
    return Over(syms)
end


mutable struct Target
    deps
    recipe
    timestamp
    cache
    name
    hash      # hash of the current recipe
    relpath
    params    # parameter values at which the cache was computed
    tree_hash # recipe tree hash at which the cache was computed. This should
              # be recursively computed from the recipe hash and those of its
              # dependencies, including weak dependencies.
    par_keys  # vector of symbols corresponding to the keyword parameters of the
              # target and all its depenedencies. Used to filter the kwargs
              # passed to make() to only those relevant for the target.
    mem_only
    par_tfs
    weak_deps
end

mutable struct Sweep
    name
    relpath
    shared_deps    # shared dependencies
    iteration_deps # iteration dependencies
    variable_keys  # which keywords correspond to ranges to iterate over
    recipe
    hash
    cache
    timestamp
    parameters
    iteration_cache
    iteration_timestamp
    iteration_parameters # iteration parameters at which the iteration_cache was computed
    iteration_timestamps
    tree_hash # recipe tree hash at which the iteration_cache was computed
    par_keys # which keyword correspond to parameters that do not vary across iterations
    weak_deps
end

include("utils.jl")

function Target(name, recipe, deps, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname, nothing)
end

# default verbosity is :full
make(target::Target; kwargs...) = make(target, verbosity(:full); kwargs...)

function make(target::Target, v::Verbosity{Level}; kwargs...) where {Level}
    make(target, v, 0; kwargs...)
end

function make(target::Target, v::Verbosity{Level}, level::Int; kwargs...) where {Level}
    kwargs = Dict((k,v) for (k,v) in kwargs if (k in target.par_keys))

    pfx = ""
    Level === :full && @info "[$level]$(pfx) making \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)):"
    Level === :short && @info "[$level]$(pfx) making \e[32m$(target.name)\e[0m:"


    if cache_uptodate(target; parameters=kwargs)
        Level === :full && @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)): retrieved from cache."
        Level === :short && @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m: retrieved from cache."
        return target.cache
    end

    try_loading(target, level, kwargs)
    if cache_uptodate(target; parameters=kwargs)
        Level === :full && @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)): retrieved from disk."
        Level === :short && @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m: retrieved from disk."
        return target.cache
    end

    for (t,tf) in zip(target.deps, target.par_tfs)
        kws = tf === nothing ? kwargs : tf(;kwargs...)
        # @show kws
        make(t, v, level+1; kws...)
    end
    update!(target, v, level; kwargs...)

    return target.cache
end


make(sweep::Sweep; kwargs...) = make(sweep, verbosity(:full); kwargs...)

function make(sweep::Sweep, v::Verbosity{Level}; kwargs...) where {Level}
    make(sweep, v, 0; kwargs...)
end

function make(sweep::Sweep, v::Verbosity{Level}, level::Int; kwargs...) where {Level}

    pfx = "⎵"^level
    pfx = ""
    Level === :full && @info "[$level]$(pfx) sweeping \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)):"
    Level === :short && @info "[$level]$(pfx) sweeping \e[32m$(sweep.name)\e[0m:"

    kwargs = Dict((k,v) for (k,v) in kwargs if (k in sweep.par_keys || k in sweep.variable_keys))
    parameters = Dict((k,v) for (k,v) in kwargs if !(k in sweep.variable_keys))
    configs = DrWatson.dict_list(Dict((s, kwargs[s]) for s in sweep.variable_keys))

    if cache_uptodate(sweep; parameters=kwargs)
        Level === :full && @info "\e[34m[$level]\e[0m$(pfx) sweep \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)): retrieved from cache."
        Level === :short && @info "\e[34m[$level]\e[0m$(pfx) sweep \e[32m$(sweep.name)\e[0m: retrieved from cache."
        return sweep.cache
    end
    try_loading(sweep, level, kwargs)
    if cache_uptodate(sweep; parameters=kwargs)
        Level === :full && @info "\e[35m[$level]\e[0m$(pfx) sweep \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)): retrieved from disk."
        Level === :short && @info "\e[35m[$level]\e[0m$(pfx) sweep \e[32m$(sweep.name)\e[0m: retrieved from disk."
        return sweep.cache
    end

    for t in sweep.shared_deps
        make(t, v, level+1; parameters...)
    end

    sweep.iteration_timestamps = []
    for variables in configs

        pfx = "⎵"^(level+1)
        pfx = ""
        Level === :full && @info "[$(level+1)]$(pfx) making \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)):"
        Level === :short && @info "[$(level+1)]$(pfx) making \e[32m$(sweep.name)\e[0m:"

        if iteration_cache_uptodate(sweep; parameters..., variables...)
            Level === :full && @info "\e[34m[$(level+1)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)): retrieved from cache."
            Level === :short && @info "\e[34m[$(level+1)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m: retrieved from cache."
            continue
        end
        try_loading_iteration(sweep, level+1, variables, parameters)
        if iteration_cache_uptodate(sweep; parameters..., variables...)
            Level === :full && @info "\e[35m[$(level+1)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)): retrieved from disk."
            Level === :short && @info "\e[35m[$(level+1)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m: retrieved from disk."
            continue
        end

        for t in sweep.iteration_deps
            make(t, v, level+2; parameters..., variables...)
        end

        iteration_update!(sweep, v, level+1, variables, parameters)
    end

    sweep_update!(sweep, v, level, configs, kwargs, parameters)
    return sweep.cache
end


function sweep_update!(sweep, ::Verbosity{Level}, level, variables_list, parameters, nonvariables) where {Level}

    pfx = "⎵"^(level)
    pfx = ""
    fullpath = target_fullpath(sweep, parameters)
    mkpath(dirname(fullpath))

    # collect the results in the .dir folder
    Level === :full && @info "[$level]$(pfx) sweep  \e[32m$(sweep.name)\e[0m at $(NamedTuple(parameters)): collect iterations."
    Level === :short && @info "[$level]$(pfx) sweep  \e[32m$(sweep.name)\e[0m: collect iterations."

    df = loadsims(sweep, variables_list, nonvariables)
    select!(df, Not([:timestamp, :hash, :path, :params, :tree_hash]))

    sweep.cache = df
    sweep.timestamp = time()
    sweep.parameters = parameters
    sweep.tree_hash = target_hash(sweep, hash(nothing))

    # save(fullpath, Dict(
    #     "cache" => sweep.cache,
    #     "timestamp" => sweep.timestamp,
    #     "hash" => sweep.hash,
    #     "params" => sweep.parameters,
    #     "tree_hash" => sweep.tree_hash))
end

function iteration_update!(sweep, ::Verbosity{Level}, level, variables, parameters) where {Level}

    pfx = "⎵"^(level)
    pfx = ""
    fullpath = iteration_fullpath(sweep, variables, parameters)
    mkpath(dirname(fullpath))

    shared_deps_vals = [t.cache for t in sweep.shared_deps]
    iteration_deps_vals = [t.cache for t in sweep.iteration_deps]

    Level === :full && @info "\e[38;5;208m[$(level)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m at $(NamedTuple(merge(parameters, variables))): computing from deps!"
    Level === :short && @info "\e[38;5;208m[$(level)]\e[0m$(pfx) target \e[32m$(sweep.name)\e[0m: computing from deps!"    
    sweep.iteration_cache = sweep.recipe(
        shared_deps_vals...,
        iteration_deps_vals...,
        sweep.weak_deps...;
        variables..., parameters...)
    sweep.iteration_timestamp = time()
    sweep.iteration_parameters = merge(variables, parameters)
    sweep.tree_hash = target_hash(sweep, hash(nothing))

    dct = merge(
        sweep.iteration_cache,
        (;
            timestamp=sweep.iteration_timestamp,
            hash=sweep.hash,
            params=sweep.iteration_parameters,
            tree_hash=sweep.tree_hash,
        ),
        (;sweep.iteration_parameters...),
    )

    jldsave(fullpath; dct...)
end

function update!(target::Target, ::Verbosity{Level}, level; kwargs...) where {Level}

    pfx = ""
    fullpath = target_fullpath(target, kwargs)
    mkpath(dirname(fullpath))

    Level === :full && @info "\e[38;5;208m[$level]\e[0m$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)): computing from deps!"
    Level === :short && @info "\e[38;5;208m[$level]\e[0m$(pfx) target \e[32m$(target.name)\e[0m: computing from deps!"
    target.params = kwargs
    target.cache = target.recipe(getfield.(target.deps, :cache)..., target.weak_deps...; kwargs...)
    target.timestamp = time()
    target.tree_hash = target_hash(target, hash(nothing))
    target.mem_only && return

    save(fullpath, Dict(
        target.name => target.cache,
        "timestamp" => target.timestamp,
        "hash" => target.hash,
        "params" => target.params,
        "tree_hash" => target.tree_hash))
end






macro target(args...)

    # extract the options, output name and recipe from the macro arguments
    if length(args) == 2
        options = :(memonly=false)
        out = args[1]
        recipe = args[2]
    elseif length(args) == 3
        options = args[1]
        out = args[2]
        recipe = args[3]
    else
        error("Invalid number of arguments to @target macro. Expected 2 or 3")
    end

    @assert options isa Expr && options.head == :(=) && options.args[1] == :memonly
    memonly = options.args[2]

    @assert out isa Symbol
    @assert recipe.head == :->

    # treat the special case (A), transform to (A,)
    if recipe.args[1] isa Symbol
        recipe.args[1] = Expr(:tuple, recipe.args[1])
    end

    # treat the special case (A;h), transform to (A,;h)
    if recipe.args[1].head == :block
        Base.remove_linenums!(recipe.args[1])
        @assert length(recipe.args[1].args) == 2
        recipe.args[1] = Expr(:tuple, Expr(:parameters, recipe.args[1].args[2]), recipe.args[1].args[1])
    end

    deps = []
    weak_deps = []
    par_keys = []
    par_kws = [] 

    tp = recipe.args[1] # e.g. tp == :((A, B(;q=2h), ;h, p))
    @assert tp.head == :tuple
    for (i,arg) in pairs(tp.args)
        if arg isa Symbol # e.g. arg == :A
            push!(deps, esc(arg))
            push!(par_kws, nothing)
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :~
            weak_dep = arg.args[2]
            push!(weak_deps, esc(weak_dep))
            tp.args[i] = weak_dep
        elseif arg isa Expr && arg.head == :call # e.g. arg == :(B(;q=2h))
            tname = arg.args[1] # e.g. tname == :B
            @assert arg.args[2] isa Expr && arg.args[2].head == :parameters
            kws = arg.args[2].args # e.g. kws == [Expr(:kw, :q, :(2h))]
            push!(deps, esc(tname))
            push!(par_kws, kws)
            tp.args[i] = tname # arg == :B
        elseif arg isa Expr && arg.head == :parameters # e.g. arg == Expr(:parameters, :h, :p)
                for p in arg.args
                    if p isa Symbol
                        push!(par_keys, p)
                    else
                        error("Unexpected parameter in target definition: $p")
                    end
                end
        else
            error("Unexpected argument in target definition: $arg")
        end
    end

    # deps     == [:A, :B]
    # par_kws  == [nothing, [Expr(:kw, :q, :(2h))]]
    # par_keys == [:h, :p]

    # build the keyword transformation expressions
    par_tfs = [] # expressions to transform the kwargs for the target into kwargs for the dependencies
    for (i, tname) in pairs(deps)
        kws = par_kws[i] # e.g. kws == [Expr(:kw, :q, :(2h))]
        if kws == nothing
            push!(par_tfs, nothing)
            continue
        end
        xp = :( (;$(par_keys...), kwargs...) -> (;$(par_keys...), kwargs..., $(kws...) ))
        push!(par_tfs, esc(xp))
    end
    # e.g. par_tfs = [ nothing, :( (;h, p, kwargs...) -> (;h, p, kwargs..., q=2h) ) ]

    # add kwargs... to the argument list to accept parameters for dependencies
    tp = add_kwargs_to_args!(tp)
    # e.g tp == :((A, B, ;h, p, kwargs...))

    fn = string(__source__.file)            # "/home/user/project/examples/params.jl"
    rp = dirname(relpath(fn, projectdir())) # "examples"
    sn = splitext(basename(fn))[1]          # "params"
    path = joinpath(rp, sn)                 # "examples/params"

    exists = isdefined(__module__, out)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out)).hash
                @assert typeof($(esc(out))) <: Target "Target $(esc(out)) musn't be redefined as a different type."
                $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
                $(esc(out)).deps = [$(deps...)]
                $(esc(out)).recipe = $(esc(recipe))
                $(esc(out)).timestamp = 0.0
                $(esc(out)).cache = nothing
                $(esc(out)).name = $(String(out))
                $(esc(out)).hash = $recipe_hash
                $(esc(out)).relpath = $path
                # $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
                $(esc(out)).par_keys = $(par_keys)
                $(esc(out)).mem_only = $memonly
                $(esc(out)).par_tfs = [$(par_tfs...)]
                $(esc(out)).weak_deps = [$(weak_deps...)]
                append_deps_parameter_keys!($(esc(out)), $(par_keys))
            end
        end
    else
        xp = quote
            $(esc(out)) = Target(
                [$(deps...)],
                $(esc(recipe)),
                0.0,
                nothing,
                $(String(out)),
                $recipe_hash,
                $path,
                nothing,
                zero(UInt64),
                $(par_keys),
                $(memonly),
                [$(par_tfs...)],
                [$(weak_deps...)],
                )
            append_deps_parameter_keys!($(esc(out)), $(esc(out)).par_keys)
            $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
        end
    end
    return xp
end


macro sweep(out, recipe)

    # @show recipe
    @assert out isa Symbol
    @assert recipe.head == :->

    file_name = String(out) * ".jld2"

    shared_deps = []
    iteration_deps = []
    weak_deps = []
    variable_keys = []
    par_keys = []

    # treat the special  case (A;h), transform to (A,;h)
    if recipe.args[1].head == :block
        Base.remove_linenums!(recipe.args[1])
        @assert length(recipe.args[1].args) == 2
        @assert recipe.args[1].args[2] isa Expr
        @assert recipe.args[1].args[2].head == :(=)
        k = recipe.args[1].args[2].args[1]
        v = :( [] )
        recipe.args[1] = Expr(:tuple, Expr(:parameters, Expr(:kw, k, v)), recipe.args[1].args[1])
    end
    # @show recipe.args[1]

    # process the dependency specification: sort out parameters and variables,
    # shared deps and iteration deps
    args = recipe.args[1]
    @assert args.head == :tuple

    for (i,arg) in pairs(args.args)
        if arg isa Expr && arg.head == :parameters
            for (j,p) in pairs(arg.args)
                if p isa Expr && p.head == :kw
                    push!(variable_keys, QuoteNode(p.args[1]))
                    arg.args[j] = p.args[1]
                elseif p isa Symbol
                    push!(par_keys, p)
                else
                    error("Unexpected parameter in sweep definition: $p")
                end
            end
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :!
            # @assert arg.args[1] == :!
            push!(iteration_deps, esc(arg.args[2]))
            args.args[i] = arg.args[2]
        elseif arg isa Symbol
            push!(shared_deps, esc(arg))
        elseif arg isa Expr && arg.head == :call && arg.args[1] == :~
            weak_dep = arg.args[2]
            push!(weak_deps, esc(weak_dep))
            args.args[i] = weak_dep
        else
            error("Unexpected recipe argument: $arg")
        end
    end

    # add kwargs... to the argument list
    args = add_kwargs_to_args!(args)

    exists = isdefined(__module__, out)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out)).hash
                $(esc(out)).shared_deps = [$(shared_deps...)]
                $(esc(out)).iteration_deps = [$(iteration_deps...)]
                $(esc(out)).variable_keys = [$(variable_keys...)]
                $(esc(out)).recipe = $(esc(recipe))
                $(esc(out)).hash = $recipe_hash
                $(esc(out)).cache = nothing
                $(esc(out)).timestamp = 0.0
                $(esc(out)).parameters = nothing
                $(esc(out)).iteration_cache = nothing
                $(esc(out)).iteration_timestamp = 0.0
                $(esc(out)).iteration_parameters = nothing
                $(esc(out)).iteration_timestamps = []
                $(esc(out)).tree_hash = Makeitso.target_hash($(esc(out)) , hash(nothing))
                $(esc(out)).par_keys = $(par_keys)
                $(esc(out)).weak_deps = [$(weak_deps...)]
                append_deps_parameter_keys!($(esc(out)), $(par_keys))
            end
        end
    else
        fn = string(__source__.file)
        rp = dirname(relpath(fn, projectdir()))
        sn = splitext(basename(fn))[1]
        rp = joinpath(rp, sn) # "examples/sweep"

        xp = quote
            $(esc(out)) = Sweep(
                $(String(out)),
                $rp,
                [$(shared_deps...)],
                [$(iteration_deps...)],
                [$(variable_keys...)],
                $(esc(recipe)),
                $recipe_hash,
                nothing,
                0.0,
                [],
                nothing,
                0.0,
                nothing,
                [],
                zero(Int64),
                $(par_keys),
                [$(weak_deps...)],
            )
            append_deps_parameter_keys!($(esc(out)), $(esc(out)).par_keys)
            $(esc(out)).tree_hash = Makeitso.target_hash($(esc(out)), hash(nothing))
        end
    end
    return xp
end


function sweep(t::Target; kwargs...)

    tname = Symbol(t.name)

    params = []
    vars = []

    var_keys = []
    par_keys = []

    for (k,v) in kwargs
        try
            sz = size(v)
            if sz != ()
                push!(vars, (k,v))
                push!(var_keys, k)
            else
                if v isa Ref
                    push!(params, (k, v[]))
                    push!(par_keys, k)
                else
                    push!(params, (k,v))
                    push!(par_keys, k)
                end
            end
        catch
            push!(params, (k,v))
            push!(par_keys, k)
        end
    end

    params = Dict(params)
    vars = Dict(vars)

    # fn = string(@__FILE__)
    # rp = dirname(relpath(fn, projectdir()))
    # sn = splitext(basename(fn))[1]
    # rp = joinpath(rp, sn)
    rp = t.relpath

    recipe_xp = :((t; kwargs...) -> (d=Dict(tname=>t); NamedTuple(d)))
    recipe_fn = (t; kwargs...) -> (d=Dict(tname=>t); NamedTuple(d))
    # recipe = :( (t; kwargs...) -> (;$tname=t) )

    # @show params
    # @show vars
    # @show rp
    # @show Base.remove_linenums!(recipe_xp)

    sweep = Sweep(
        "$(t.name).sweep",
        # t.name,
        rp,
        [],        # shaed dependencies
        [t],       # iteration dependencies
        var_keys,  # keywords corresponding to variables to sweep over
        recipe_fn,
        pihash(recipe_xp), # has of the recipe
        # t.hash,
        nothing,
        0.0,
        params,
        nothing,      # iteration_cache
        0.0,          # iteration_timestamp
        nothing,      # iteration_parameters
        [],           # iteration_timestamps
        zero(UInt64), # tree_hash at which the cached iteration was computed
        par_keys,     # keywords correspdongin to fixed parameters
        []            # weak dependencies
    )
    append_deps_parameter_keys!(sweep, sweep.par_keys)
    sweep.tree_hash = Makeitso.target_hash(sweep, hash(nothing))

    df = make(sweep; vars..., params...)
end


function sweep(t::Target, o::Over; kwargs...)

    tname = Symbol(t.name)

    params = Pair[]
    vars = Pair[]

    var_keys = Symbol[]
    par_keys = Symbol[]

    over_keys = Set(o.keys)

    for k in o.keys
        haskey(kwargs, k) || error("Missing sweep variable '$k' in keyword arguments")
    end

    for (k,v) in kwargs
        if k in over_keys
            vv = v isa Ref ? v[] : v
            vals = try
                size(vv) == () ? [vv] : vv
            catch
                [vv]
            end
            push!(vars, k=>vals)
            push!(var_keys, k)
        else
            pv = v isa Ref ? v[] : v
            push!(params, k=>pv)
            push!(par_keys, k)
        end
    end

    params = Dict(params)
    vars = Dict(vars)

    rp = t.relpath

    recipe_xp = :((t; kwargs...) -> (d=Dict(tname=>t); NamedTuple(d)))
    recipe_fn = (t; kwargs...) -> (d=Dict(tname=>t); NamedTuple(d))

    sweep = Sweep(
        "$(t.name).sweep",
        rp,
        [],
        [t],
        var_keys,
        recipe_fn,
        pihash(recipe_xp),
        nothing,
        0.0,
        params,
        nothing,
        0.0,
        nothing,
        [],
        zero(UInt64),
        par_keys,
        []
    )
    append_deps_parameter_keys!(sweep, sweep.par_keys)
    sweep.tree_hash = Makeitso.target_hash(sweep, hash(nothing))

    df = make(sweep; vars..., params...)
end


"""
    deepclean(x)

Recursively removes all on-disk artifacts for `x` and its dependencies.

- For `Target`, this traverses `target.deps` and then removes `target_dirname(target)`.
- For `Sweep`, this traverses `sweep.shared_deps` and `sweep.iteration_deps` and then removes `target_dirname(sweep)`.

If a directory does not exist, it is skipped.
"""
function deepclean(target::Target)
    # Recursively clean dependencies first
    for dep in target.deps
        deepclean(dep)
    end
    
    # Remove the target's directory and all its jld2 files
    dir = target_dirname(target)
    if isdir(dir)
        rm(dir, recursive=true)
    end
end


function deepclean(sweep::Sweep)
    # Recursively clean shared dependencies first
    for dep in sweep.shared_deps
        deepclean(dep)
    end
    
    # Recursively clean iteration dependencies first
    for dep in sweep.iteration_deps
        deepclean(dep)
    end
    
    # Remove the sweep's directory and all its jld2 files
    dir = target_dirname(sweep)
    if isdir(dir)
        rm(dir, recursive=true)
    end
end


function _collect_from_dir(dir)
    if !isdir(dir)
        return DataFrame()
    end

    df = DrWatson.collect_results(dir; black_list=String[])

    # Remove metadata fields
    cols_to_drop = intersect(["hash", "timestamp", "tree_hash", "path"], names(df))
    if !isempty(cols_to_drop)
        select!(df, Not(cols_to_drop))
    end

    # Flatten params dictionary into top-level columns
    if "params" in names(df)
        param_keys = Symbol[]
        for p in df.params
            if p isa AbstractDict
                for k in keys(p)
                    sk = Symbol(k)
                    if !(sk in param_keys)
                        push!(param_keys, sk)
                    end
                end
            end
        end

        @show param_keys
        for k in param_keys
            df[!, k] = [
                (p isa AbstractDict && haskey(p, k)) ? p[k] :
                (p isa AbstractDict && haskey(p, String(k))) ? p[String(k)] :
                missing
                for p in df.params
            ]
        end

        select!(df, Not(:params))
    end
    @show df

    return df
end


function collect(target::Target)
    dir = target_dirname(target)
    return _collect_from_dir(dir)
end


function collect(sweep::Sweep)
    dir = target_dirname(sweep)
    return _collect_from_dir(dir)
end




end # module

