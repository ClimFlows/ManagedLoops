struct ManagedArray{A,M,T,N} <: AbstractArray{T,N}
    mgr::M
    a::A
    ManagedArray(mgr::M, a::A) where {M,A}= new{A, M, eltype(a), ndims(a)}(mgr, a)
end

Base.ndims(::Type{ManagedArray{A}}) where A = ndims(A)
Base.size(ma::ManagedArray) = size(ma.a)

function Base.copyto!(ma::ManagedArray, bc::Broadcast.Broadcasted)
    managed_copyto!(ma.mgr, ma.a, bc)
    return ma.a
end

@loops function managed_copyto!(_, a, bc)
    let irange = eachindex(a)
        @vec for i in irange
            @inbounds a[i] = bc[i]
        end
    end
end

# support for syntax : @. mgr[a] = b + c
Base.getindex(mgr::LoopManager, a::AbstractArray) = ManagedArray(mgr, a)
