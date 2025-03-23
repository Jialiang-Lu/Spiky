function fixfig(h, options)
% FIXFIG fix figure appearance
%
%   h: figure handle
arguments
    h = []
    options.Theme = []
    options.Save string = string.empty
    options.ContentType string = "image"
    options.Resolution double = 200
    options.Append logical = false
    options.BackgroudColor = "current"
end

if isempty(h)
    h = gcf;
end
if ~isa(h, "matlab.ui.Figure")
    error("The input must be a figure handle")
end
%%
c = get(groot, "DefaultAxesColor");
c1 = get(groot, "DefaultAxesXColor");
c2 = get(groot, "DefaultAxesYColor");
c3 = get(groot, "DefaultAxesZColor");
ct = get(groot, "DefaultTextColor");
st = get(groot, "DefaultTextFontSize");
ax = findall(h, "Type", "Axes");
for k = 1:length(ax)
    ax(k).Color = c;
    ax(k).XColor = c1;
    ax(k).YColor = c2;
    ax(k).ZColor = c3;
    ax(k).Box = "off";
end
ax = findall(h, "Type", "PolarAxes");
for k = 1:length(ax)
    ax(k).Color = c;
    ax(k).ThetaColor = c1;
    ax(k).RColor = c2;
end
t = findall(h, "Type", "Text");
for k = 1:length(t)
    if t(k).HandleVisibility
        continue
    end
    if t(k).Color(1)==t(k).Color(2)&&t(k).Color(1)==t(k).Color(3)
        t(k).Color = ct;
    end
    t(k).FontSize = st;
end
t = findall(h, "Type", "SubplotText");
for k = 1:length(t)
    t(k).Color = ct;
    t(k).FontSize = ceil(get(groot, "DefaultAxesFontSize")*...
        get(groot, "FactoryAxesTitleFontSizeMultiplier"));
end
t = findall(h, "Type", "Colorbar");
for k = 1:length(t)
    t(k).Color = get(groot, "DefaultColorbarColor");
end
for k = 1:length(h.Children)
    if isa(h.Children(k), "matlab.graphics.layout.TiledChartLayout")
        sg = h.Children(k).Title;
        sg.FontSize = get(groot, "DefaultAxesFontSize")*...
            get(groot, "factoryAxesTitleFontSizeMultiplier");
        sg.FontWeight = "bold";
    end
end
%%
if ~isempty(options.Theme)
    theme(h, options.Theme);
end
if ~isempty(options.Save)
    exportgraphics(h, options.Save, ContentType=options.ContentType, Resolution=options.Resolution, ...
        Append=options.Append, BackgroundColor=options.BackgroudColor);
end
