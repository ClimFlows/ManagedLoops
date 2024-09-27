module ManagedLoopsAdaptExt

using ManagedLoops: LoopManager, HostManager
using Adapt: Adapt, adapt

(mgr::LoopManager)(x) = adapt(mgr, x)

# when adapting a manager to a target manager, the target manager replaces the original manager
# otherwise we put 'missing'
Adapt.adapt_structure(to, mgr::LoopManager) = adapt_structure_mgr(to, mgr)
# Fallback implementation of `Adapt.adapt_storage(to, x)` is `Adapt.adapt_structure(to, x)`
adapt_structure_mgr(to, mgr) = Adapt.adapt_storage(to, mgr)
adapt_structure_mgr(to::LoopManager, mgr) = to

# adapting an AbstractArray to the CPU returns an array
Adapt.adapt_storage(::HostManager, x) = adapt_to_host(x)
adapt_to_host(x) = x
adapt_to_host(x::Array) = x
adapt_to_host(x::AbstractArray) = Array(x)

end
