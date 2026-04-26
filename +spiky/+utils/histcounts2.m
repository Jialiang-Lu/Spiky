function counts = histcounts2(X, Y, Xedges, YEdges, weights, options)
%HISTCOUNTS2 2D histogram counts with weights and individual group ids
%   counts = histcounts2(X, Y, Xedges, YEdges, weights, ids, ...)
%
%   X: (n, 1) double, x coordinates of the data points
%   Y: (n, 1) double, y coordinates of the data points
%   Xedges: (m, 1) double, x bin edges
%   YEdges: (p, 1) double, y bin edges
%   weights: (n, 1) double, weights for each data point
%   Name-value arguments:
    %   Ids: (n, 1) double, group ids for each data point. The histogram will be computed for each group separately.
%       Normalization: string, normalization method for the counts. Options are:
%           "count": raw counts (default)
%           "probability": counts divided by total weight, so that the sum of counts is 1
%           "percentage": counts divided by total weight and multiplied by 100, so that the
%               sum of counts is 100
%           "countdensity": counts divided by the area of each bin, so that the counts represent density
%           "pdf": counts divided by the area of each bin and total weight, so that
%               the counts represent probability density function
%
%   counts: (m-1, p-1, max(ids)) double, histogram counts for each group. 
%       counts(i, j, k) is the count for the bin defined by Xedges(i:i+1) and YEdges(j:j+1) for group k.
arguments
    X (:, 1) double
    Y (:, 1) double
    Xedges (:, 1) double
    YEdges (:, 1) double
    weights (:, 1) double = ones(numel(X), 1)
    options.Ids (:, 1) double {mustBeInteger, mustBePositive} = ones(numel(X), 1)
    options.Normalization string {mustBeMember(options.Normalization, ["count", "probability", ...
        "percentage", "countdensity", "pdf"])} = "count"
end
assert(isequal(height(X), height(Y), height(weights), height(options.Ids)), ...
    "X, Y, weights, and ids must have the same number of rows.");
n = height(X);
ws = sum(weights);
idcX = discretize(X, Xedges);
idcY = discretize(Y, YEdges);
isValid = ~isnan(idcX)&~isnan(idcY);
X = X(isValid);
Y = Y(isValid);
weights = weights(isValid);
ids = options.Ids(isValid);
idcX = idcX(isValid);
idcY = idcY(isValid);
nX = numel(Xedges)-1;
nY = numel(YEdges)-1;
nIds = max(ids);
counts = accumarray([idcX, idcY, ids], weights, [nX, nY, nIds]);
switch options.Normalization
    case "count"
        % do nothing
    case "probability"
        counts = counts/ws;
    case "percentage"
        counts = counts/ws*100;
    case "countdensity"
        counts = counts./(diff(Xedges)*diff(Yedges)');
    case "pdf"
        counts = counts./(diff(Xedges)*diff(Yedges)'*ws);
end
