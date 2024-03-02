using ManagedLoops: @loops

@loops function test!(_, a, b)
    let irange = eachindex(a,b)
        for i in irange
            a[i] = exp(b[i])
        end
    end
end

a = randn(100)
b = randn(100)

test!(nothing, a, b)
