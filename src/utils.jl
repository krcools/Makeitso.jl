function target_hash(target::Target, h=hash(nothing))
    for d in target.deps
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
    h = hash(target.hash, h)
    return h
end


function fn_pars_hash(target, config)
    bn = DrWatson.savename(config)
    hs = hash(config)
    hs = target_hash(target, hs)

    fn = bn == "" ? string(hs) : string(bn, ".", hs)
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
    return joinpath(DrWatson.datadir(target.relpath))
end

function target_fullpath(target, parameters)
    return joinpath(target_dirname(target), target.name * "." * fn_pars_hash(target, parameters) * ".jld2")
end

function sweep_dirname(sweep)
    return joinpath(DrWatson.datadir(sweep.relpath))
end

function sweep_fullpath(sweep)
    return joinpath(sweep_dirname(sweep), String(sweep.name) * ".jld2")
end

function iteration_dirname(sweep, parameters)
    return joinpath(DrWatson.datadir(sweep.relpath), sweep.name * "." * fn_pars_hash(sweep, parameters) * ".dir")
end

function iteration_fullpath(sweep, variables_dict, parameters_dict)
    joinpath(iteration_dirname(sweep, nothing), fn_pars_hash(sweep, merge(parameters_dict, variables_dict)) * ".jld2")
end

function iteration_cache_uptodate(sweep; kwargs...)
    if sweep.iteration_cache == nothing
        @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): cache empty."
        return false
    end
    if sweep.iteration_parameters != Dict(kwargs)
        @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): recipe changed."
        return false
    end
    @info "iteration $(sweep.name) at $(NamedTuple(kwargs)): up-to-date."
    return true
end

function cache_uptodate(sweep::Sweep; parameters)
    if sweep.cache == nothing
        @info "Sweep $(sweep.name) at $(parameters): cache empty."
        return false
    end
    if sweep.parameters != parameters
        @info "Sweep $(sweep.name) at $(parameters): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        @info "Sweep $(sweep.name) at $(parameters): recipe changed."
        return false
    end
    @info "sweep $(sweep.name) at $(NamedTuple(parameters)): cache up-to-date."
    return true
end

function cache_uptodate(sweep::Target; parameters)
    if sweep.cache == nothing
        @info "target $(sweep.name) at $(NamedTuple(parameters)): cache empty."
        return false
    end
    if sweep.params != parameters
        @info "target $(sweep.name) at $(NamedTuple(parameters)): parameters changed."
        return false
    end
    if sweep.tree_hash != target_hash(sweep)
        @info "target $(sweep.name) at $(parameters): recipe changed."
        return false
    end
    @info "target $(sweep.name) at $(NamedTuple(parameters)): cache up-to-date."
    return true
end


function loadsims(dirname, configs, parameters)
    
    @show dirname
    df = DrWatson.collect_results(datadir(dirname))
    configs == nothing && return df

    # @show "before parameter filtering" df

    df = filter!(df) do row
        for (k,v) in pairs(parameters)
            row[k] !== v && return false
        end
        return true
    end

    # @show "before config filtering" df

    df = filter!(df) do row
        for config in configs
            config_found = true
            for (k,v) in pairs(config)
                row[k] !== v && (config_found = false) && break
            end
            config_found && return true
        end
        return false
    end

    # @show "after filtering" df

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


function append_deps_parameter_keys!(target::Target, parameter_keys)
    for dep in target.deps
        append!(parameter_keys, dep.parameter_keys)
    end
    unique!(parameter_keys)
    return parameter_keys
end

function append_deps_parameter_keys!(target::Sweep, parameter_keys)
    for dep in target.shared_deps
        append!(parameter_keys, dep.parameter_keys)
    end
    for dep in target.iteration_deps
        append!(parameter_keys, dep.parameter_keys)
    end
    unique!(parameter_keys)
    return parameter_keys
end



function try_loading(target::Target, kwargs)

    path = target_fullpath(target, kwargs)
    if isfile(path)
        d = load(path)
        @info "target $(target.name) at $(NamedTuple(kwargs)): read $(relpath(path, projectdir()))."
        if d["hash"]      == target.hash        &&
           d["params"]    == kwargs             &&
           d["tree_hash"] == target_hash(target)

            target.cache      = d[target.name]
            target.timestamp  = d["timestamp"]
            target.params     = d["params"]
            target.tree_hash  = d["tree_hash"]
        else
            @info "target $(target.name) at $(NamedTuple(kwargs)): backup recipe or parameters incorrect."
        end
    else
        @info "target $(target.name) at $(NamedTuple(kwargs)): no backup at $(relpath(path, projectdir()))."
    end
end


function try_loading(sweep::Sweep, kwargs)
    path = target_fullpath(sweep, kwargs)
    if isfile(path)
        d = load(path)
        @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): read $(relpath(path, projectdir()))"
        if  (d["hash"]      == sweep.hash) &&
            (d["params"]    == kwargs)     &&
            (d["tree_hash"] == sweep.tree_hash)

            sweep.cache      = d["cache"]
            sweep.timestamp  = d["timestamp"]
            sweep.parameters = d["params"]
            sweep.tree_hash  = d["tree_hash"]
        else
            @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): backup recipe or parameters incorrect."
        end
    else
        @info "sweep $(sweep.name) at $(NamedTuple(kwargs)): no backup at $(relpath(path, projectdir()))"
    end
end


function try_loading_iteration(sweep::Sweep, variables, parameters)
    path = iteration_fullpath(sweep, variables, parameters)
    if isfile(path)
        d = load(path)
        @info "iteration $(sweep.name) at $(NamedTuple(variables)): read $(relpath(path, projectdir()))"
        if d["hash"] == sweep.hash &&
            d["params"] == merge(parameters, variables) &&
            d["tree_hash"] == sweep.tree_hash

            sweep.iteration_cache      = d
            sweep.iteration_timestamp  = d["timestamp"]
            sweep.iteration_parameters = d["params"]
            sweep.tree_hash            = d["tree_hash"]
        else
            @info "iteration $(sweep.name) at $(NamedTuple(variables)): backup recipe or parameters incorrect."
        end
    else
        @info "iteration $(sweep.name) at $(NamedTuple(variables)): no backup at $(relpath(path, projectdir()))"
    end
end