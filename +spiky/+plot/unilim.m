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
if isscalar(targets) || isempty(targets)
    return
end
if ax=="all"
    ax = "xyzc";
end
if contains(ax, "x", IgnoreCase=true)
    updatelim(targets, "XLim");
end
if contains(ax, "y", IgnoreCase=true)
    nYAxes = arrayfun(@(h) length(h.YAxis), targets);
    if all(nYAxes==1)
        updatelim(targets, "YLim", true);
    else % multiple y axes, unify each of them separately
        updatelim(arrayfun(@(h) h.YAxis(1), targets(nYAxes>=1)), "Limits", true);
        updatelim(arrayfun(@(h) h.YAxis(2), targets(nYAxes>=2)), "Limits", true);
    end
end
if contains(ax, "z", IgnoreCase=true)
    updatelim(targets, "ZLim");
end
if contains(ax, "c", IgnoreCase=true)
    updatelim(targets, "CLim");
end
end

function updatelim(ax, targetProp, isY)
    arguments
        ax
        targetProp string
        isY logical = false
    end
    l = get(ax, targetProp);
    l = cell2mat(l);
    lMax = [min(l, [], "all") max(l, [], "all")];
    % hasLine = false;
    % if isY
    %     lInc = lMax(:, 2)-l(:, 2);
    %     for ii = 1:numel(ax)
    %         if isa(ax, "matlab.graphics.axis.Axes")
    %             h = findobj(ax(ii), Tag="sigline");
    %         else
    %             h = findobj(ax(ii).Parent, Tag="sigline");
    %         end
    %         for jj = 1:numel(h)
    %             h(jj).YData = h(jj).YData+lInc(ii);
    %             hasLine = true;
    %         end
    %     end
    % end
    % if hasLine
    %     lMax(:, 2) = lMax(:, 2)+(lMax(:, 2)-lMax(:, 1))*0.05; % add some padding if there are sig lines
    % end
    set(ax, targetProp, lMax);
end
