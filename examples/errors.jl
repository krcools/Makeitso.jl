# demonstrate parameter transformation using the motivating example
# of computing a sequence of approximation errors w.r.t. a chosen
# reference solution computed by the same target.

using Makeitso

@target solution (; n) -> begin
    @show "solution" n
    round(π, digits=n)
end

@target approx (solution,; n) -> begin
    @show "approx" n
    solution
end

@target refsol (solution(;n=nref),; nref) -> begin
    return solution
end

@sweep approx_error (refsol, !approx; n = N, nref) -> begin
    @show approx
    @show refsol
    (;error = abs(approx - refsol))
end

make(approx_error; n=collect(1:10), nref=16)