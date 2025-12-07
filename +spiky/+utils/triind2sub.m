function [v1, v2] = triind2sub(sz, ndx, k, options)
%TRIIND2SUB Convert linear indices of a triangular matrix to subscripts
%
%   [v1, v2] = TRIIND2SUB(sz, ndx)
%
%   sz: size of the square matrix
%   ndx: linear indices
%   k: diagonal offset, 0 is the main diagonal, positive for above, negative for below
%   Name-value arguments:
%       Lower: if true, the matrix is lower triangular
arguments
    sz (1, 1) double {mustBePositive, mustBeInteger}
    ndx (:, 1) double {mustBePositive, mustBeInteger}
    k (1, 1) double {mustBeInteger} = 0
    options.Lower (1, 1) logical = true
end

%% Early exit on empty
if isempty(ndx)
    v1 = zeros(0, 1);
    v2 = zeros(0, 1);
    return
end

%% Column counts and cumulative edges
n = sz;
jAll = (1:n).';
if options.Lower
    startRowAll = max(jAll-k+1, 1);
    countAll = max(n-startRowAll+1, 0);
else
    endRowAll = min(jAll+k-1, n);
    countAll = max(endRowAll, 0);
end
totalCount = sum(countAll);
if totalCount == 0
    error("triind2sub:EmptyTriangle", ...
        "No elements in the selected triangular region for the given k and Lower.");
end
if any(ndx<1 | ndx>totalCount)
    error("triind2sub:OutOfRange", ...
        "ndx must be within 1..N where N is the number of kept elements (%d).", totalCount);
end
edges = [0; cumsum(countAll)];  % cumulative counts; length n+1

%% Locate column per ndx, then compute row
% Use discretize on ndx-1 so edges(k) <= x < edges(k+1)
v2 = discretize(ndx-1, edges);
if any(isnan(v2))
    error("triind2sub:BinMapFailure", "Failed to map some indices to columns.");
end

offsetPrev = edges(v2); % number of elements before column v2
localIdx = ndx-offsetPrev; % 1-based position within the column

if options.Lower
    startRowPerCol = max(v2-k+1, 1);
    v1 = startRowPerCol+localIdx-1; % rows start at startRowPerCol
else
    v1 = localIdx; % rows start at 1 for upper-triangular compression
end

v1 = v1(:);
v2 = v2(:);
end