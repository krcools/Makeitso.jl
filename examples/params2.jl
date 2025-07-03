using Makeitso

@target A (;h) -> begin
    h + 1
end

@target B (A,;h) -> begin
    A * 2
end

@sweep C (!B, ;h in hs) -> begin
    @show h
    (;sol=sqrt(B))
end

make(C; hs=[1,2,3])