module Mod

export @changeifexists

mutable struct MyStruct
    cache
    hash
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


macro changeifexists(x, recipe)
    exists = isdefined(__module__, x)
    @show recipe
    @show h = pihash(recipe)
    if exists
        xp = quote
            if $h != $(esc(x)).hash
                $(esc(x)).cache = nothing
            end
        end
    else
        xp = :($(esc(x)) = MyStruct(nothing, $h))
    end

    return xp
end

end

using .Mod
@changeifexists A (A)->3
A.cache = 3

@changeifexists A (A)->3
@show A.cache == 3

@changeifexists A (A)->4
@show A.cache == nothing
