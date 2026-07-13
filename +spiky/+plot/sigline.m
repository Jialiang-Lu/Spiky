function hs = sigline(targets, p, plotOps, options)
%SIGLINE plot horizontal lines indicating significance levels
%   hs = sigline(targets, p, ...)
%
%   targets: line objects of the plotted data
%   p: a matrix of p values with the same number of columns as number of targets
%   Name-value arguments:
%       ...: properties of matlab.graphics.primitive.Rectangle for the significance lines
%       Threshold: plot lines for p values smaller than the threshold. If multiple values are given,
%           multiple lines will be plotted with different thickness (default: 0.01)
%       OffsetPercent: the vertical offset of the significance lines relative to the y limits of the
%           axes, in percentage (default: 2)
%       HeightPercent: the vertical spacing between significance lines for different targets, 
%           in percentage of the y limits of the axes (default: 1)
%       Parent: the axes to plot on (default: gca)
%
%   hs: nTargets x nLevels cell array of line handles for the significance lines

arguments
    targets (:, 1) matlab.graphics.chart.primitive.Line
    p (:, :) double
    plotOps.?matlab.graphics.primitive.Rectangle
    options.Threshold (1, 3) double = 0.01
    options.OffsetPercent double = 2
    options.HeightPercent double = 1
    options.Parent matlab.graphics.axis.Axes = gca
end

n = numel(targets);
assert(n==width(p), "The number of targets must match the number of columns in p.");
nLevels = numel(options.Threshold);
hs1 = cell(n, nLevels);
xl = options.Parent.XLim;
yl = options.Parent.YLim;
yInc = diff(yl)*options.OffsetPercent/100;
yStart = yl(2)+yInc;
yNow = yStart;
yH = diff(yl)*options.HeightPercent/100;
levelRatios = (options.Threshold/min(options.Threshold)).^0.3; % 1 x nLevels, 1 for most significant, >1 for less significant
yHLevels = yH./levelRatios; % 1 x nLevels, most significant has the largest thickness
holdState = options.Parent.NextPlot;
options.Parent.NextPlot = "add";
plotOps.EdgeColor = "none";
s = struct;
s.Idx = 1;
s.Offset = options.OffsetPercent;
s.Spacing = options.HeightPercent;
s.Ratio = 1;
for ii = 1:n
    x = targets(ii).XData;
    resX = x(2)-x(1);
    plotOps.FaceColor = targets(ii).Color;
    plotArgs = namedargs2cell(plotOps);
    s.Idx = ii;
    for jj = 1:nLevels
        idcSig = find(p(:, ii)<options.Threshold(jj));
        if isempty(idcSig)
            continue
        end
        itvSig = spiky.core.Events(idcSig).findContinuous(1.5).Time; % nChunks x 2 indices
        x1 = x(itvSig)+[-0.25 0.25]*resX; % nChunks x 2 left and right edges
        nChunks = height(x1);
        s.Ratio = levelRatios(jj);
        h = gobjects(nChunks, 1);
        for kk = 1:nChunks
            h(kk) = rectangle(options.Parent, "UserData", s, "Tag", "sigline", "Position", ...
                [x1(kk, 1) yNow-yHLevels(jj)/2 x1(kk, 2)-x1(kk, 1) yHLevels(jj)], plotArgs{:});
        end
        % an = [h.Annotation];
        % li = [an.LegendInformation];
        % set(li, IconDisplayStyle="off");
        hs1{ii, jj} = h;
    end
    yNow = yNow+yH;
end
ylim(options.Parent, [yl(1) yNow+yH/2]);
options.Parent.NextPlot = holdState;
% options.Parent.YAxis.LimitsChangedFcn = @(src, evt) onLimitsChanged(src, evt, hs1);
options.Parent.YAxis.LimitsChangedFcn = {@onLimitsChanged, hs1};
if nargout>0
    hs = hs1;
end
end

function onLimitsChanged(src, evt, hs)
    ylNew = evt.NewLimits;
    if isempty(hs) || isempty(hs{1})
        return
    end
    s = hs{1, 1}(1).UserData;
    n = height(hs);
    yd = diff(ylNew)/(100+s.Offset+(n-0.5)*s.Spacing)*100;
    yl = [0 yd]+ylNew(1);
    yInc = diff(yl)*s.Spacing/100;
    yStart = yl(2)+diff(yl)*s.Offset/100;
    for ii = 1:numel(hs)
        hLevel = hs{ii};
        if isempty(hLevel) || ~isvalid(hLevel(1))
            continue
        end
        s = hLevel(1).UserData;
        yNow = yStart+(s.Idx-1)*yInc;
        yHLevel = diff(yl)*s.Spacing/100/s.Ratio;
        for jj = 1:numel(hLevel)
            if ~isvalid(hLevel(jj))
                continue
            end
            pos = hLevel(jj).Position;
            pos(2) = yNow-yHLevel/2;
            pos(4) = yHLevel;
            hLevel(jj).Position = pos;
        end
    end
end
