using Makeitso

@target A1 (;h) -> (println("A1: h=$h"); h + 1)
@target A2 (;p) -> (println("A2: p=$p"); p + pi)

@target C () -> 123
@target D (;h, p) -> (println("D: h=$h, p=$p"); h + p)

@sweep B (C, !D, ~A1, ~A2; h = [], p = []) -> begin
    @show h
    @show p
    x1 = make(A1; h=h)
    x2 = make(A2; p=p)
    (;sol=x1+x2+C+D)
end

df = make(B; h=[1,2], p=[10,20])