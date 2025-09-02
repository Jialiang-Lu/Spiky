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
if isempty(getCurrentWorker())
    [indices, counts] = spiky.mex.findInPeriods_(array, periods, rightClose);
    return
end
nPeriods = size(periods, 1);
nEvents = length(array);
indices = zeros(nPeriods, 1);
counts = zeros(nPeriods, 1);

p = 1;

for i = 1:nPeriods
    tStart = periods(i, 1);
    tEnd = periods(i, 2);
    while p<=nEvents && array(p)<tStart
        p = p+1;
    end
    q = p;
    if rightClose
        while q<=nEvents && array(q)<=tEnd
            q = q+1;
        end
    else
        while q<=nEvents && array(q)<tEnd
            q = q+1;
        end
    end
    if p <= nEvents && array(p) <= tEnd
        indices(i) = p;
        counts(i) = q-p;
    else
        indices(i) = 0;
        counts(i) = 0;
    end
end
end
