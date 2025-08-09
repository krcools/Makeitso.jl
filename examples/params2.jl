using Makeitso

@target A (;h) -> begin
    h + 1
end

@target B (A,;h) -> begin
    A * 2
end

@sweep C (!B, ;h = H) -> begin
    @show h
    (;sol=sqrt(B))
end

make(C; h=[1,2])