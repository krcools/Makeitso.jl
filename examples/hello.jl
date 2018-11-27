using JLMake

# target_A = Target(:A, ()->rand(10))
# target_B = Target(:B, ()->rand(10))
# target_C = Target(:C, (A,B)->A.+B, tA, tB)


@target A ()->rand(10)
@target B ()->rand(9+1)
@target C (A,B)->A.+B


@target D (A,B,C)->A.+B.+C

@make A
@make C
@make D
@show (@make D)[end]
