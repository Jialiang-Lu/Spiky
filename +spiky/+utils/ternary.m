function c = ternary(cond, a, b)
    % TERNARY Ternary operator
    %
    %   c = TERNARY(cond, a, b) returns a if cond is true and b otherwise
    
    if isempty(cond)
        cond = false;
    end
    if isscalar(cond)
        if cond
            c = a;
        else
            c = b;
        end
    elseif islogical(cond)
        c = cond.*a+(1-cond).*b;
    else
        error('Condition has to be logical')
    end
end