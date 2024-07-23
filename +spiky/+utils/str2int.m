function x = str2int(txt, formatSpec)
%STR2INT Convert string to integer correctly for values above flintmax
%   
%   txt: input text to scan
%   formatSpec: format of the field for textscan, e.g. "%d64"
%
%   X: numeric array of int

narginchk(1, 2)
if ~exist("formatSpec", "var") || isempty(formatSpec)
    formatSpec = "%d64";
end
txt = convertCharsToStrings(txt);
formatSpec = convertCharsToStrings(formatSpec);
if iscell(txt)
    x = cellfun(@(t) str2int(t, formatSpec), txt);
    return
end
if startsWith(formatSpec, "int")
    formatSpec = "%d"+string(formatSpec{1}(4:end));
elseif startsWith(formatSpec, "uint")
    formatSpec = "%u"+string(formatSpec{1}(5:end));
end
if ~startsWith(formatSpec, "%")
    formatSpec = "%"+formatSpec;
end
if ~ismember(formatSpec{1}(2), ["d", "u", "x", "b"])
    error("Format specification %s is not an integer", formatSpec)
end
if isscalar(txt)
    out = textscan(txt, formatSpec);
    x = out{1};
else
    sz = size(txt);
    n = numel(txt);
    out = textscan(txt(1), formatSpec);
    x = zeros(sz, class(out{1}));
    for ii = 1:n
        out = textscan(txt(ii), formatSpec);
        x(ii) = out{1};
    end
end