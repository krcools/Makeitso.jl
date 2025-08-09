# Like parames 2, but now with a mix of variables and parameters.

using Makeitso

@target A (;h) -> begin
    h + 1
end

@target B (A,;h, p) -> begin
    A * 2 + p
end

@sweep C (!B, ;h = H, p) -> begin
    @show h
    (;sol=sqrt(B))
end

make(C; h=[1,3,4], p=12)