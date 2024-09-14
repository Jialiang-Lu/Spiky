function map = colormap(name, n, qualitative)
%COLORMAP Get a colormap by name
%
%   map = COLORMAP(name, n)
%
%   name: name of the colormap
%   n: number of colors
%   qualitative: qualitative colormap
%
%   map: [n, 3] colormap
%
% Zhaoxu Liu / slandarer (2024). 200 colormap 
% (https://www.mathworks.com/matlabcentral/fileexchange/120088-200-colormap), 
% MATLAB Central File Exchange

arguments
    name (1, 1) string {mustBeMember(name, [
        "viridis"
        "plasma"
        "inferno"
        "magma"
        "cividis"
        "parula"
        "Greys"
        "Purples"
        "Blues"
        "Greens"
        "Oranges"
        "Reds"
        "YlOrBr"
        "YlOrRd"
        "OrRd"
        "PuRd"
        "RdPu"
        "BuPu"
        "GnBu"
        "PuBu"
        "YlGnBu"
        "PuBuGn"
        "BuGn"
        "YlGn"
        "binary"
        "gist_yarg"
        "gist_gray"
        "gray"
        "bone"
        "pink"
        "spring"
        "summer"
        "autumn"
        "winter"
        "cool"
        "Wistia"
        "hot"
        "afmhot"
        "gist_heat"
        "amber"
        "copper"
        "batlow"
        "dusk"
        "eclipse"
        "ember"
        "fall"
        "gem"
        "haline"
        "hawaii"
        "dense"
        "amp"
        "bilbao"
        "deep"
        "matter"
        "speed"
        "tempo"
        "turbid"
        "heat"
        "ice"
        "imola"
        "lapaz"
        "neutral"
        "nuuk"
        "savanna"
        "sepia"
        "solar"
        "thermal"
        "thermal-2"
        "tokyo"
        "turku"
        "amethyst"
        "arctic"
        "bubblegum"
        "emerald"
        "flamingo"
        "freeze"
        "ghostlight"
        "gothic"
        "horizon"
        "jungle"
        "lavender"
        "lilac"
        "nuclear"
        "pepper"
        "sapphire"
        "sunburst"
        "swamp"
        "torch"
        "toxic"
        "tree"
        "voltage"
        "PiYG"
        "PRGn"
        "BrBG"
        "PuOr"
        "RdGy"
        "RdBu"
        "RdYlBu"
        "RdYlGn"
        "spectral"
        "prinsenvlag"
        "coolwarm"
        "bwr"
        "seismic"
        "broc"
        "curl"
        "holly"
        "delta"
        "fusion"
        "roma"
        "vik"
        "viola"
        "waterlily"
        "pride"
        "bjy"
        "guppy"
        "berlin"
        "bky"
        "iceburn"
        "lisbon"
        "redshift"
        "vanimo"
        "watermelon"
        "wildfire"
        "seaweed"
        "hsv"
        "bamo"
        "broco"
        "cet_c1"
        "colorwheel"
        "corko"
        "phase"
        "rainbow-iso"
        "romao"
        "twilight"
        "twilight_s"
        "seasons"
        "seasons_s"
        "infinity"
        "infinity_s"
        "copper2"
        "copper2_s"
        "emergency"
        "emergency_s"
        "flag"
        "prism"
        "colorcube"
        "ocean"
        "gist_earth"
        "terrain"
        "gist_stern"
        "gnuplot"
        "gnuplot2"
        "brg"
        "tropical"
        "CMRmap"
        "cubehelix"
        "apple"
        "chroma"
        "cosmic"
        "rain"
        "gist_rainbow"
        "rainbow"
        "rainbow-kov"
        "rainbow-sc"
        "rainforest"
        "jet"
        "turbo"
        "neon"
        "nipy_spectral"
        "gist_ncar"
        "oxy"
        "bukavu"
        "fes"
        "oleron"
        "topo"
        "Pastel1"
        "Pastel2"
        "Paired"
        "Accent"
        "Dark2"
        "Set1"
        "Set2"
        "Set3"
        "tab10"
        "tab20"
        "tab20b"
        "tab20c"
        "538"
        "bold"
        "brewer"
        "colorblind"
        "glasbey"
        "glasbey_bw"
        "glasbey_category10"
        "glasbey_dark"
        "glasbey_hv"
        "glasbey_light"
        "prism2"
        "vivid"
        ])}
    n double {mustBeScalarOrEmpty} = []
    qualitative logical = false
end

fpth = mfilename("fullpath");
fdir = fileparts(fpth);
maps = load(fullfile(fdir, "colormaps.mat"));
maps = maps.maps;
if ~isKey(maps, name)
    warning("Colormap %s not found", name);
    map1 = colormap("parula");
else
    map1 = maps{name};
end
n1 = size(map1, 1);
if isempty(n)
    n = n1;
end
if qualitative
    idc = 1:n;
    idc = mod(idc-1, n1)+1;
    map1 = map1(idc, :);
elseif n~=n1
    map1 = interp1((1:n1)', map1, linspace(1, n1, n));
end
if nargout>0
    map = map1;
else
    colormap(map1);
end
end
