function [hLine, hText] = sigstar(groups, p, options)
%SIGSTAR Add significance stars to a plot based on p-values for specified groups.
%   [hLine, hText] = SIGSTAR(groups, p, options)
%
%   groups: cell array of groups, where each group is a vector of x-coordinates (1 or 2 elements)
%   p: vector of p-values corresponding to each group
%   Name-value arguments:
%       OffsetPercent: vertical offset from the top of the plot (default: 5%)
%       HeightPercent: height of the significance lines (default: 1%)
%       LineWidth: width of the significance lines (default: 2)
%       LineColor: color of the significance lines (default: "k")
%       TextColor: color of the significance stars (default: "k")
%       FontSize: font size of the significance stars (default: 8)
%       Parent: axes to plot on (default: gca)

arguments
    groups (:, 1) % cell (or numeric/categorical array of groups if each group has only one element)
    p (:, 1) double
    options.SigOnly logical = false
    options.OffsetPercent double = 5
    options.HeightPercent double = 1
    options.LineWidth double = 2
    options.LineColor char = "k"
    options.TextColor char = "k"
    options.FontSize double = 8
    options.Parent matlab.graphics.axis.Axes = gca
end
%% Prepare data
if isnumeric(groups) || iscategorical(groups)
    groups = num2cell(groups);
end
if options.SigOnly
    groups = groups(p<0.05);
    p = p(p<0.05);
end
nGroups = numel(groups);
nPerGroup = cellfun(@numel, groups);
assert(all(nPerGroup>0 & nPerGroup<=2), "Each group must contain 1 or 2 elements.");
isGroup1 = nPerGroup==1;
isGroup2 = nPerGroup==2;
nGroups1 = sum(isGroup1);
nGroups2 = sum(isGroup2);
yl = options.Parent.YLim;
hText0 = gobjects(nGroups, 1);
hLine0 = gobjects(nGroups2, 1);
yInc = diff(yl)*options.OffsetPercent/100;
yNow = yl(2)+yInc;
yH = diff(yl)*options.HeightPercent/100;
labels = strings(size(p));
labels(p>=0.05) = "n.s.";
labels(p<0.05) = sprintf("\x2731");
labels(p<0.01) = sprintf("\x2731\x2731");
labels(p<0.001) = sprintf("\x2731\x2731\x2731");
s = struct;
s.Idx = 1;
s.Offset = options.OffsetPercent;
s.Spacing = options.HeightPercent;
%% Single groups
if nGroups1>0
    groups1 = cell2mat(groups(isGroup1));
    hText1 = gobjects(nGroups1, 1);
    labels1 = labels(isGroup1);
    for ii = 1:nGroups1
        x = groups1(ii);
        hText1(ii) = text(options.Parent, x, yNow, labels1(ii), HorizontalAlignment="center", ...
            VerticalAlignment="bottom", FontSize=options.FontSize, Color=options.TextColor, ...
            BackgroundColor="none", Tag="sigstar", UserData=s);
    end
    yNow = yNow+yInc;
    s.Idx = 2;
    hText0(isGroup1) = hText1;
end
%% Group pairs
if nGroups2>0
    groups2 = spiky.utils.cellfun(@(g) g(:)', groups(isGroup2));
    if iscategorical(groups2(1))
        xtks = options.Parent.XAxis.TickValues;
        groups2 = double(categorical(groups2, xtks));
    end
    labels2 = labels(isGroup2);
    hText2 = gobjects(nGroups2, 1);
    [~, idcSort] = sort(diff(groups2, 1, 2));
    groups2 = groups2(idcSort, :);
    labels2 = labels2(idcSort);
    for ii = 1:nGroups2
        x = repmat(groups2(ii, :), 2, 1);
        y = [yNow, yNow+yH, yNow+yH, yNow];
        hLine0(ii) = plot(options.Parent, x(:), y(:), Color=options.LineColor, ...
            LineWidth=options.LineWidth, Tag="sigstar", UserData=s);
        xc = mean(groups2(ii, :));
        hText2(ii) = text(options.Parent, xc, yNow+yH, labels2(ii), HorizontalAlignment="center", ...
            VerticalAlignment="bottom", FontSize=options.FontSize, Color=options.TextColor, ...
            BackgroundColor="none", Tag="sigstar", UserData=s);
    end
    hText0(isGroup2) = hText2;
    yNow = yNow+yInc;
end
%% Output
options.Parent.YLim = [yl(1) yNow];
options.Parent.YAxis.LimitsChangedFcn = {@onLimitsChanged, hText0, hLine0};
if nargout>0
    hLine = hLine0;
end
if nargout>1
    hText = hText0;
end
end

function onLimitsChanged(src, evt, hText, hLine)
    ylNew = evt.NewLimits;
    if isempty(hText)
        return
    end
    s = hText(end).UserData;
    n = s.Idx;
    yd = diff(ylNew)/(100+(n+1)*s.Offset)*100;
    yl = [0 yd]+ylNew(1);
    yInc = diff(yl)*s.Offset/100;
    yH = diff(yl)*s.Spacing/100;
    idcText = arrayfun(@(h) h.UserData.Idx, hText);
    yText = yl(2)+yInc*idcText;
    for ii = 1:numel(hText)
        pos = hText(ii).Position;
        pos(2) = yText(ii);
        hText(ii).Position = pos;
    end
    if ~isempty(hLine)
        idxLine = hLine(1).UserData.Idx;
        yLine = yl(2)+yInc*idxLine;
        set(hLine, "YData", [yLine, yLine+yH, yLine+yH, yLine]);
    end
end


