module Makeitso

export @target
export @make
#export @update!

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
end

function Target(name, recipe, deps::Vector{Target}, hash, simname)
    t = Target(deps, recipe, 0.0, nothing, name, hash, simname)
end

function make(target, level=0)
    for t in target.deps
        make(t, level+1)
    end

    varname = String(target.name)
    filename = String(target.name) * ".jld2"
    STORE_DIR = datadir(target.relpath)
    filename = joinpath(STORE_DIR, filename)

    # No file means this is the first run ever
    if !isfile(filename)
        update!(target)
        @info "level $level dep $(target.name): computed from dependencies [initial computation]."
        return target.cache
    end

    # Target was made in previous session. Is it up-to-date?
    deps_stamp = reduce(max, getfield.(target.deps, :timestamp), init=0.0)
    if target.cache == nothing
        d = load(filename)
        if d["hash"] != target.hash
            update!(target)
            @info "level $level dep $(target.name): computed from dependencies [recipe modified]."
        elseif d["timestamp"] < deps_stamp
            update!(target)
            @info "level $level dep $(target.name): computed from dependencies [store out-of-date]."
        else
            target.timestamp = d["timestamp"]
            target.cache = d[varname]
            @info "level $level dep $(target.name): restored from disk."
        end
        return target.cache
    end

    # Target was computed in this session. Is it up-to-date?
    if target.timestamp < deps_stamp
        update!(target)
        @info "level $level dep $(target.name): computed from dependencies [memory cache out-of-date]."
        return target.cache
    else
        @info "level $level dep $(target.name): retrieved from memory cache."
        return target.cache
    end
end


function update!(target::Target)

    varname = String(target.name)
    filename = String(target.name) * ".jld2"
    STORE_DIR = datadir(target.relpath)
    filename = joinpath(STORE_DIR, filename)
    mkpath(STORE_DIR)

    target.cache = target.recipe(getfield.(target.deps, :cache)...)
    target.timestamp = time()
    save(filename, Dict(
        varname => target.cache,
        "timestamp" => target.timestamp,
        "hash" => target.hash))
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

    splitext(basename(string(__source__.file)))[1]
    out_target = Symbol("target_", out)
    file_name = String(out) * ".jld2"
    # file_name = joinpath(STORE_DIR, file_name)

    vnames = [] # A, B, C
    tnames = [] # target, target_B, target_C

    tp = recipe.args[1]
    if tp isa Symbol
        push!(vnames, tp)
        push!(tnames, esc(Symbol("target_", tp)))
    else
        @assert tp.head == :tuple
        for arg in tp.args
            push!(vnames, arg)
            push!(tnames, esc(Symbol("target_", arg)))
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


macro make(vname)
    tname = Symbol("target_", vname)
    xp = :($(esc(vname)) = make($(esc(tname))))
    return xp
end

end # module
