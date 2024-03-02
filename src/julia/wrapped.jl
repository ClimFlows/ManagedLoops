"""
    abstract type WrapperManager{B,SuperType<:LoopManager} <: Supertype end

Ancestor for manager types wrapping another loop manager. It is expected that
concrete children types possess a field `wrapped::B` referring to the wrapped manager.
Routines accepting a `mgr::LoopManager` argument may provide a fallback implementation
for `mgr::WrapperManager` by calling themselves with `mgr.wrapped` as argument.
"""
abstract type WrapperManager{B, SuperType<:LoopManager} <: SuperType end

"""
    abstract type WrappedArray{A} end

Ancestor for types wrapping an array. It is expected that
concrete children types possess a field `data::A` referring to the wrapped array.
Routines accepting an array argument may provide a fallback implementation
for `wrapped::WrappedArray` by calling themselves with `wrapped.data` as argument.
If an array `result` is returned, it should be wrapped by calling `wrap_array(wrapped, result)`
"""
abstract type WrappedArray{A} end
"""
    wrapped_result = wrap_array(result::A, wrapper::WrappedArray{A})

Wraps `result` in a WrappedArray of the same concrete type as `wrapper`. This function is not implemented
by `ManagedLoops`, it is meant to be implemented for concrete types `WArray<:WrappedArray`. See also [`WrapperManager`](@ref).
"""
function wrap_array end
