function unilim(ax, targets)
%UNILIM unify the limits of the axes
%
%   unilim(ax, targets) sets the limits of the axes to be the same for one or more axes.
%
%   ax: axes to set the limits for. Can be "all", "x", "y", or "z", or a combination of them.
%       If empty, all axes are used.
%   [targets]: axes to set the limits for. If empty, all axes of the current figure are used.

arguments
    ax string {mustBeTextScalar} = "all"
    targets matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
end
if isempty(targets)
    targets = findall(gcf, "Type", "Axes");
end
if ax=="all"
    ax = "xyz";
end
if contains(ax, "x", IgnoreCase=true)
    updatelim(targets, "XLim");
end
if contains(ax, "y", IgnoreCase=true)
    updatelim(targets, "YLim");
end
if contains(ax, "z", IgnoreCase=true)
    updatelim(targets, "ZLim");
end
end

function updatelim(ax, targetProp)
    l = get(ax, targetProp);
    l = cell2mat(l);
    l = [min(l, [], "all") max(l, [], "all")];
    set(ax, targetProp, l);
end
