struct ManagedArray{A,M,T,N} <: AbstractArray{T,N}
    mgr::M
    a::A
    ManagedArray(mgr::M, a::A) where {M,A}= new{A, M, eltype(a), ndims(a)}(mgr, a)
end

Base.ndims(::Type{ManagedArray{A}}) where A = ndims(A)
Base.size(ma::ManagedArray) = size(ma.a)

function Base.copyto!(ma::ManagedArray, bc::Broadcast.Broadcasted)
    managed_copyto!(ma.mgr, ma.a, bc, axes(bc)...)
    return ma.a
end

@loops function managed_copyto!(_, a, bc, ax1)
    let irange = ax1
        @vec for i in irange
            @inbounds a[i] = bc[i]
        end
    end
end

@loops function managed_copyto!(_, a, bc, ax1, ax2)
    let (irange, jrange) = (ax1, ax2)
        for j in jrange
            @vec for i in irange
                @inbounds a[i,j] = bc[i,j]
            end
        end
    end
end

@loops function managed_copyto!(_, a, bc, ax1, ax2, ax3)
    let (irange, jrange) = (ax1, ax2)
        for j in jrange, k in ax3
            @vec for i in irange
                @inbounds a[i,j,k] = bc[i,j,k]
            end
        end
    end
end

@loops function managed_copyto!(_, a, bc, ax1, ax2, ax3, ax4)
    let (irange, jrange) = (ax1, ax2)
        for j in jrange, k in ax3, l in ax4
            @vec for i in irange
                @inbounds a[i,j,k,l] = bc[i,j,k,l]
            end
        end
    end
end

# support for syntax : @. mgr[a] = b + c
Base.getindex(mgr::LoopManager, a::AbstractArray) = ManagedArray(mgr, a)
