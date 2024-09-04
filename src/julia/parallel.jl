"""
    parallel(fun, mgr, args...) # or
    parallel(mgr, args...) do thread_mgr, args...
        ...
    end

If `mgr` is a multithread manager, executes `fun(thread_mgr, args...)` over multiple threads.
Each thread receives the per-thread manager `thread_mgr` which is derived from `mgr`
and can be used by `fun` with `offload` and `barrier`.
If `mgr` is not a multithread manager, defaults to `fun(mgr, args...)`.
"""
@inline parallel(fun::Fun, mgr::Union{Nothing, LoopManager}, args::Vararg{Any,NA}) where {Fun, NA} = fun(mgr, args...)

"""
    barrier(mgr::LoopManager)
    @barrier mgr

Synchronization barrier. If the code invoking `barrier` has been launched by [`parallel`](@ref)
and `mgr` is a per-thread manager, synchronizes threads. Otherwise does nothing.
"""
@inline barrier(::Union{Nothing, LoopManager}, ::Symbol=:unknown) = nothing

macro barrier(expr)
    here = QuoteNode(Symbol(__source__.file, ':', __source__.line))
    return esc(:(barrier($expr, $here)))
end

"""
    master(fun, mgr, args...) # or
    master(mgr, args...) do master_mgr, args...
        ...
    end

If `mgr` is a multithread manager, executes `fun(master_mgr, args...)` on the master thread only.
Other threads wait until completion of `fun(...)`.
The master manager `master_mgr` is derived from `mgr` and can be used by `fun` with `offload`.
If `mgr` is not a multithread manager, defaults to `fun(mgr, args...)`.
"""
master(fun::Fun, mgr, args::Vararg{Any,NA}) where {Fun, NA} = fun(mgr, args...) # fallback implementation

"""
    result = share(fun, mgr, args...)
    result = share(mgr, args...) do master_mgr, args...
        ...
    end
If `mgr` is a per-thread manager, evaluates `fun(master_mgr, args...)` on a single thread and returns the result
to all threads. This is especially useful to allocate a shared array in a multithreaded region.
Note that Julia will probably not be able to infer the type of the result.
To avoid type instability, it may be useful/necessary to explicitly type the result or use a function barrier.

If `mgr` is not a per-thread manager, defaults to `fun(mgr, args...)`.
"""
share(fun::Fun, ::LoopManager, args::Vararg{Any,NA}) where {Fun, NA} = fun(mgr, args...)
