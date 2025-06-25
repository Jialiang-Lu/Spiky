function out = wrap(func, idc, varargin)
%WRAP Wraps a function call to select from multiple outputs.
% 
%   func: Function handle to be wrapped.
%   idc: Index or indices of the outputs to select.
%   varargin: Additional arguments for the function call.

arguments
    func
    idc (1, :) double {mustBePositive, mustBeInteger}
end
arguments (Repeating)
    varargin
end
m = max(idc);
out = cell(1, m);
[out{:}] = feval(func, varargin{:});
if isscalar(idc)
    out = out{idc};
else
    out = out(idc);
end

