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