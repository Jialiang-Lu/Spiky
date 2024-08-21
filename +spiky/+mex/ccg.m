function [ccg, pairs] = ccg(events, ids, binSize, halfBins)
% CCG Compute cross-correlogram
%
%   ccg = CCG(events, marks, binSize, halfBins)
%
%   events: (double) event times
%   ids: (int32) id of each event
%   binSize: (double) bin size in the event time units
%   halfBins: (int32) number of bins on each side of the correlogram
%
%   ccg: [2*halfBins+1, nIds, nIds] cross-correlogram 
%   pairs: [nPairs, 2] pairs of event index of each pair in the correlogram 

arguments
    events (:, 1) double
    ids (:, 1) int32
    binSize (1, 1) double
    halfBins (1, 1) int32
end
[ccg, pairs] = spiky.mex.ccg_(events, ids, binSize, halfBins);

end