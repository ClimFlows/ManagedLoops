macro loops(code)
    return esc(loops_macro_new(code))
end

macro with(expr)
    return esc(with_macro(expr))
end
macro with(mgr, expr)
    return esc(with_macro(mgr, expr))
end

function with_macro(mgr, expr)
    if @capture(expr, (let names_ = values_ ; body__ ; end))
        return expand_with(mgr, names, values, body)
    end
    with_error()
end

function with_macro(expr)
    if @capture(expr, (mgr_, let names_ = values_ ; body__ ; end))
        return expand_with(mgr, names, values, body)
    end
    with_error()
end

expand_with(mgr, names, values, body) = :(
    $offload($mgr, $values) do $names
        $(body...)
    end )

with_error() = error("""
Error: @with supports only the following syntaxes:
    
    @with mgr, let lhs = rhs
        [body]
    end

    @with mgr let lhs = rhs
        [body]
    end

where `mgr::LoopManager` may be an expression, `lhs` must be a single name or a tuple of names,
and `rhs` is an expression yielding the range(s) of the loop(s) to be managed.
""")

function loops_macro_new(expr)
    def = MacroTools.splitdef(expr)
    def[:args][1] == :(_) || error("""
    In `@loops function fun(...) ...`, the first argument of `fun` must be the dummy argument `_`
        $(MacroTools.striplines(expr)) """
    )

    body = def[:body].args
    lines = filter(line -> !isa(line, LineNumberNode), body)

    # one kernel for each `let` block
    kernels = [
        let def = deepcopy(def)
            # we start from the user-defined function definition,
            # prepend our arguments and replace the function body
            # with the body of the `let` block
            names, _, body = loops_macro_capture(expr, lines[i])
            args = def[:args]
            popfirst!(args)
            pushfirst!(args, names, :(::Val{$i}))
            def[:body].args = body
            kernel = combinedef(def)
            kernel = :(@inline $kernel)
        end for i in eachindex(lines)
    ]

    # calls `offload` for each kernel
    wrapper = loops_macro_wrapper(expr, def, lines)

    def[:args][1] = :(::Nothing) # must be done after previous line for obscure reason
    return quote
        @inline $(combinedef(def))
        @inline $wrapper
        $(kernels...)
    end
end

# construct the function accepting a `LoopManager` as first argument
# its body is a sequence of calls to `offload`
function loops_macro_wrapper(expr, def, lines)
    def = deepcopy(def)
    args = def[:args]
    args[1] = :(mgr::$LoopManager)

    # array of function calls
    def[:body].args = [
        let call = deepcopy(expr.args[1])
            _, values, _ = loops_macro_capture(expr, lines[i])
            # prepare call expression : pop function name and dummy first argument
            fun = popfirst!(call.args)
            popfirst!(call.args)
            # prepend our arguments
            pushfirst!(call.args, offload, fun, :mgr, values, :(Val($i)))
            :(@inline $call)
        end for i in eachindex(lines)
    ]
    return combinedef(def)
end

function loops_macro_capture(expr, line)
    @capture(line, let names_ = values_ ; body__ ; end) || error("""
    The `@loops` macro has been placed in front of :
        $(MacroTools.striplines(expr))
    but line
        $(MacroTools.striplines(line))
    does not conform to the pattern :
        let ranges = ...
            ...
        end
    """)
    return names, values, body
end
