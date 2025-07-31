using Makeitso


@target A () -> 2
@target memonly=true B () -> "hello!"
@target M (A,B) -> (B * ", ")^A

x = make(M)
y = make(B)
println(x)

@info "--- Recipe for M modified! ---"
@target M (A,B) -> (B * "\n")^A
x = make(M)
y = make(B)
println(x)
