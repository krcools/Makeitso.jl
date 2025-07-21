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
end

include("utils.jl")

function Target(name, recipe, deps, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname, nothing)
end

function make(target, level=0; kwargs...)

    for t in target.deps
        make(t, level+1; kwargs...)
    end

    fullpath = target_fullpath(target, kwargs)

    # No file means this is the first run ever
    if !isfile(fullpath)
        @info "No backup found for $(target.name)."
        update!(target; kwargs...)
        @info "level $level dep $(target.name): computed from dependencies [initial computation]."
        return target.cache
    end

    # Target was made in previous session. Is it up-to-date?
    deps_stamp = reduce(max, getfield.(target.deps, :timestamp), init=0.0)
    if target.cache == nothing
        d = load(fullpath)
        @info "target loaded from location: $(relpath(fullpath, projectdir())))"
        if d["hash"] != target.hash
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [recipe modified]."
        elseif d["params"] != kwargs
            # @show target.params
            # @show kwargs
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [parameters modified]."
        elseif d["timestamp"] < deps_stamp
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [out-of-date]."
        else
            target.timestamp = d["timestamp"]
            target.cache = d[String(target.name)]
            target.params = d["params"]
            @info "level $level dep $(target.name): restored from disk."
        end
        return target.cache
    end

    # Target was computed in this session. Is it up-to-date?
    if target.timestamp < deps_stamp
        update!(target; kwargs...)
        @info "level $level dep $(target.name) in memory but recomputed from deps [out-of-date]."
        return target.cache
    elseif target.params != kwargs
        # @show target.params
        # @show kwargs
        update!(target; kwargs...)
        @info "level $level dep $(target.name) in memory but recomputed from deps [parameters modified]."
        return target.cache
    else
        @info "level $level dep $(target.name): retrieved from memory."
        return target.cache
    end
end



function make(sweep::Sweep, level=0; kwargs...)

    parameters = Dict(
        (k,v) for (k,v) in kwargs if !(k in sweep.variable_keys)
    )

    for t in sweep.shared_deps
        make(t, level+1; parameters...)
    end

    # @show kwargs
    # @show sweep.variable_keys
    variables_list = DrWatson.dict_list(
        Dict((s, kwargs[s]) for s in sweep.variable_keys)
    )

    sweep.iteration_timestamps = []
    for variables in variables_list

        # remove the copy in memory
        sweep.iteration_cache = nothing
        for  dep in sweep.iteration_deps
            cleancacherecursive(dep)
        end

        for t in sweep.iteration_deps
            make(t, level+1; parameters..., variables...)
        end

        # Try to load a backup from disk
        path = iteration_fullpath(sweep, variables)
        if isfile(path)
            d = load(path)
            @info "Sweep $(sweep.name) iteration at $(NamedTuple(variables)) loaded from: $(relpath(path, projectdir()))"
            if d["hash"] == sweep.hash && d["params"] == merge(parameters, variables)
                sweep.iteration_cache      = d
                sweep.iteration_timestamp  = d["timestamp"]
                sweep.iteration_parameters = d["params"]
            end
        end

        if !iteration_cache_uptodate(sweep; parameters..., variables...)
            iteration_update!(sweep, variables, parameters)
        end

        push!(sweep.iteration_timestamps, sweep.iteration_timestamp)
    end

    if sweep.cache == nothing # this likely needs to become sweep.cache == nothing || sweep.parameters != parameters
        path = target_fullpath(sweep, parameters)
        if isfile(path)
            d = load(path)
            @info "Sweep $(sweep.name) at $(NamedTuple(parameters)) loaded from: $(relpath(path, projectdir()))"
            if d["hash"] == sweep.hash && d["params"] == parameters
                sweep.cache      = d["cache"]
                sweep.timestamp  = d["timestamp"]
                sweep.parameters = d["params"]
            end
        end
    end

    if !cache_uptodate(sweep; parameters)
        sweep_update!(sweep, variables_list, parameters)
    end

    return sweep.cache
end


function sweep_update!(sweep, variables_list, parameters)

    fullpath = target_fullpath(sweep, parameters)
    mkpath(dirname(fullpath))

    # collect the results in the .dir folder
    df = loadsims(iteration_dirname(sweep), variables_list)
    select!(df, Not([:timestamp, :hash, :path, :params]))

    sweep.cache = df
    sweep.timestamp = time()
    sweep.parameters = parameters

    save(fullpath, Dict(
        "cache" => sweep.cache,
        "timestamp" => sweep.timestamp,
        "hash" => hash,
        "params" => sweep.parameters))
end

function iteration_update!(sweep, variables, parameters)

    fullpath = iteration_fullpath(sweep, variables)
    mkpath(dirname(fullpath))

    shared_deps_vals = [t.cache for t in sweep.shared_deps]
    iteration_deps_vals = [t.cache for t in sweep.iteration_deps]

    @info "Computing sweep $(sweep.name) iteration at $(variables)"
    sweep.iteration_cache = sweep.recipe(
        shared_deps_vals...,
        iteration_deps_vals...,
        ; variables..., parameters...)
    sweep.iteration_timestamp = time()
    sweep.iteration_parameters = merge(variables, parameters)

    dct = merge(
        sweep.iteration_cache,
        (;
            timestamp=sweep.iteration_timestamp,
            hash=sweep.hash,
            params=sweep.iteration_parameters,
        ),
        (;sweep.iteration_parameters...),
    )

    # @show typeof(dct)
    # @show dct

    jldsave(fullpath; dct...)
end

function update!(target::Target; kwargs...)

    fullpath = target_fullpath(target, kwargs)
    mkpath(dirname(fullpath))
    # varname = String(target.name)

    # dirname = DrWatson.datadir(target.relpath)
    # filename = (joinpath(dirname, varname * ".jld2"))
    # mkpath(dirname)

    target.params = kwargs
    target.cache = target.recipe(getfield.(target.deps, :cache)...; kwargs...)
    target.timestamp = time()
    save(fullpath, Dict(
        target.name => target.cache,
        "timestamp" => target.timestamp,
        "hash" => target.hash,
        "params" => target.params))
end






macro target(out, recipe)

    @assert out isa Symbol
    @assert recipe.head == :->

    file_name = String(out) * ".jld2"

    tnames = []
    tp = recipe.args[1]
    if tp isa Symbol # special case for single argument
        push!(tnames, esc(tp))
    else
        @assert tp.head == :tuple
        for arg in tp.args
            arg isa Symbol || continue # skips kwargs
            push!(tnames, esc(arg))
        end
    end

    exists = isdefined(__module__, out)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out)).hash
                $(esc(out)).deps = [$(tnames...)]
                $(esc(out)).recipe = $(esc(recipe))
                $(esc(out)).timestamp = 0.0
                $(esc(out)).cache = nothing
                $(esc(out)).hash = $recipe_hash
                full_path = joinpath(Makeitso.BakerStreet.DrWatson.datadir($(esc(out)).relpath), $file_name)
                isfile(full_path) && rm(full_path)
            end
        end
    else
        fn = string(__source__.file)
        rp = dirname(relpath(fn, projectdir()))
        sn = splitext(basename(fn))[1]
        path = joinpath(rp, sn) # "examples/sweep"

        xp = :($(esc(out)) = Target($(String(out)), $(esc(recipe)),
            [$(tnames...)], $recipe_hash, $path))
    end
    return xp
end

# function sweep_expr(out, recipe)

#     args = recipe.args[1]
#     kwdargs = args.args[1]
#     posargs = args.args[2:end]
#     body = recipe.args[2]

#     @assert args.head == :tuple
#     @assert kwdargs.head == :parameters

#     atomics = filter(a -> (a isa Symbol), posargs)
#     sweeps = filter(a -> !(a isa Symbol), posargs)
#     sweeps = [s.args[2] for s in sweeps]

#     parnames = []
#     rngnames = []
#     for i in eachindex(kwdargs.args)
#         kwdargs.args[i] isa Expr || continue
#         kwdargs.args[i].head == :call || continue
#         push!(parnames, kwdargs.args[i].args[2])
#         push!(rngnames, kwdargs.args[i].args[3])
#         kwdargs.args[i] = kwdargs.args[i].args[3]
#     end

#     cfgnames = setdiff(kwdargs.args, rngnames)

#     args = Expr(:tuple, kwdargs, atomics...)

#     plargs = [esc(Expr(:kw, p, r)) for (p,r) in zip(parnames, rngnames)]
#     mkargs = [esc(Expr(:kw, p, r)) for (p,r) in zip(cfgnames, cfgnames)]
#     path = :(joinpath(Makeitso.BakerStreet.DrWatson.datadir($(out).relpath), $(String(out) * ".dir")))

#     gensyms = [Base.gensym(s) for s in  sweeps]
#     makes = Expr(:block, [
#         :( $(esc(g)) = make($(esc(s)); $(parnames...), $(mkargs...) ) )
#     for (s,g) in zip(sweeps, gensyms)]...)

#     body = MacroTools.postwalk(body) do x
#         i = findfirst(==(x), sweeps)
#         i !== nothing ? gensyms[i] : x
#     end

#     runsims = :(BakerStreet.runsims(payload, $(esc(path)); $(plargs...)))
#     xp = :(
#         $args -> begin
#             function payload(; $(parnames...) )
#                 $makes
#                 $(esc(body))
#             end
#             $((runsims))
#         end
#     )

#     return xp
# end


# macro sweep(out, recipe)
#     recipe = sweep_expr(out, recipe)

#     @assert out isa Symbol
#     @assert recipe.head == :->

#     file_name = String(out) * ".jld2"

#     tnames = []
#     tp = recipe.args[1]
#     if tp isa Symbol
#         push!(tnames, esc(tp))
#     else
#         @assert tp.head == :tuple
#         for arg in tp.args
#             arg isa Symbol || continue
#             push!(tnames, esc(arg))
#         end
#     end
#     recipe.args[1] = esc(recipe.args[1])

#     exists = isdefined(__module__, out)
#     recipe_hash = pihash(recipe)
#     if exists
#         xp = quote
#             if $recipe_hash != $(esc(out)).hash
#                 $(esc(out)).recipe = $((recipe))
#                 $(esc(out)).deps = Target[$(tnames...)]
#                 $(esc(out)).hash = $recipe_hash
#                 full_path = joinpath(BakerStreet.DrWatson.datadir($(esc(out)).relpath), $file_name)
#                 $(esc(out)).timestamp = 0.0
#                 $(esc(out)).cache = nothing
#                 isfile(full_path) && rm(full_path)
#             end
#         end
#     else
#         fn = string(__source__.file)
#         rp = dirname(relpath(fn, projectdir()))
#         sn = splitext(basename(fn))[1]
#         path = joinpath(rp, sn)

#         xp = :($(esc(out)) = Target($(String(out)), $((recipe)),
#             Target[$(tnames...)], $recipe_hash, $path))
#     end

#     return xp
# end


macro sweep(out, recipe)

    @assert out isa Symbol
    @assert recipe.head == :->

    file_name = String(out) * ".jld2"

    shared_deps = []
    iteration_deps = []
    variable_keys = []

    # process the dependency specification
    args = recipe.args[1]
    @assert args.head == :tuple

    for (i,arg) in pairs(args.args)
        if arg isa Expr && arg.head == :parameters
            for (j,p) in pairs(arg.args)
                if p isa Expr && p.head == :kw
                    push!(variable_keys, QuoteNode(p.args[1]))
                    arg.args[j] = p.args[1]
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

    # @show args
    # @show shared_deps
    # @show iteration_deps
    # @show variable_keys


    # tp = recipe.args[1]
    # if tp isa Symbol # special case for single argument
    #     push!(shared_deps, esc(tp))
    # else
    #     @assert tp.head == :tuple
    #     for arg in tp.args
    #         arg isa Symbol || continue # skips kwargs
    #         push!(shared_deps, esc(arg))
    #     end
    # end

    exists = isdefined(__module__, out)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out)).hash
                $(esc(out)).shared_deps = [$(shared_deps...)]
                $(esc(out)).iteration_deps = [$(iteration_deps...)]
                $(esc(out)).variables_keys = [$(variable_keys...)]
                $(esc(out)).recipe = $(esc(recipe))
                $(esc(out)).hash = $recipe_hash
                $(esc(out)).cache = nothing
                $(esc(out)).timestamp = 0.0
                $(esc(out)).parameters = nothing
                $(esc(out)).iteration_cache = nothing
                $(esc(out)).iteration_timestamp = 0.0
                $(esc(out)).iteration_parameters = nothing
                $(esc(out)).iteration_timestamps = []
                full_path = Makeitso.sweep_fullpath($(esc(out)))
                isfile(full_path) && rm(full_path)
            end
        end
    else
        fn = string(__source__.file)
        rp = dirname(relpath(fn, projectdir()))
        sn = splitext(basename(fn))[1]
        rp = joinpath(rp, sn) # "examples/sweep"

        xp = :(
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
                []
            )
        )
    end
    return xp
end

end # module

