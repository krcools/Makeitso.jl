module Makeitso

using JLD2
using FileIO
using DrWatson
using BakerStreet
using DataFrames
using MacroTools

export @target
export @sweep, @sweep2
export make
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
    parameter_keys
    mem_only
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
    parameter_keys
end

include("utils.jl")

function Target(name, recipe, deps, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname, nothing)
end


function make(target::Target, level=0; kwargs...)
    kwargs = Dict((k,v) for (k,v) in kwargs if (k in target.parameter_keys))

    if cache_uptodate(target; parameters=kwargs)
        return target.cache
    end

    try_loading(target, kwargs)

    if cache_uptodate(target; parameters=kwargs)
        return target.cache
    end

    for t in target.deps
        make(t, level+1; kwargs...)
    end

    update!(target; kwargs...)

    return target.cache
end


function make(sweep::Sweep, level=0; kwargs...)

    kwargs = Dict((k,v) for (k,v) in kwargs if (k in sweep.parameter_keys || k in sweep.variable_keys))
    parameters = Dict((k,v) for (k,v) in kwargs if !(k in sweep.variable_keys))
    configs = DrWatson.dict_list(Dict((s, kwargs[s]) for s in sweep.variable_keys))

    cache_uptodate(sweep; parameters=kwargs) && return sweep.cache
    try_loading(sweep, kwargs)
    cache_uptodate(sweep; parameters=kwargs) && return sweep.cache

    for t in sweep.shared_deps
        make(t, level+1; parameters...)
    end

    sweep.iteration_timestamps = []
    for variables in configs

        iteration_cache_uptodate(sweep; parameters..., variables...) && continue
        try_loading_iteration(sweep, variables, parameters)
        iteration_cache_uptodate(sweep; parameters..., variables...) && continue

        for t in sweep.iteration_deps
            make(t, level+1; parameters..., variables...)
        end

        iteration_update!(sweep, variables, parameters)
    end

    sweep_update!(sweep, configs, kwargs, parameters)
    return sweep.cache
end


function sweep_update!(sweep, variables_list, parameters, nonvariables)

    fullpath = target_fullpath(sweep, parameters)
    mkpath(dirname(fullpath))

    # collect the results in the .dir folder
    # @info "!!! sweep $(sweep.name) at $(parameters): computing from deps."
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

function iteration_update!(sweep, variables, parameters)

    fullpath = iteration_fullpath(sweep, variables, parameters)
    mkpath(dirname(fullpath))

    shared_deps_vals = [t.cache for t in sweep.shared_deps]
    iteration_deps_vals = [t.cache for t in sweep.iteration_deps]

    @info "!!! iteration $(sweep.name) at $(variables): computing from deps."
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

function update!(target::Target; kwargs...)

    fullpath = target_fullpath(target, kwargs)
    mkpath(dirname(fullpath))

    @info "!!! target $(target.name) at $(NamedTuple(kwargs)): computing from deps."
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

    tnames = []
    parameter_keys = []

    # treat the special case of a single argument
    if recipe.args[1] isa Symbol
        recipe.args[1] = Expr(:tuple, recipe.args[1])
    end

    tp = recipe.args[1]
    @assert tp.head == :tuple
    for arg in tp.args
        if arg isa Symbol
            push!(tnames, esc(arg))
        elseif arg isa Expr && arg.head == :parameters
                for p in arg.args
                    if p isa Symbol
                        push!(parameter_keys, p)
                    else
                        error("Unexpected parameter in target definition: $p")
                    end
                end
        else
            error("Unexpected argument in target definition: $arg")
        end
    end

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
                $(esc(out)).deps = [$(tnames...)]
                $(esc(out)).recipe = $(esc(recipe))
                $(esc(out)).timestamp = 0.0
                $(esc(out)).cache = nothing
                $(esc(out)).name = $(String(out))
                $(esc(out)).hash = $recipe_hash
                $(esc(out)).relpath = $path
                $(esc(out)).tree_hash = target_hash($(esc(out)), hash(nothing))
                $(esc(out)).parameter_keys = $(parameter_keys)
                $(esc(out)).mem_only = $memonly
                append_deps_parameter_keys!($(esc(out)), $(parameter_keys))
            end
        end
    else
        xp = quote
            $(esc(out)) = Target(
                [$(tnames...)],
                $(esc(recipe)),
                0.0,
                nothing,
                $(String(out)),
                $recipe_hash,
                $path,
                nothing,
                zero(UInt64),
                $(parameter_keys),
                $(memonly),
                )
            append_deps_parameter_keys!($(esc(out)), $(esc(out)).parameter_keys)
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
    parameter_keys = []

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
                    push!(parameter_keys, p)
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
                $(esc(out)).parameter_keys = $(parameter_keys)
                append_deps_parameter_keys!($(esc(out)), $(parameter_keys))
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
                $(parameter_keys),
            )
            append_deps_parameter_keys!($(esc(out)), $(esc(out)).parameter_keys)
            $(esc(out)).tree_hash = Makeitso.target_hash($(esc(out)), hash(nothing))
        end
    end
    return xp
end

end # module

