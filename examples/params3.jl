# debug how unused parameters are passed down

using Makeitso

@target A () -> begin
    1
end

@target B (A,;h) -> begin
    A * 2
end

@target C (B, ;h) -> begin
    @show h
    sqrt(B)
end

make(C; h=12)
make(C; h=13)

# TODO: filename hash for A does not need to depend on h