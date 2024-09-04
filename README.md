# ManagedLoops

[![CI](https://github.com/ClimFlows/ManagedLoops/actions/workflows/CI.yml/badge.svg)](https://github.com/ClimFlows/ManagedLoops/actions/workflows/CI.yml)
[![Code Coverage](https://codecov.io/gh/ClimFlows/ManagedLoops/branch/main/graph/badge.svg)](https://codecov.io/gh/ClimFlows/ManagedLoops)

`ManagedLoops` defines an API to separate the task of writing loops from the task of defining how to
execute the loops (e.g. using SIMD, multiple threads, or on a GPU). In addition it provides convenience macros
`@unroll` to unroll loops whose length is known at *parse* time and `@vec` to mark loops as suitable for SIMD vectorization.

The API is based on the abstract type `LoopManager` and its descendents, and on the function `offload`.
Manager types deriving from `LoopManager` offer different iteration strategies, see package [`LoopManagers`](https://github.com/ClimFlows/LoopManagers.jl).
Function `offload` may be called directly (lower-level API), or may hide behind the `@loops` macro (higher-level API).

`ManagedLoops` is very lightweight and depends only on `MacroTools`. Thus, making it a dependency of your "provider" modules, where number-crunching routines are defined, is very cheap. [`LoopManagers`](https://github.com/ClimFlows/LoopManagers.jl) is a more heavyweight package, but only "consumer" modules, those which create loop managers and pass them to functions, need to depend on it.

Furthermore the high-level API is designed to have a small entry cost (loops must be placed in loop-only functions) and a zero exit cost:
* If do not want to depend on `LoopManagers`,  pass `nothing` as the first argument of `@loops` functions and they will work "normally", as if `@loops` and `@vec` were not there.
* If you decide to drop `ManagedLoops` altogether, simply remove `@loops` and `@vec` and your code just works.

## High-level user API

### Single loop

```julia
    using LoopManagers: @loops, @vec

    @loops function loop1!(_, x, y) # do not omit the unused first argument !
        let irange = eachindex(x,y)
            @vec for i in irange   # signals that this loop supports vectorization
                # do some work at index i
                # when indexing arrays, `i` should always be innermost (first) due to `@vec`
            end
        end
    end

    loop!(x,y) = loop1!(nothing, x, y) # plain loop, no manager needed
    loop1!(mgr::LoopManager, x, y) # loops are "managed" by `mgr`, provided for instance by `LoopManagers`
```

### Two nested loops

```julia
    @loops function loop2!(_, x, y)
        let (irange, jrange) = axes(x) # these ranges are "managed"
            # we can have an outer loop here, whose range will not be "managed"
            for j in jrange
                # do some computation shared by all indices i
                @vec for i in irange
                    # do some work at index i, j
                    # we can have a non-managed inner loop here
                end
            end
        end
    end

    loop2!(nothing, x, y)
    loop2!(mgr::LoopManager, x, y)
```

### Current limitations

"supports vectorization" means no conditional branching / flow control inside the loop. Ternary expressions `a ? b : c` and `if-then-else` expressions may be used if prepended with the `@vec` macro, e.g.:
```julia
    @vec for i in irange
        x[i] = @vec if y[i]>0 ; log(y[i]) ; else zero(y[i]); end
        x[i] = @vec y[i]>0 ? log(y[i]) : zero(y[i])
    end
```

Type annotations are not supported with `@loops`. This limitation could be relaxed with some work.

## Under the hood

The `@loops` macro expands to something similar to the following.

### Single loop

```julia
    function loop1!(irange, x, y)
        @vec for i in irange
            # do some work at index i
        end
    end

    loop1!(mgr, x, y) = offload(loop1!, mgr, eachindex(x,y), x, y)
```

### Two nested loops
```julia
    function loop2!((irange, jrange), x, y)
        for j in jrange
            # do some computation shared by all indices i
            @vec for i irange
                # do some work at index i
            end
        end
    end

    loop2!(mgr, x, y) = offload(loop2!, mgr, axes(x), x, y)
```

## Other

### Managed broadcast

Broadcast expressions such as `@. x = sin(y)` are semantically equivalent to loops. To manage the implied loop with `mgr::LoopManager`, use:
```julia
@. mgr[x] = sin(y)
```
or, if `x` is a function argument, pass `mgr[x]` instead of `x`. Since this works by specializing functions in Base Julia,
this can be used with function defined in modules that are not using `LoopManagers` at all.

```julia
# function definition, possibly in a module that knows nothing about LoopManagers
f!(x,y) = @. x = sin(y)

# elsewhere call f(x,y) as usual
f!(x,y)
# we can also let `mgr::LoopManager` control the loops
f!(mgr[x], y)
```

### @unroll macro

`@unroll (x^2 for x in (1,2,3))` expands to `(1^2, 2^2, 3^2)`.

```julia
    @unroll for x in 1:3
        myfun(x)
    end
```
expands to :

```julia
    myfun(1)
    myfun(2)
    myfun(3)
```

Only tuples and ranges with elements or bounds known at *parse time* are supported. To use this macro with type parameters, one may use generated functions.

```julia
    @generated function fun(x::MyType{N}) where N
        quote
            @vec for i in 1:$N
                otherfun(i, x)
            end
        end
    end
```

### Experimental

`ManagedLoops` also defines `parallel`, `barrier`, `master`, `share` to support
OpenMP-like execution with long-lived threads. This is currently experimental and not more performant than short-lived threads launched at each outer loop.

## Change Log

### 0.1.7
* `@vec` for ternary operator. `@vec a ? b : c` now expands to `choose(a, ()->b, ()->c)`

### 0.1.6
* `@vec` for `if-then-else` expressions. `@vec if a ; b ; else c ; end` now expands to `choose(a, ()->b, ()->c)`. `choose(a, B, C)` evaluates only `B()` (resp. `C()`) when `a` is all `true` (resp. all `false`). Otherwise both are evaluated and blended.

### 0.1.5
* support for "managed broadcasting": if the l.h.s of a broadcast expression `@. lhs = rhs` is of the form `lhs = mgr[array]` then the broadcast loop is managed by `mgr`. Limited to 4D arrays for the moment.
