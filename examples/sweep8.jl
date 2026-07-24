# test the method for sweep that takes a positional arugment of type Over

using Makeitso

@target base () -> 10

module Mod
    function f(x)
        return x + 1
    end

    function square_root(x)
        return sqrt(x)
    end
end

@target ore (;seed, p) -> begin
    y= Mod.f(seed) + p
    return y
end

@sweep solutions (base, !ore, ;seed = [], p) -> begin
    return (;sol = Mod.square_root(ore) + base)
end

@target average (solutions,;seed, p) -> begin
    sum(solutions.sol)
end

# x = make(average; seed=[1.0,2.0,3.0], p=3.14)
# y = make(solutions; seed=[1.0,2.0,3.0], p=3.14)

x = make(average, verbosity(:variables); seed=[1.0,2.0,3.0], p=3.14)
# y = make(solutions, verbosity(:short); seed=[1.0,2.0,3.0], p=3.14)

# @info "Building zs"
# z1 = sweep(average; seed=Ref([1.0,2.0,3.0]), p=[2.78, 3.14])
# z2 = sweep(average; seed=[[1.0,2.0,3.0], [4.0,5.0,6.0]], p=[2.78, 3.14])

# @info "Building ws"
# w1 = sweep(average, over(:p); seed=[1.0,2.0,3.0], p=[2.78, 3.14])
# w2 = sweep(average, over(:seed, :p); seed=[[1.0,2.0,3.0], [4.0,5.0,6.0]], p=[2.78, 3.14])
