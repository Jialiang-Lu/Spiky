function [indices, counts] = findInPeriods(array, periods, rightClose)
% FINDINPERIODS Find indices of array elements within periods
% [indices, counts] = findInPeriods(array, periods, rightClose)
%
%   array: 1D sorted array of doubles
%   periods: periods as n x 2 double
%   [rightClose]: whether the right boundary is closed
%
%   indices: indices of first elements within each period
%   counts: counts of elements within each period

arguments
    array double {mustBeVector}
    periods (:, 2) double
    rightClose (1, 1) logical = false
end
[indices, counts] = spiky.mex.findInPeriods_(array, periods, rightClose);

end
