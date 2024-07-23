function [n, d] = equalDiv(x, maxd)
    %EQUALDIV divide x into n euqal chunks with each chunk smaller than maxd
    
    n = ceil(x/maxd);
    while mod(x, n)~=0
        n = n+1;
    end
    d = x/n;
    