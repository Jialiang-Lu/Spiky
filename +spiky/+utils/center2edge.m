function edge = center2edge(center)
% Convert center coordinates to edge coordinates.
%   edge = center2edge(center)
arguments
    center {mustBeNumeric, mustBeVector}
end
if isrow(center)
    center = center';
    isRow = true;
else
    isRow = false;
end
d = diff(center);
d = [-d(1); d; d(end)]/2;
edge = center([1 1:end])+d;
if isRow
    edge = edge';
end
