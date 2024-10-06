function [n, d] = equalDiv(x, maxd)
%EQUALDIV divide x into n euqal chunks with each chunk smaller than maxd
%
%   [n, d] = equalDiv(x, maxd)
%
%   x: total length
%   maxd: maximum length of each chunk
%
%   n: number of chunks
%   d: length of each chunk

n = ceil(x/maxd);
while mod(x, n)~=0
    n = n+1;
end
d = x/n;
