function centers = edge2center(edges)
%EDGE2CENTER Convert bin edges to bin centers
%   centers = edge2center(edges)
arguments
    edges {mustBeNumeric, mustBeVector}
end
centers = (edges(1:end-1)+edges(2:end))/2;
end