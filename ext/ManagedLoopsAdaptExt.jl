module ManagedLoopsAdaptExt

using ManagedLoops: LoopManager
using Adapt: adapt

(mgr::LoopManager)(x) = adapt(mgr, x)

end
