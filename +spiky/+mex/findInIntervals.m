function [indices, counts] = findInIntervals(array, intervals, rightClose)
%FINDININTERVALS Find indices of array elements within intervals
% [indices, counts] = findInIntervals(array, intervals, rightClose)
%
%   array: 1D sorted array of doubles
%   intervals: intervals as n x 2 double
%   [rightClose]: whether the right boundary is closed
%
%   indices: indices of first elements within each interval
%   counts: counts of elements within each interval

arguments
    array double {mustBeVector}
    intervals (:, 2) double
    rightClose (1, 1) logical = false
end
if isempty(getCurrentWorker())
    [indices, counts] = spiky.mex.findInIntervals_(array, intervals, rightClose);
    return
end
nIntervals = size(intervals, 1);
nEvents = length(array);
indices = zeros(nIntervals, 1);
counts = zeros(nIntervals, 1);

p = 1;

for i = 1:nIntervals
    tStart = intervals(i, 1);
    tEnd = intervals(i, 2);
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
