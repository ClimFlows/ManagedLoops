"""
Module `ManagedLoops` defines an API to separate the task of writing loops from the task of defining how to
execute the loops (e.g. using SIMD, multiple threads, or on a GPU). In addition it provides convenience macros
[`@unroll`](@ref) to unroll loops whose length is known at *parse* time and [`@vec`](@ref) to mark loops as suitable
for SIMD vectorization.

The API is based on the abstract type [`LoopManager`](@ref) and its descendents, and on the function [`offload`](@ref).
Manager types deriving from [`LoopManager`](@ref) offer different iteration strategies, see package `LoopManagers`.
Function `offload may be called directly, or may hide behind the [`@loops`](@ref) macro.

# Single loop

```
    function loop1(range, args...)
        # do some computation shared by all indices i
        for i irange
            # do some work at index i
        end
    end

    offload(loop1, mgr::LoopManager, range, args...)
```

# Two nested loops
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

`ManagedLoops` also defines [`parallel`], [`barrier`], [`master`], [`share`] to support
OpenMP-like execution with long-lived threads. This is currently experimental and not more performant
than short-lived threads launched at each outer loop.

"""
module ManagedLoops

export @unroll, @__HERE__, offload, no_simd
export LoopManager, HostManager, DeviceManager

"""
    offload(fun1, mgr::LoopManager, range, args...)
    offload(fun2, mgr::LoopManager, (irange, jrange), args...)

Given a function performing a loop / loop nest:
```
    function fun1(range, args...)
        # do some computation shared by all indices i
        for i irange
            # do some work at index i
        end
        return Nothing
    end

    function fun2((irange, jrange), args...)
        # do some computation shared by all indices i,j
        for j in jrange
            # do some computation shared by all indices i
            for i irange
                # do some work at index i
            end
        end
        return Nothing
    end
```
Executes the loop nest with the provided manager. Depending on the manager, `fun` may be called just once on the full range,
several times on sub-ranges, or many times on 'ranges' consisting of a single index.

!!! warning
    Each call to fun() must be independent, and several calls may occur concurrently.
    The only guarantee is that the whole iteration space is covered without overlap.

!!! note
    `offload` *may* amortize the cost of a pre-computation
    whose results are reused across iterations, as in the above example.
    This depends on how `offload` is implemented by the manager.

"""
function offload end

# default manager
"""
    mgr = default_manager()
    mgr = default_manager(ManagerType) :: ManagerType
    # examples
    host = default_manager(HostManager)
    device = default_manager(DeviceManager)

Returns a manager of the desired type, if provided. ManagedLoops implements only :

    default_manager() = default_manager(HostManager)

`default_manager(::Type{HostManager}) is defined if `LoopManagers` is loaded.
`default_manager` is also meant to be specialized by the user, for instance :
    ManagedLoops.default_manager(::Type{HostManager}) = LoopManagers.Vectorized_CPU()
"""
default_manager() = default_manager(HostManager)

# abstract managers
"""
    abstract type LoopManager end

Ancestor of types describing a loop manager.
"""
abstract type LoopManager end

"""
    abstract type DeviceManager <: LoopManager end

Ancestor of types describing a loop manager running on a device (GPU).
"""
abstract type DeviceManager <: LoopManager end

"""
    abstract type HostManager <: LoopManager end

Ancestor of types describing a loop manager running on the host.
"""
abstract type HostManager <: LoopManager end


# Sometimes we need to deactivate SIMD on loops that would not work with it
"""
    mgr_nosimd = no_simd(mgr::LoopManager)
Returns a manager similar to `mgr` but with SIMD disabled.

!!! tip
    Due to implementation details, not all loops support SIMD.
    If errors are thrown when offloading a loop
    on an SIMD-enabled manager, use this function.
"""
no_simd(mgr::LoopManager) = mgr

# parallel, barrier, master, share
include("julia/parallel.jl")

# API for wrapped managers and arrays
include("julia/wrapped.jl")

# macros

module _internals_

using MacroTools

include("julia/at_unroll.jl")
include("julia/at_loops.jl")
include("julia/at_vec.jl")

end # internals

using ._internals_: @vec, @unroll, @loops, bulk, tail

end # module ManagedLoops
