function [hLine, hError] = plotError(x, y, e, lineSpec, plotOps, options)
%PLOTERROR Plot data with shaded error bars
%
%   h = plotError(x, y, e, options)
%
%   x: x data
%   y: y data
%   e: error data
%   lineSpec: line specification
%   plotOps: additional arguments passed to plot
%   options: options
%       FaceAlpha: face alpha for the error bars
%
%   hLine: handle to the main line
%   hError: handle to the error patch

arguments
    x double
    y double
    e double
    lineSpec string = "k-"
    plotOps.?matlab.graphics.chart.primitive.Line
    options.FaceAlpha double = 0.5
end

if ~isvector(x) && ~isvector(y)
    if ~isequal(size(x), size(y))
        error("x and y must have the same size");
    end
elseif isvector(x)
    if isrow(x)
        x = x.';
        y = y.';
        e = e.';
    end
    x = repmat(x, 1, size(y, 2));
else
    error("Wrong size combination of x and y");
end
nPoints = size(x, 1);
nLines = size(x, 2);
if size(e, 1)==1
    e = repmat(e, nPoints, 1);
end
if size(e, 2)==1
    e = repmat(e, 1, nLines);
end
plotArgsCell = namedargs2cell(plotOps);
hLine1 = plot(x, y, lineSpec, plotArgsCell{:});
if nLines>1
    cs = spiky.plot.colormap("tab10", nLines, true);
end
for ii = nLines:-1:1
    xData = [x(:, ii); flipud(x(:, ii))];
    yData = [y(:, ii)+e(:, ii); flipud(y(:, ii)-e(:, ii))];
    if nLines>1
        c = cs(ii, :);
        hLine1(ii).Color = c;
    else
        c = hLine1(ii).Color;
    end
    hError1(ii) = patch(xData, yData, c, FaceAlpha=options.FaceAlpha, EdgeColor="none");
end
box off

if nargout>0
    hLine = hLine1;
    hError = hError1;
end

end

