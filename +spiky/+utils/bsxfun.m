function c = bsxfun(f, a, b)
%BSXFUN Apply function to arrays with singleton expansion, supports object arrays
%
%   c = bsxfun(f, a, b)
%
%   f: function handle, must accept two inputs and return one output
%   a, b: input arrays, can be object arrays
%   c: output array, same size as the result of f(a, b)

ida = reshape(1:numel(a), size(a));
idb = reshape(1:numel(b), size(b));
id = bsxfun(@(x, y) x+1i*y, ida, idb);
% c = arrayfun(@(x) f(a(real(x)), b(imag(x))), id, UniformOutput=false);
% c = cell2mat(c);
n = numel(id);
for ii = n:-1:1
    c(ii) = f(a(real(id(ii))), b(imag(id(ii))));
end
c = reshape(c, size(id));