using ManagedLoops: @loops, @vec, @unroll
using Test

@loops function test!(_, a, b, c)
    let irange = eachindex(a, b, c)
        @vec for i in irange
            a[i] = @unroll sum( c[i]^n for n in 1:4)
            b[i] = c[i] + c[i]^2 + c[i]^3 + c[i]^4
        end
    end
end

@testset "Macros" begin
    c = randn(100)
    a, b = similar(c), similar(c)
    test!(nothing, a, b, c)
    @test a ≈ b
end
