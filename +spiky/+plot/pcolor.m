function h = pcolor(x, y, C)
arguments
    x double {mustBeVector}
    y double {mustBeVector}
    C double {mustBeNumeric, mustBeNonempty}
end

ax = gca;
% pcolor historically drops last row/col; pad to preserve full image
Cpad = padarray(C, [1 1], "replicate", "post");

% create edges from centers (assumes uniform spacing)
if numel(x) > 1
    dx = diff(x(1:2));
else
    dx = 1;
end
if numel(y) > 1
    dy = diff(y(1:2));
else
    dy = 1;
end
xEdges = [x - dx/2, x(end) + dx/2];
yEdges = [y - dy/2, y(end) + dy/2];

[XE, YE] = meshgrid(xEdges, yEdges);

% render with flat shading to mimic pixel blocks
h1 = pcolor(ax, XE, YE, Cpad);
shading(ax, "flat");
set(h1, "EdgeColor", "none");
set(ax, "YDir", "normal");
axis(ax, "tight"); axis(ax, "manual");
if nargout>0
    h = h1;
end
end