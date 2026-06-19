using Makeitso

@target A1 () -> (println("Building A1"); 2.0)
@target A2 () -> (println("Building A2"); 3.0)

@target B () -> (println("Building B"); pi)

@target C (B, ~A1, ~A2; p) -> begin
    x = if p < 3.0
        make(A1)
    elseif p < 5.0
        make(A2)
    else
        0.0
    end
end

@show make(C; p=2)