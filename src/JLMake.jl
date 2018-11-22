module JLMake

export Target
export make
export @target
export @make
export @update!

using JLD2
using FileIO

mutable struct Target
    deps::Vector{Target}
    recipe
    timestamp
    cache
    name
end

function Target(name, recipe, deps...)
    t = Target([deps...], recipe, 0.0, nothing, name)
end


function make(target)
    for t in target.deps
        make(t)
    end

    varname = String(target.name)
    filename = String(target.name) * ".jld2"

    # No file means this is the first run ever
    !isfile(filename) && (update!(target); return target.cache)

    # Target was made in previous session. Is it up-to-date?
    deps_stamp = reduce(max, getfield.(target.deps, :timestamp), init=0.0)
    if target.cache == nothing
        d = load(filename)
        if d["timestamp"] < deps_stamp
            update!(target)
        else
            target.timestamp = d["timestamp"]
            target.cache = d[varname]
        end
        return target.cache
    end

    # Target was computed in this session. Is it up-to-date?
    if target.timestamp < deps_stamp
        update!(target)
    end

    return target.cache
end


function update!(target::Target)

    varname = String(target.name)
    filename = String(target.name) * ".jld2"

    target.cache = target.recipe(getfield.(target.deps, :cache)...)
    target.timestamp = time()
    save(filename, Dict(
        varname => target.cache,
        "timestamp" => target.timestamp))
end

function update!(target::Target, val)

    target.cache = val
    target.timestamp = time()

    varname = String(target.name)
    filename = String(target.name) * ".jld2"

    save(filename, Dict(
        varname => target.cache,
        "timestamp" => target.timestamp))
end

macro update!(var)
    :(update!($(esc(Symbol("target_",var)))))
end

macro update!(var, val)
    :(update!($(esc(Symbol("target_",var))), $(esc(val))))
end

macro target(out, recipe)


    @assert out isa Symbol
    @assert recipe.head == :->

    out_target = Symbol("target_", out)

    vnames = [] # A, B, C
    tnames = [] # target, target_B, target_C

    tp = recipe.args[1]
    @assert tp.head == :tuple
    for arg in tp.args
        push!(vnames, arg)
        push!(tnames, esc(Symbol("target_", arg)))
    end

    :($(esc(out_target)) = Target($(QuoteNode(out)), $(esc(recipe)), $(tnames...)))
end


macro make(vname)
    tname = Symbol("target_", vname)
    :($(esc(vname)) = make($(esc(tname))))
end

end # module
