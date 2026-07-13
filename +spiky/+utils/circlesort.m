function idc = circlesort(varargin)
%CIRCLESORT Sort points in a circular order based on their angles from the centroid.
%   idc = circlesort(pos)
%   idc = circlesort(x, y)

arguments (Repeating)
    varargin {mustBeNumeric}
end

if nargin==1
    pos = varargin{1};
    assert(width(pos)==2, "Input position must have 2 columns for x and y.");
    x = pos(:, 1);
    y = pos(:, 2);
elseif nargin==2
    x = varargin{1};
    y = varargin{2};
    assert(isvector(x) && isvector(y) && length(x)==length(y), ...
        "Input x and y must be vectors of the same length.");
    x = x(:);
    y = y(:);
else
    error("Invalid number of input arguments. Provide either a single Nx2 matrix or two Nx1 vectors for x and y.");
end
x = x-mean(x);
y = y-mean(y);
ang = atan2(y, x);
[~, idc] = sort(ang);

end