using JLMake

# target_A = Target(:A, ()->rand(10))
# target_B = Target(:B, ()->rand(10))
# target_C = Target(:C, (A,B)->A.+B, tA, tB)


@target A ()->rand(10)
@target B ()->rand(10)
@target C (A,B)->A.+B

@make A
@make C

#@update! B
@make C
C[end]
