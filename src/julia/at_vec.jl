#================ @vec macro ===============#

# @vec for i in range
#    ...
# end
#
# =>
#
# for i in bulk(range)
#    ...
# end
# @simd for i in tail(range)
#    ...
# end

@inline bulk(_)=()
@inline tail(range)=range

macro vec(expr)
    return esc(vec_macro(expr))
end

function vec_macro(expr)
    if @capture(expr,  if a_ ; b_ ; else ; c_ ; end )
        return :($choose($a, ()->$b, ()->$c))
    elseif @capture(expr,  for a_ in b_ ; body__ ; end )
        return quote
            for $a in $bulk($b)
                $(body...)
            end
            @simd for $a in $tail($b)
                $(body...)
            end
        end
    elseif @capture(expr,  for i_ in irange_, j_ in jrange_ ; body__ ; end )
        return quote
            for $j in $jrange
                for $i in $bulk($irange)
                    $(body...)
                end
                @simd for $i in $tail($irange)
                    $(body...)
                end
            end
        end
    else
        error("Malformed @vec statement : $expr")
    end
end

