function ndx = trisub2ind(sz, v1, v2, k, options)
%TRISUB2IND Convert subscripts of a triangular matrix to linear indices
%
%   ndx = TRISUB2IND(sz, v1, v2)
%
%   sz: size of the square matrix
%   v1, v2: row and column subscripts
%   k: diagonal offset, 0 is the main diagonal, positive for above, negative for below
%   Name-value arguments:
%       Lower: if true, the matrix is lower triangular
arguments
    sz (1, 1) double {mustBePositive, mustBeInteger}
    v1 (:, 1) double {mustBePositive, mustBeInteger}
    v2 (:, 1) double {mustBePositive, mustBeInteger}
    k (1, 1) double {mustBeInteger} = 0
    options.Lower (1, 1) logical = true
end

%% Setup and validation
n = sz;
if numel(v1) ~= numel(v2)
    error("trisub2ind:SizeMismatch", "v1 and v2 must have the same number of elements.");
end
if any(v1<1 | v1>n | v2<1 | v2>n)
    error("trisub2ind:OutOfRange", "Subscripts must satisfy 1 <= v1,v2 <= sz.");
end

%% Column counts and start indices in the compressed vector
jAll = (1:n).';
if options.Lower
    startRowAll = max(jAll-k+1, 1);
    countAll = max(n-startRowAll+1, 0);
else
    endRowAll = min(jAll+k-1, n);
    countAll = max(endRowAll, 0);
end
totalCount = sum(countAll);
if totalCount==0 && ~isempty(v1)
    error("trisub2ind:EmptyTriangle", ...
        "No elements in the selected triangular region for the given k and Lower.");
end
startIdxAll = cumsum([1; countAll(1:end-1)]); % 1-based start index per column

%% Per-input validation against triangular region
if options.Lower
    startRow = max(v2-k+1, 1);
    valid = (countAll(v2)>0) & (v1>=startRow) & (v1<=n);
    localIdx = v1-startRow+1;
else
    endRow = min(v2+k-1, n);
    valid = (countAll(v2)>0) & (v1>=1) & (v1<=endRow);
    localIdx = v1; % rows start at 1 for upper-triangular compression
end

if ~all(valid)
    error("trisub2ind:InvalidIndex", ...
        "Some (v1,v2) pairs are outside the selected triangular region.");
end

%% Map subscripts to compressed linear indices (column-major)
ndx = startIdxAll(v2)+localIdx-1;
ndx = ndx(:);
end