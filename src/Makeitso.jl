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
export getrow


mutable struct Target
    deps
    recipe
    timestamp
    cache
    name
    hash
    relpath
    params
    tree_hash
    par_keys
    mem_only
    par_tfs
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
    iteration_parameters
    iteration_timestamps
    tree_hash
    par_keys
end

include("utils.jl")

function Target(name, recipe, deps, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname, nothing)
end


function make(target::Target, level=0; kwargs...)
    kwargs = Dict((k,v) for (k,v) in kwargs if (k in target.par_keys))

    # pfx = "⎵"^level
    pfx = ""
    @info "[$level]$(pfx) making \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)):"

    if cache_uptodate(target; parameters=kwargs)
        @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)) retrieved from cache."
        return target.cache
    end

    try_loading(target, level, kwargs)

    if cache_uptodate(target; parameters=kwargs)
        @info "[$level]$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)) retrieved from disk."
        return target.cache
    end

    # @show kwargs

    for (t,tf) in zip(target.deps, target.par_tfs)
        kws = tf === nothing ? kwargs : tf(;kwargs...)
        # @show kws
        make(t, level+1; kws...)
    end

    update!(target, level; kwargs...)

    return target.cache
end


function make(sweep::Sweep, level=0; kwargs...)

    pfx = "⎵"^level
    pfx = ""
    @info "[$level]$(pfx) making \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)):"

    kwargs = Dict((k,v) for (k,v) in kwargs if (k in sweep.par_keys || k in sweep.variable_keys))
    parameters = Dict((k,v) for (k,v) in kwargs if !(k in sweep.variable_keys))
    configs = DrWatson.dict_list(Dict((s, kwargs[s]) for s in sweep.variable_keys))

    if cache_uptodate(sweep; parameters=kwargs)
        @info "[$level]$(pfx) sweep \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)) retrieved from cache."
        return sweep.cache
    end
    try_loading(sweep, level, kwargs)
    if cache_uptodate(sweep; parameters=kwargs)
        @info "[$level]$(pfx) sweep \e[32m$(sweep.name)\e[0m at $(NamedTuple(kwargs)) retrieved from disk."
        return sweep.cache
    end

    for t in sweep.shared_deps
        make(t, level+1; parameters...)
    end

    sweep.iteration_timestamps = []
    for variables in configs

        pfx = "⎵"^(level+1)
        pfx = ""
        @info "[$(level+1)]$(pfx) making iteration \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)):"

        if iteration_cache_uptodate(sweep; parameters..., variables...)
            @info "[$(level+1)]$(pfx) iteration \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)) retrieved from cache."
            continue
        end
        try_loading_iteration(sweep, level+1, variables, parameters)
        if iteration_cache_uptodate(sweep; parameters..., variables...)
            @info "[$(level+1)]$(pfx) iteration \e[32m$(sweep.name)\e[0m at $(NamedTuple(variables)) retrieved from disk."
            continue
        end

        for t in sweep.iteration_deps
            make(t, level+2; parameters..., variables...)
        end

        iteration_update!(sweep, level+1, variables, parameters)
    end

    sweep_update!(sweep, level, configs, kwargs, parameters)
    return sweep.cache
end


function sweep_update!(sweep, level, variables_list, parameters, nonvariables)

    pfx = "⎵"^(level)
    pfx = ""
    fullpath = target_fullpath(sweep, parameters)
    mkpath(dirname(fullpath))

    # collect the results in the .dir folder
    @info "[$level]$(pfx) sweep \e[32m$(sweep.name)\e[0m at $(NamedTuple(parameters)): collect iterations."
    df = loadsims(iteration_dirname(sweep, nothing), variables_list, nonvariables)
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

function iteration_update!(sweep, level, variables, parameters)

    pfx = "⎵"^(level)
    pfx = ""
    fullpath = iteration_fullpath(sweep, variables, parameters)
    mkpath(dirname(fullpath))

    shared_deps_vals = [t.cache for t in sweep.shared_deps]
    iteration_deps_vals = [t.cache for t in sweep.iteration_deps]

    @info "\e[38;5;208m[$(level)]\e[0m$(pfx) iteration \e[32m$(sweep.name)\e[0m at $(NamedTuple(merge(parameters, variables))): computing from deps!"
    sweep.iteration_cache = sweep.recipe(
        shared_deps_vals...,
        iteration_deps_vals...,
        ; variables..., parameters...)
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

function update!(target::Target, level; kwargs...)

    pfx = "⎵"^(level)
    pfx = ""
    fullpath = target_fullpath(target, kwargs)
    mkpath(dirname(fullpath))

    @info "\e[38;5;208m[$level]\e[0m$(pfx) target \e[32m$(target.name)\e[0m at $(NamedTuple(kwargs)): computing from deps!"
    target.params = kwargs
    target.cache = target.recipe(getfield.(target.deps, :cache)...; kwargs...)
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

    file_name = String(out) * ".jld2"

    deps = []
    par_keys = []
    par_kws = []
    par_tfs = []

    # treat the special case of a single argument
    if recipe.args[1] isa Symbol
        recipe.args[1] = Expr(:tuple, recipe.args[1])
    end

    tp = recipe.args[1]
    @assert tp.head == :tuple
    for (i,arg) in pairs(tp.args)
        if arg isa Symbol
            push!(deps, esc(arg))
            push!(par_kws, nothing)
        elseif arg isa Expr && arg.head == :call
            tname = arg.args[1]
            @assert arg.args[2] isa Expr && arg.args[2].head == :parameters
            kws = arg.args[2].args
            push!(deps, esc(tname))
            push!(par_kws, kws)
            tp.args[i] = tname
        elseif arg isa Expr && arg.head == :parameters
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



    # build the keyword transformation expressions
    for (i, tname) in pairs(deps)
        kws = par_kws[i]
        if kws == nothing
            push!(par_tfs, nothing)
            continue
        end
        xp = :( (;$(par_keys...), kwargs...) -> (;$(par_keys...), kwargs..., $(kws...) ))
        push!(par_tfs, esc(xp))
    end


    # @show out
    # @show tp
    # @show deps
    # @show par_keys
    # @show par_kws
    # for tf in par_tfs
    #     @show tf
    # end
    # println()

    # body = :( ($(par_keys...), kwargs...) -> (;$(par_keys...), kwargs..., $(kws...)) )

    # add kwargs... to the argument list
    tp = add_kwargs_to_args!(tp)

    fn = string(__source__.file)
    rp = dirname(relpath(fn, projectdir()))
    sn = splitext(basename(fn))[1]
    path = joinpath(rp, sn) # "examples/sweep"

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
                $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
                $(esc(out)).par_keys = $(par_keys)
                $(esc(out)).mem_only = $memonly
                $(esc(out)).par_tfs = [$(par_tfs...)]
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
                [$(par_tfs...)]
                )
            append_deps_parameter_keys!($(esc(out)), $(esc(out)).par_keys)
            $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
        end
    end
    return xp
end


macro sweep(out, recipe)

    @assert out isa Symbol
    @assert recipe.head == :->

    file_name = String(out) * ".jld2"

    shared_deps = []
    iteration_deps = []
    variable_keys = []
    par_keys = []

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
        elseif arg isa Expr && arg.head == :call
            @assert arg.args[1] == :!
            push!(iteration_deps, esc(arg.args[2]))
            args.args[i] = arg.args[2]
        elseif arg isa Symbol
            push!(shared_deps, esc(arg))
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
                append_deps_parameter_keys!($(esc(out)), $(par_keys))
                # full_path = Makeitso.sweep_fullpath($(esc(out)))
                # isfile(full_path) && rm(full_path)
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
        rp,
        [],
        [t],
        var_keys,
        recipe_fn,
        pihash(recipe_xp),
        nothing,
        0.0,
        params,
        nothing, # iteration_cache
        0.0, # iteration_timestamp
        nothing, # iteration_parameters
        [], # iteration_timestamps
        zero(UInt64), # tree_hash
        par_keys, # par_keys
    )
    append_deps_parameter_keys!(sweep, sweep.par_keys)
    sweep.tree_hash = Makeitso.target_hash(sweep, hash(nothing))

    df = make(sweep; vars..., params...)
end

end # module

