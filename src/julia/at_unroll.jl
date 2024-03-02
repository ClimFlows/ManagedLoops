#======== unroll loops, tuples and (weighted) sums  ========#

"""
## One-argument form

    @unroll expr

Unrolls the following constructs in expr :

    for i in start:stop ... end
    (expr for i in start:stop)
    sum(expr for i=start:stop ... end)

provided integers `start` and `stop` are known at *parse* time.
Unrolling applies recursively to sub-expressions contained in `expr`.

!!! example
    ```
    @unroll for i=4:6 ; foo(i); end
    @unroll (i*i for i=4:6)
    @unroll sum(i * i for i=4:6)
    ```
    expands to
    ```
    begin; foo(4); foo(5); foo(6) ; end
    (4*4, 5*5, 6*6)
    4*4 + 5*5 + 6*6
    ```

## Two-argument form

    @unroll n in start:stop expr(n)

Expands to

    if n==start ; @unroll expr(start) ; end
    if n==start+1 ; @unroll expr(start+1) ; end
    ...
    if n==stop ; @unroll expr(stop) ; end

provided integers `start` and `stop` are known at parse time.
Unrolling applies recursively `expr` and its sub-expressions.

!!! warning
    Nested use of @unroll should never be necessary and may not work as expected.
"""
macro unroll(expr)
    return esc(MacroTools.prewalk(unroll_all_, expr))
end

macro unroll(range, expr)
    assume_(range, :(@unroll $expr))
end

hardcode(expr, sym, val) =
    MacroTools.postwalk(expr) do e
        (e == sym) ? val : e
    end

unroll_sum(expr) = expr

function unroll_sum(expr::Expr)
    if @capture(expr, sum(a_ * b_ for var_ = start_Int:stop_Int))
        for i = start:stop
            aa = hardcode(a, var, i)
            bb = hardcode(b, var, i)
            if i == start
                expr = :($aa * $bb)
            else
                expr = :(muladd($aa, $bb, $expr))
            end
        end
    elseif @capture(expr, sum(a_ for var_ = start_Int:stop_Int))
        for i = start:stop
            aa = hardcode(a, var, i)
            if i == start
                expr = aa
            else
                expr = :($expr + $aa)
            end
        end
    end
    return expr
end

function unroll_(expr)
    if @capture(expr, for var_ = start_Int:stop_Int
        body__
    end)
        expr = quote
            $([hardcode(el, var, i) for el in body, i = start:stop]...)
        end
    elseif @capture(expr, (el_ for var_ = start_Int:stop_Int))
        expr = Expr(:tuple, [hardcode(el, var, i) for i = start:stop]...)
    end
    return expr
end

unroll_all_(expr) = unroll_(unroll_sum(expr))

function at_tuple(expr)
    if @capture(expr, val_ for var_ = start_:stop_)
        expr = quote
            NTuple{$stop - $start + 1,typeof(let $var = 1
                $val
            end)}($expr)
        end
    end
    expr
end

macro tuple(expr)
    if @capture(expr, val_ for var_ = start_:stop_)
        expr = quote
            NTuple{$stop - $start + 1,typeof(let $var = $start
                $val
            end)}($expr)
        end
    end
    return esc(expr)
end

function assume_(range, expr)
    if @capture(range, var_Symbol in start_Int:stop_Int)
        lines = (:(
            if $var == $i
                $(hardcode(expr, var, i))
            end
        ) for i = start:stop)
        return esc(Expr(:block, lines...))
    else
        error(
            "Malformed expression 'range' in macro '@assume range expr' : '$range' provided while 'range' should be of the form 'var in start:stop' with start and stop integers known at parse time",
        )
    end
end
