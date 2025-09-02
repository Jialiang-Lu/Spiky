function [flags, valueset] = flagsencode(cats, valueset)
% FLAGSENCODE Encode categorical flags into a binary matrix
%   flags = flagsencode(cats, valueset)
%
%   cats: Nx1 categorical array of strings. cats(i) = "x_i1|x_i2|...|x_i_ni" where
%       x_ij is the j-th value of the i-th flag, and belongs to valueset.
%   valueset: Kx1 string array of valueset [X_1, X_2, ..., X_k]. Determined from cats if not
%   provided.
%
%   flags: NxK logical matrix, where flags(i, j) = true if valueset(j) is present in cats(i), false
%       otherwise.

arguments
    cats (:, 1)
    valueset (:, 1) string = string.empty
end

cats = string(cats);
c = arrayfun(@(x) split(x, "|"), cats, UniformOutput=false);
if isempty(valueset)
    valueset = unique(vertcat(c{:}));
    valueset = valueset(valueset~="");
end
is = cellfun(@(x) ismember(valueset, x), c, UniformOutput=false);
flags = cell2mat(is')';
