function hs = sigline(targets, p, plotOps, options)
%SIGLINE plot horizontal lines indicating significance levels

arguments
    targets (:, 1) matlab.graphics.chart.primitive.Line
    p (:, :) double
    plotOps.?matlab.graphics.chart.primitive.Line
    options.Threshold = 0.01
    options.OffsetPercent double = 2
    options.HeightPercent double = 1
    options.Parent matlab.graphics.axis.Axes = gca
end

n = numel(targets);
assert(n==width(p), "The number of targets must match the number of columns in p.");
hs1 = cell(n, 1);
yl = options.Parent.YLim;
yInc = diff(yl)*options.OffsetPercent/100;
yNow = yl(2)+yInc;
yH = diff(yl)*options.HeightPercent/100;
holdState = options.Parent.NextPlot;
options.Parent.NextPlot = "add";
for ii = 1:n
    x = targets(ii).XData;
    plotOps.Color = targets(ii).Color;
    plotArgs = namedargs2cell(plotOps);
    idcSig = find(p(:, ii)<options.Threshold);
    if ~isempty(idcSig)
        itvSig = spiky.core.Events(idcSig).findContinuous(1.5).Time;
        h = plot(options.Parent, x(itvSig), [yNow yNow], plotArgs{:}, Tag="sigline", ...
            SeriesIndex=ii);
        an = [h.Annotation];
        li = [an.LegendInformation];
        set(li, IconDisplayStyle="off");
        hs1{ii} = h;
    end
    yNow = yNow+yH;
end
ylim(options.Parent, [yl(1) yNow]);
options.Parent.NextPlot = holdState;
if nargout>0
    hs = hs1;
end
