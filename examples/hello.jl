using JLMake

# target_A = Target(:A, ()->rand(10))
# target_B = Target(:B, ()->rand(10))
# target_C = Target(:C, (A,B)->A.+B, tA, tB)


@target A ()->rand(10)
@target B ()->rand(10)
@target C (A,B)->A.+B


@target D (A,B,C)->A.+B.+C

@make A
@make C

#@update! B
@make C
C[end]


@which JLMake.Target(:D, ((A, B, C)->(A .+ B) .+ C), [target_A, target_B, target_C])

JLMake.Target(:D, ((A, B, C)->(A .+ B) .+ C), [target_A, target_B, target_C])
