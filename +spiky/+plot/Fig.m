function h = fig(width, height, options)
%FIG draws figure with specified size at automatically calculated position
%   on the rightmost monitor
%
%   width: width of the figure in pixels or in percentage of the screen width
%   height: height of the figure in pixels or in percentage of the screen height
%   options: named arguments passed to the figure() function

arguments
    width = 0.8
    height = 0.8
    options.?matlab.ui.Figure
end

mon = get(0, "MonitorPositions");
res = mon(end, 3:4);
pos = mon(end, 1:2)-1;
if ~isnan(str2double(width))
    width = str2double(width);
end
if ~isnan(str2double(height))
    height = str2double(height);
end
if width<=1
    width = res(1)*width;
end
if height<=1
    height = res(2)*height;
end
figsize = [width, height];
propArgs = namedargs2cell(options);
h1 = figure("Position", [round((res-figsize)/2)+pos, figsize], propArgs{:});
if nargout
    h = h1;
end

end