# debug parameter transformation

using Makeitso

@target A (;h) -> begin
    h
end

@target B1 (A(;h=h1),;h1) -> begin
    2 * A
end

@target B2 (A(;h=h2),;h2) -> begin
    3 * A
end

@target C (B1, B2) -> begin
    B1 + B2
end

make(C; h1=1, h2=2)
make(C; h1=3, h2=-1)
