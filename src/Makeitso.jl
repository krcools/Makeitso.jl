module Makeitso

export @target
export @make
export make

using JLD2
using FileIO
using DrWatson
using BakerStreet


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

    # @show out
    # @show recipe

    @assert out isa Symbol
    @assert recipe.head == :->
    
    # modify recipe to accept kwargs
    tp = recipe.args[1]

    splitext(basename(string(__source__.file)))[1]
    # out_target = Symbol("target_", out)
    out_target = out
    file_name = String(out) * ".jld2"

    # vnames = [] # A, B, C
    tnames = [] # target, target_B, target_C

    # tp = recipe.args[1]
    if tp isa Symbol
        # push!(vnames, tp)
        # push!(tnames, esc(Symbol("target_", tp)))
        push!(tnames, esc(tp))
    else
        # @show tp.head
        @assert tp.head == :tuple
        for arg in tp.args
            arg isa Symbol || continue
            # push!(vnames, arg)
            # push!(tnames, esc(Symbol("target_", arg)))
            push!(tnames, esc(arg))
        end
    end

    exists = isdefined(__module__, out_target)
    recipe_hash = pihash(recipe)
    if exists
        xp = quote
            if $recipe_hash != $(esc(out_target)).hash
                $(esc(out_target)).deps = Target[$(tnames...)]
                $(esc(out_target)).recipe = $(esc(recipe))
                $(esc(out_target)).timestamp = 0.0
                $(esc(out_target)).cache = nothing
                $(esc(out_target)).hash = $recipe_hash
                full_path = joinpath(DrWatson.datadir($(esc(out_target)).relpath), $file_name)
                isfile(full_path) && rm(full_path)
                # isfile($file_name) && rm($file_name)
            end
        end
    else

        fn = string(__source__.file)
        rp = dirname(relpath(fn, projectdir()))
        sn = splitext(basename(fn))[1]
        path = joinpath(rp, sn)


        xp = :($(esc(out_target)) = Target($(QuoteNode(out)), $(esc(recipe)),
            Target[$(tnames...)], $recipe_hash, $path))
    end
    return xp
end


macro make(vname, vars...)
    # println(vars)
    # expr = symdict_expr_from_vars(vars)
    # println(expr)
    # tname = Symbol("target_", vname)
    tname = vname
    xp = :(make($(esc(tname))))
    return xp
end

end # module
