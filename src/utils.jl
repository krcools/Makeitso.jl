function target_hash(target::Target, h=hash(nothing))
    for d in target.deps
        h = target_hash(d, h)
    end
    for d in target.weak_deps
        h = target_hash(d, h)
    end
    h = hash(target.hash, h)
    return h
end


function target_hash(target::Sweep, h=hash(nothing))
    for d in target.shared_deps
        h = target_hash(d, h)
    end
    for d in target.iteration_deps
        h = target_hash(d, h)
    end
        for d in target.weak_deps
        h = target_hash(d, h)
    end
    h = hash(target.hash, h)
    return h
end


function fn_pars_hash(target, config)
    bn = DrWatson.savename(config)
    hs = hash(config)
    hs = target_hash(target, hs)

    fn = bn == "" ? string(hs, base=62) : bn * "." * string(hs, base=62)
    return fn
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


function target_dirname(target)
    return joinpath(DrWatson.datadir(target.relpath), target.name * "." * fn_pars_hash(target, nothing) * ".dir")
    # return joinpath(DrWatson.datadir(target.relpath))
end

function target_fullpath(target, parameters)
    # return joinpath(target_dirname(target), target.name * "." * fn_pars_hash(target, parameters) * ".jld2")
    return joinpath(target_dirname(target), fn_pars_hash(target, parameters) * ".jld2")
end

# function sweep_dirname(sweep)
#     return joinpath(DrWatson.datadir(sweep.relpath))
# end

# function sweep_fullpath(sweep)
#     return joinpath(sweep_dirname(sweep), String(sweep.name) * ".jld2")
# end

# function iteration_dirname(sweep, parameters)
#     return joinpath(DrWatson.datadir(sweep.relpath), sweep.name * "." * fn_pars_hash(sweep, parameters) * ".dir")
# end

function iteration_fullpath(sweep, variables_dict, parameters_dict)
    # joinpath(iteration_dirname(sweep, nothing), fn_pars_hash(sweep, merge(parameters_dict, variables_dict)) * ".jld2")
    joinpath(target_dirname(sweep), fn_pars_hash(sweep, merge(parameters_dict, variables_dict)) * ".jld2")
end

function iteration_cache_uptodate(sweep; kwargs...)
    if sweep.iteration_cache == nothing
        # @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): cache empty."
        return false
    end
    if sweep.iteration_parameters != Dict(kwargs)
        # @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        # @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): recipe changed."
        return false
    end
    # @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): up-to-date."
    return true
end

function cache_uptodate(sweep::Sweep; parameters)
    if sweep.cache == nothing
        # @info "Sweep $(sweep.name) at $(parameters): cache empty."
        return false
    end
    if sweep.parameters != parameters
        # @info "Sweep $(sweep.name) at $(parameters): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        # @info "Sweep $(sweep.name) at $(parameters): recipe changed."
        return false
    end
    # @info "sweep $(sweep.name) at $(NamedTuple(parameters)): cache up-to-date."
    return true
end

function cache_uptodate(sweep::Target; parameters)
    if sweep.cache == nothing
        # @info "target $(sweep.name) at $(NamedTuple(parameters)): cache empty."
        return false
    end
    if sweep.params != parameters
        # @info "target $(sweep.name) at $(NamedTuple(parameters)): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        # @info "target $(sweep.name) at $(parameters): recipe changed."
        return false
    end
    # @info "target $(sweep.name) at $(NamedTuple(parameters)): cache up-to-date."
    return true
end


function loadsims(sweep, configs, parameters)

    dirname = target_dirname(sweep)
    rinclude = map(configs) do variables_dict
        fn = Regex(fn_pars_hash(sweep, merge(parameters, variables_dict)) * "\\.jld2")
    end

    # @show rinclude

    df = DrWatson.collect_results(datadir(dirname); rinclude=rinclude)
    configs == nothing && return df

    # @show configs
    # @show parameters
    # @show df

    l1 = size(df,1)

    df = filter!(df) do row
        for (k,v) in pairs(parameters)
            row[k] === missing && return false
            row[k] != v && return false
        end
        return true
    end

    # @show df
    l2 = size(df,1)
    @assert l1 == l2

    df = filter!(df) do row
        for config in configs
            config_found = true
            for (k,v) in pairs(config)
                row[k] === missing && (config_found = false) && break
                row[k] != v && (config_found = false) && break
            end
            config_found && return true
        end
        return false
    end

    # @show df
    l3 = size(df,1)
    @assert l1 == l3

    return df
end

function cleancacherecursive(target::Target)
    target.cache = nothing
    target.timestamp = 0.0
    for dep in target.deps
        cleancacherecursive(dep)
    end
end


function add_kwargs_to_args!(tp)
    if tp isa Symbol
        # Only positional, add kwargs... as a new parameters section
        tp = Expr(:tuple, tp, Expr(:parameters, Expr(:..., :kwargs)))
    elseif tp.head == :tuple
        # Look for :parameters section
        found = false
        for arg in tp.args
            if arg isa Expr && arg.head == :parameters
                push!(arg.args, Expr(:..., :kwargs))
                found = true
            end
        end
        # If no :parameters, add one
        if !found
            pushfirst!(tp.args, Expr(:parameters, Expr(:..., :kwargs)))
        end
    end
    return tp
end


function append_deps_parameter_keys!(target::Target, par_keys)
    for dep in target.deps
        append!(par_keys, dep.par_keys)
    end
    for dep in target.weak_deps
        append!(par_keys, dep.par_keys)
    end
    unique!(par_keys)
    return par_keys
end

function append_deps_parameter_keys!(target::Sweep, par_keys)
    for dep in target.shared_deps
        append!(par_keys, dep.par_keys)
    end
    for dep in target.iteration_deps
        append!(par_keys, dep.par_keys)
    end
    for dep in target.weak_deps
        append!(par_keys, dep.par_keys)
    end
    unique!(par_keys)
    return par_keys
end



function try_loading(target::Target, level, kwargs)

    path = target_fullpath(target, kwargs)
    if isfile(path)
        d = load(path)
        # @info "target $(target.name) at $(NamedTuple(kwargs)): read $(relpath(path, projectdir()))."
        if d["hash"]      == target.hash        &&
           d["params"]    == kwargs             &&
           d["tree_hash"] == target_hash(target)

            target.cache      = d[target.name]
            target.timestamp  = d["timestamp"]
            target.params     = d["params"]
            target.tree_hash  = d["tree_hash"]
        else
            # @info "target $(target.name) at $(NamedTuple(kwargs)): backup recipe or parameters incorrect."
        end
    else
        # @info "target $(target.name) at $(NamedTuple(kwargs)): no backup at $(relpath(path, projectdir()))."
    end
end


function try_loading(sweep::Sweep, level, kwargs)
    path = target_fullpath(sweep, kwargs)
    if isfile(path)
        d = load(path)
        # @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): read $(relpath(path, projectdir()))"
        if  (d["hash"]      == sweep.hash) &&
            (d["params"]    == kwargs)     &&
            (d["tree_hash"] == sweep.tree_hash)

            sweep.cache      = d["cache"]
            sweep.timestamp  = d["timestamp"]
            sweep.parameters = d["params"]
            sweep.tree_hash  = d["tree_hash"]
        else
            # @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): backup recipe or parameters incorrect."
        end
    else
        # @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): no backup at $(relpath(path, projectdir()))"
    end
end


function try_loading_iteration(sweep::Sweep, level, variables, parameters)
    path = iteration_fullpath(sweep, variables, parameters)
    if isfile(path)
        d = load(path)
        # @info "iteration $(sweep.name) at $(NamedTuple(variables)): read $(relpath(path, projectdir()))"
        if d["hash"] == sweep.hash &&
            d["params"] == merge(parameters, variables) &&
            d["tree_hash"] == sweep.tree_hash

            sweep.iteration_cache      = d
            sweep.iteration_timestamp  = d["timestamp"]
            sweep.iteration_parameters = d["params"]
            sweep.tree_hash            = d["tree_hash"]
        else
            # @info "iteration $(sweep.name) at $(NamedTuple(variables)): backup recipe or parameters incorrect."
        end
    else
        # @info "iteration $(sweep.name) at $(NamedTuple(variables)): no backup at $(relpath(path, projectdir()))"
    end
end


function weak_dep_make_call_expr(dep::Symbol, explicit_keys::Vector{Symbol})
    kwargs_args = Any[explicit_keys..., Expr(:..., :kwargs)]
    return Expr(:call, :make, Expr(:parameters, kwargs_args...), dep)
end


function is_make_call_head(x)
    x === :make && return true
    if x isa Expr && x.head == :. && length(x.args) == 2
        return x.args[2] == QuoteNode(:make)
    end
    return false
end


function rewrite_weak_dep_expr(x, weak_dep_syms::Set{Symbol}, explicit_keys::Vector{Symbol})
    if x isa Symbol
        if x in weak_dep_syms
            return weak_dep_make_call_expr(x, explicit_keys)
        end
        return x
    elseif x isa QuoteNode
        return x
    elseif !(x isa Expr)
        return x
    end

    if x.head == :quote
        return x
    end

    if x.head == :call && !isempty(x.args) && is_make_call_head(x.args[1])
        return x
    end

    if x.head == :(=) || x.head == :kw
        if length(x.args) < 2
            return x
        end
        args = Any[x.args[1]]
        append!(args, rewrite_weak_dep_expr.(x.args[2:end], Ref(weak_dep_syms), Ref(explicit_keys)))
        return Expr(x.head, args...)
    end

    if x.head == :->
        @assert length(x.args) == 2
        return Expr(:->, x.args[1], rewrite_weak_dep_expr(x.args[2], weak_dep_syms, explicit_keys))
    end

    if x.head == :function
        @assert length(x.args) == 2
        return Expr(:function, x.args[1], rewrite_weak_dep_expr(x.args[2], weak_dep_syms, explicit_keys))
    end

    new_args = rewrite_weak_dep_expr.(x.args, Ref(weak_dep_syms), Ref(explicit_keys))
    return Expr(x.head, new_args...)
end


function preprocess_weak_dep_recipe!(recipe::Expr, weak_dep_symbols::Vector{Symbol}, explicit_keys::Vector{Symbol})
    isempty(weak_dep_symbols) && return recipe
    @assert recipe.head == :->
    weak_dep_syms = Set(weak_dep_symbols)
    recipe.args[2] = rewrite_weak_dep_expr(recipe.args[2], weak_dep_syms, explicit_keys)
    return recipe
end