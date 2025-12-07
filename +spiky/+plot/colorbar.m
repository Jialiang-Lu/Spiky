function h = colorbar(varargin)
% COLORBAR1 Create a colorbar that looks identical to MATLAB's but uses PCOLOR.

%% ---- Read layout from a temporary colorbar (then remove it) ----
% Make a real colorbar to capture the exact layout MATLAB would choose.
ax = gca;
tmpCbar = colorbar(ax, varargin{:});                  % <-- layout oracle
drawnow;                                              % ensure Position is final
cbPos        = tmpCbar.Position;
cbOrientation = tmpCbar.Orientation;                  % "vertical"|"horizontal"
cbTicks       = tmpCbar.Ticks;
cbTickLabels  = string(tmpCbar.TickLabels);
cbFontName    = tmpCbar.FontName;
cbFontSize    = tmpCbar.FontSize;
cbTickDir     = tmpCbar.TickDirection;                % "in"|"out"
cbLineWidth   = tmpCbar.LineWidth;
cbLocation    = tmpCbar.Location;                     % e.g. "eastoutside"
tmpCbar.Visible = "off";

%% ---- Prepare color data consistent with parent axes CLim/colormap ----
clim = ax.CLim;
cmap = colormap(ax);
nColors = size(cmap,1);

switch cbOrientation
    case "vertical"
        % Build edges and center values for a vertical strip [0,1] x [cmin,cmax]
        yEdges = linspace(clim(1), clim(2), nColors+1);
        xEdges = [0 1];
        % [XE, YE] = meshgrid(xEdges, yEdges);
        yCenters = 0.5*(yEdges(1:end-1) + yEdges(2:end));
        C = yCenters(:);                              % nColors x 1
    case "horizontal"
        % Build edges and center values for a horizontal strip [cmin,cmax] x [0,1]
        xEdges = linspace(clim(1), clim(2), nColors+1);
        yEdges = [0 1];
        % [XE, YE] = meshgrid(xEdges, yEdges);
        xCenters = 0.5*(xEdges(1:end-1) + xEdges(2:end));
        C = xCenters(:).';                            % 1 x nColors
    otherwise
        error("Unsupported orientation: %s", cbOrientation);
end

%% ---- Create axes at the exact same position and draw with PCOLOR ----
fig = ancestor(ax, "figure");
hcb = axes("Parent", fig, "Units", "normalized", "Position", cbPos); %#ok<LAXES>
colormap(hcb, cmap);
C = padarray(C, [1 1], "replicate", "post");

switch cbOrientation
    case "vertical"
        % C must be size [numel(yEdges)-1, numel(xEdges)-1] = [nColors, 1]
        hp = pcolor(hcb, xEdges, yEdges, C);
        set(hcb, "YDir", "normal", "XLim", [0 1], "YLim", clim);
        % Axis side based on Location
        switch cbLocation
            case "eastoutside"
                hcb.YAxisLocation = "right";
            case "westoutside"
                hcb.YAxisLocation = "left";
        end
    case "horizontal"
        % C must be size [numel(yEdges)-1, numel(xEdges)-1] = [1, nColors]
        hp = pcolor(hcb, xEdges, yEdges, C);
        set(hcb, "XLim", clim, "YLim", [0 1]);
        switch cbLocation
            case "northoutside"
                hcb.XAxisLocation = "top";
            case "southoutside"
                hcb.XAxisLocation = "bottom";
        end
end

% Make the tiles look like a standard colorbar
set(hp, "EdgeColor", "none");           % no grid lines between tiles
shading(hcb, "flat");                  % flat shading = solid tiles
box(hcb, "on");                        % visible box like default colorbar

%% ---- Ticks, labels, fonts: mirror the real colorbar we probed ----
switch cbOrientation
    case "vertical"
        if ~isempty(cbTicks),     hcb.YTick = cbTicks;      end
        if ~isempty(cbTickLabels),hcb.YTickLabel = cbTickLabels; end
        hcb.XTick = []; hcb.XTickLabel = [];
    case "horizontal"
        if ~isempty(cbTicks),     hcb.XTick = cbTicks;      end
        if ~isempty(cbTickLabels),hcb.XTickLabel = cbTickLabels; end
        hcb.YTick = []; hcb.YTickLabel = [];
end
hcb.FontName    = cbFontName;
hcb.FontSize    = cbFontSize;
hcb.LineWidth   = cbLineWidth;
hcb.TickDir     = cbTickDir;

%% ---- Keep CLim consistent with parent and lock it ----
hcb.CLim = clim;                                  % scaled mapping
axes(ax);                                       % restore parent axes

if nargout>0
    h = hcb;
end

end
