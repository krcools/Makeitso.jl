function fn_pars_hash(config)
    bn = DrWatson.savename(config)
    hs = hash(config)
    fn = string(bn, ".", hs)
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
    return joinpath(target_dirname(target), target.name * "." * fn_pars_hash(parameters) * ".jld2")
end

function sweep_dirname(sweep)
    return joinpath(DrWatson.datadir(sweep.relpath))
end

function sweep_fullpath(sweep)
    return joinpath(sweep_dirname(sweep), String(sweep.name) * ".jld2")
end

function iteration_dirname(sweep)
    return joinpath(DrWatson.datadir(sweep.relpath), String(sweep.name) * ".dir")
end

function iteration_fullpath(sweep, variables_dict)
    joinpath(iteration_dirname(sweep), fn_pars_hash(variables_dict) * ".jld2")
end

function iteration_cache_uptodate(sweep; kwargs...)
    if sweep.iteration_cache == nothing
        @info "Sweep $(sweep.name) iteration at $(NamedTuple(kwargs)) cache not available."
        return false
    end
    if sweep.iteration_timestamp < reduce(max, getfield.(vcat(sweep.shared_deps, sweep.iteration_deps), :timestamp), init=0.0)
        @info "Sweep $(sweep.name) iteration at $(NamedTuple(kwargs)) cache is out-of-date."
        return false
    end
    if sweep.iteration_parameters != Dict(kwargs)
        # @show sweep.iteration_parameters
        # @show Dict(kwargs)
        @info "Makeitso.jl: Sweep $(sweep.name) iteration at $(NamedTuple(kwargs)) parameters have changed."
        return false
    end
    @info "Sweep $(sweep.name) iteration at $(NamedTuple(kwargs)) is up-to-date."
    return true
end

function cache_uptodate(sweep; parameters)
    if sweep.cache == nothing
        @info "Sweep $(sweep.name) at $(parameters)not cached in memory."
        return false
    end
    if sweep.timestamp < reduce(max, sweep.iteration_timestamps, init=0.0)
        # @show sweep.timestamp
        # @show sweep.iteration_timestamps
        @info "Sweep $(sweep.name) cache is out-of-date."
        return false
    end
    if sweep.parameters != parameters
        @info "Sweep $(sweep.name) parameters have changed."
        return false
    end
    return true
end


function loadsims(dirname, configs=nothing)
    
    df = DrWatson.collect_results(datadir(dirname))
    configs == nothing && return df

    # @show df
    # @show configs

    df = filter!(df) do row
        # @show row
        for config in configs
            # @show config
            config_found = true
            for (k,v) in pairs(config)
                row[k] !== v && (config_found = false) && break
            end
            config_found && return true
        end
        return false
    end

    # @show df
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
            push!(tp.args, Expr(:parameters, Expr(:..., :kwargs)))
        end
    end
    return tp
end