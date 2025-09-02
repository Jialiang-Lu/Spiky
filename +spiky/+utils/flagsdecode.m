function cats = flagsdecode(flags, valueset)
% FLAGSDECODE Decode binary matrix flags into categorical flags
%   cats = flagsdecode(flags, valueset)
%
%   flags: NxK logical matrix, where flags(i, j) = true if valueset(j) is present in cats(i), false
%       otherwise.
%   valueset: Kx1 string array of valueset [X_1, X_2, ..., X_k].
%
%   cats: Nx1 categorical array of strings. cats(i) = "x_i1|x_i2|...|x_i_ni" where
%       x_ij is the j-th value of the i-th flag, and belongs to valueset.

arguments
    flags (:, :) logical
    valueset (:, 1)
end

valueset = string(valueset);
flags = num2cell(flags, 2);
cats = categorical(cellfun(@(x) join(valueset(x), "|"), flags));
