module ManagedLoopsAdaptExt

using ManagedLoops: LoopManager
using Adapt: Adapt, adapt

(mgr::LoopManager)(x) = adapt(mgr, x)

# when adapting a manager to a target manager, the target manager replaces the original manager
# otherwise we put 'missing'
Adapt.adapt_structure(to, mgr::LoopManager) = adapt_structure_mgr(to, mgr)
adapt_structure_mgr(to, mgr) = Adapt.adapt_storage(to, mgr) # not sure this is the right thing to do
adapt_structure_mgr(to::LoopManager, mgr) = to

end
