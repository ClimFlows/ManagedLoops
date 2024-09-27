module ManagedLoopsAdaptExt

using ManagedLoops: LoopManager
using Adapt: Adapt, adapt

(mgr::LoopManager)(x) = adapt(mgr, x)

# when adapting a manager to a target manager, the target manager replaces the original manager
# otherwise we put 'missing'
Adapt.adapt_structure(to, mgr::LoopManager) = adapt_structure_mgr(to)
adapt_structure_mgr(_) = missing
adapt_structure_mgr(to::LoopManager) = to

end
