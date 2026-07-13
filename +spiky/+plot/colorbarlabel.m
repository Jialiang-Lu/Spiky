function h = colorbarlabel(txt, plotOps)
%COLORBARLABEL Adds a label to the colorbar of a plot.
arguments
    txt string
    plotOps.?matlab.graphics.primitive.Text
end
cb = colorbar;
cb.Label.String = txt;
plotArgs = namedargs2cell(plotOps);
if ~isempty(plotArgs)
    set(cb.Label, plotArgs{:});
end
if nargout>0
    h = cb.Label;
end
end
