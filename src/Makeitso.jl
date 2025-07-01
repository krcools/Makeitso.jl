module Makeitso

using JLD2
using FileIO
using DrWatson
using BakerStreet
using DataFrames

export @target
export @sweep
export make
export getrow

mutable struct Target
    deps::Vector{Target}
    recipe
    timestamp
    cache
    name
    hash
    relpath
    params
end

function Target(name, recipe, deps::Vector{Target}, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname, nothing)
end

function make(target, level=0; kwargs...)

    for t in target.deps
        make(t, level+1; kwargs...)
    end

    varname = String(target.name)
    filename = String(target.name) * ".jld2"
    STORE_DIR = datadir(target.relpath)
    fullpath = joinpath(STORE_DIR, filename)

    # No file means this is the first run ever
    if !isfile(fullpath)
        update!(target; kwargs...)
        @info "level $level dep $(target.name): computed from dependencies [initial computation]."
        return target.cache
    end

    # Target was made in previous session. Is it up-to-date?
    deps_stamp = reduce(max, getfield.(target.deps, :timestamp), init=0.0)
    if target.cache == nothing
        d = load(fullpath)
        if d["hash"] != target.hash
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [recipe modified]."
        elseif d["params"] != kwargs
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [parameters modified]."
        elseif d["timestamp"] < deps_stamp
            update!(target; kwargs...)
            @info "level $level dep $(target.name) on disk but recomputed from deps [out-of-date]."
        else
            target.timestamp = d["timestamp"]
            target.cache = d[varname]
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
        update!(target; kwargs...)
        @info "level $level dep $(target.name) in memory but recomputed from deps [parameters modified]."
        return target.cache
    else
        @info "level $level dep $(target.name): retrieved from memory."
        return target.cache
    end
end


function update!(target::Target; kwargs...)

    varname = String(target.name)
    filename = String(target.name) * ".jld2"
    STORE_DIR = datadir(target.relpath)
    filename = joinpath(STORE_DIR, filename)
    mkpath(STORE_DIR)

    target.params = kwargs
    target.cache = target.recipe(getfield.(target.deps, :cache)...; kwargs...)
    target.timestamp = time()
    save(filename, Dict(
        varname => target.cache,
        "timestamp" => target.timestamp,
        "hash" => target.hash,
        "params" => target.params))
end



# Position independent hashing of expressions
pihash(x) = pihash(x, zero(UInt))
pihash(x::Expr,h) = pihash(x.args, pihash(x.head, h))
pihash(x::LineNumberNode,h) = h
function pihash(x::Array,h)
    for y in x
        h = pihash(y, h)
    end
    h
end
pihash(x::Any,h) = hash(x,h)


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
                $(esc(out)).deps = Target[$(tnames...)]
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
        path = joinpath(rp, sn)

        xp = :($(esc(out)) = Target($(QuoteNode(out)), $(esc(recipe)),
            Target[$(tnames...)], $recipe_hash, $path))
    end
    return xp
end

function sweep_expr(out, recipe)

    args = recipe.args[1]
    kwdargs = args.args[1]
    posargs = args.args[2:end]
    body = recipe.args[2]

    @assert args.head == :tuple
    @assert kwdargs.head == :parameters

    atomics = filter(a -> (a isa Symbol), posargs)
    sweeps = filter(a -> !(a isa Symbol), posargs)

    parnames = []
    rngnames = []
    for i in eachindex(kwdargs.args)
        kwdargs.args[i] isa Expr || continue
        kwdargs.args[i].head == :call || continue
        push!(parnames, kwdargs.args[i].args[2])
        push!(rngnames, kwdargs.args[i].args[3])
        kwdargs.args[i] = kwdargs.args[i].args[3]
    end

    args = Expr(:tuple, kwdargs, atomics...)

    plargs = [ esc(Expr(:kw, p, r)) for (p,r) in zip(parnames, rngnames)]
    path = :(joinpath(Makeitso.BakerStreet.DrWatson.datadir($(out).relpath), $(String(out) * ".dir")))

    makes = Expr(:block, [
        :( $(s.args[2]) = make($(esc(s.args[2])); $(parnames...) ) )
    for s in sweeps]...)

    runsims = :(BakerStreet.runsims(payload, $(esc(path)); $(plargs...)))
    xp = :(
        $args -> begin
            function payload(; $(parnames...) )
                $makes
                $body
            end
            $((runsims))
        end
    )

    return xp
end


macro sweep(out, recipe)
    recipe = sweep_expr(out, recipe)

    @assert out isa Symbol
    @assert recipe.head == :->

    file_name = String(out) * ".jld2"

    tnames = []
    tp = recipe.args[1]
    if tp isa Symbol
        push!(tnames, esc(tp))
    else
        @assert tp.head == :tuple
        for arg in tp.args
            arg isa Symbol || continue
            push!(tnames, esc(arg))
        end
    end
    recipe.args[1] = esc(recipe.args[1])

    exists = isdefined(__module__, out)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out)).hash
                $(esc(out)).deps = Target[$(tnames...)]
                $(esc(out)).recipe = $((recipe))
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
        path = joinpath(rp, sn)

        xp = :($(esc(out)) = Target($(QuoteNode(out)), $((recipe)),
            Target[$(tnames...)], $recipe_hash, $path))
    end

    return xp
end

end # module
