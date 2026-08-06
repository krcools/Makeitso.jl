using Makeitso

@target A1 (;h,q) -> (println("A1: h=$h, q=$q"); h + q)
@target A2 (;p) -> (println("A2: p=$p"); p + pi)

@target C () -> 123
@target D (;h, p) -> (println("D: h=$h, p=$p"); h + p)

@sweep B (C, !D, ~A1, ~A2; h = [], p = []) -> begin
    @show h
    @show p
    x = if p == 10
        make(A1; h=2p, q=5)
    else
        A2
    end
    # x1 = make(A1; h=h)
    # x2 = make(A2; p=p)
    (;sol=x+C+D)
end

df = make(B; h=[1,2], p=[10,20])

ex = @macroexpand @sweep B (C, !D, ~A1, ~A2; h = [], p = []) -> begin
    # @show h
    # @show p
    x = if p == 10
        make(A1; h=2p, q=5)
    else
        A2
    end
    # x1 = make(A1; h=h)
    # x2 = make(A2; p=p)
    (;sol=x+C+D)
end

Base.remove_linenums!(ex)