module HelloKW

using Makeitso

@target A (;h) -> begin
    # @show kwargs
    println(h)
    # error()
    return 1:10
end

@target B (;h)->[-4,-3,-2,-1,0,1,2,3,4,5]
@target C (A,B;h)->A.+B
@target D (A,B,C;h)->A.+B.+C

x = Makeitso.make(D; h=2)[end]
@assert x == 30

@target B (;h)->pi
println("--- Recipe for B modified! ---")

x = Makeitso.make(D; h=2)[end]
@assert x ≈ (20+2pi)

x = Makeitso.make(D; h=3)[end]
x = Makeitso.make(D; h=2)[end]
# x = @make D h=3


# function qq(;kwargs...)

#     @show typeof(kwargs)
#     @show kwargs

#     return kwargs
# end

# xp = :(
#     (A,B) -> begin
#         A+B
#     end
# )

end