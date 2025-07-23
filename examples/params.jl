module HelloKW

using Makeitso

@target A (;h) -> begin
    # println(h)
    return 1:10
end

@target B (;h)->[-4,-3,-2,-1,0,1,2,3,4,5]
@target C (A,B;h)->A.+B
@target D (A,B,C;h)->A.+B.+C

x = make(D; h=2)[end]
@assert x == 30

@target B (;h)->pi
println("--- Recipe for B modified! ---")

x = make(D; h=2)[end]
@assert x ≈ (20+2pi)

x = make(D; h=3)[end]
x = make(D; h=2)[end]

end