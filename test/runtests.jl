using ManagedLoops: ManagedLoops, @loops, @vec, @unroll, parallel, barrier
using Test

struct PlainCPU <: ManagedLoops.HostManager end
ManagedLoops.offload(fun, ::PlainCPU, range, args...) = fun(range, args...)

@loops function test1!(_, a, b, c)
    let irange = eachindex(a, b, c)
        @vec for i in irange
            a[i] = @unroll sum( c[i]^n for n in 1:4)
            b[i] = c[i] + c[i]^2 + c[i]^3 + c[i]^4
        end
    end
end

@loops function test2!(_, a, b, c)
    let (irange, jrange) = axes(c)
        @unroll @vec for i in irange, j in jrange
            tup = ( c[i,j]^n for n in 1:4)
            a[i,j] = sum(tup)
            b[i,j] = c[i,j] + c[i,j]^2 + c[i,j]^3 + c[i,j]^4
        end
    end
end

@loops function test3!(_, a, b, c)
    let (irange, jrange) = axes(c)
        for j in jrange
            @vec for i in irange
                a[i,j] = @vec if b[i,j]>0 c[i,j] else c[i,j]^2 end
                b[i,j] = @vec b[i,j]>0 ? c[i,j] : c[i,j]^2
            end
        end
    end
end

function check(mgr, fun!, c)
    a, b = similar(c), similar(c)
    parallel(mgr) do local_mgr
        fun!(local_mgr, a, b, c)
        barrier(mgr)
    end
    return a ≈ b
end

function test_bc(mgr, dims)
    a, b, c = ( randn(dims) for i=1:3)
    @. mgr[a] = log(exp(b)*exp(c))
    return true
end

@testset "Macros" begin
    for mgr in (nothing, PlainCPU())
        @test check(mgr, test1!, randn(100))
        @test check(mgr, test2!, randn(100, 100))
        @test check(mgr, test3!, randn(100, 100))
    end
end

@testset "Broadcast" begin
    mgr = PlainCPU()
    @test test_bc(mgr, 1000)
    @test test_bc(mgr, (100,100))
    @test test_bc(mgr, (100,100,100))
    @test test_bc(mgr, (10,10,10))
end
