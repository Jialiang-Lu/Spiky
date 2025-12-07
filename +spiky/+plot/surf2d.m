function h = surf2d(x, y, C)
arguments
    x double {mustBeVector}
    y double {mustBeVector}
    C double {mustBeNumeric, mustBeNonempty}
end
[XX, YY] = meshgrid(x, y);
h1 = surface(XX, YY, zeros(size(C)), C, ...
    EdgeColor="none", FaceColor="texturemap");
view(2);
set(gca, "YDir", "normal");
axis tight
axis manual
if nargout>0
    h = h1;
end
end

