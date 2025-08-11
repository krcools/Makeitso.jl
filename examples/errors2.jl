# demonstrate parameter transformation using the motivating example
# of computing a sequence of approximation errors w.r.t. a chosen
# reference solution computed by the same target. Approach using targets
# and an ad-hoc sweep.

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

@target approx_error (refsol, approx; n, nref) -> begin
    @show approx
    @show refsol
    abs(approx - refsol)
end

sweep(approx_error; n=collect(1:10), nref=16)

# This is not ideal because refsol is computed 10 times instead of just once.
# On the other hand, refsol is only a thin wrapper around the solution target,
# so the overhead is minimal. The expensive target solution is computed 11 times,
# as intended.