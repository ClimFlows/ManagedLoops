# ManagedLoops

`ManagedLoops` defines an API to separate the task of writing loops from the task of defining how to
execute the loops (e.g. using SIMD, multiple threads, or on a GPU). In addition it provides convenience macros
`@unroll` to unroll loops whose length is known at *parse* time and `@vec` to mark loops as suitablecfor SIMD vectorization.

The API is based on the abstract type `LoopManager` and its descendents, and on the function `offload`.
Manager types deriving from `LoopManager` offer different iteration strategies, see package `LoopManagers`.
Function `offload` may be called directly, or may hide behind the `@loops` macro.

## Single loop

```
    function loop1(range, args...)
        # do some computation shared by all indices i
        for i irange
            # do some work at index i
        end
    end

    offload(loop1, mgr::LoopManager, range, args...)
```

## Two nested loops
```
    function loop2((irange, jrange), args...)
        # do some computation shared by all indices i,j
        for j in jrange
            # do some computation shared by all indices i
            for i irange
                # do some work at index i
            end
        end
    end

    offload(loop2, mgr::LoopManager, (irange, jrange), args...)
```

`ManagedLoops` also defines `parallel`, `barrier`, `master`, `share` to support
OpenMP-like execution with long-lived threads. This is currently experimental and not more performant than short-lived threads launched at each outer loop.
