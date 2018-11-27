using Makeitso

@target A ()->rand(10)
@target B ()->rand(10)
@target C (A,B)->A.+B


@target D (A,B,C)->A.+B.+C

@make A
@make C
@make D
@show (@make D)[end]
