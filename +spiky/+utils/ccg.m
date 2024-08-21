function [ccg, tCcg] = ccg(cellEvents, binSize, halfBins, normalization, epochs)
% CCG Compute cross-correlogram
%
%   ccg = CCG(cellEvents, binSize, halfBins, normalization, epochs)
%
%   cellEvents: (cell) of event times
%   binSize: bin size in the event time units
%   halfBins: number of bins on each side of the correlogram
%   normalization: type of y-axis normalization, can be "idx", "hz", "hz2", or "scale"
%   [epochs]: [n, 2] epochs to compute from
%
%   ccg: [2*halfBins+1, nCells, nCells] cross-correlogram
%   tCcg: [2*halfBins+1, 1] time axis for the bins in s

arguments
    cellEvents
    binSize (1, 1) double
    halfBins (1, 1) double
    normalization (1, 1) string {mustBeMember(normalization, ["count", "hz", "hz2", "scale"])} = "hz"
    epochs = []
end

%% Flatten inputs
if isnumeric(cellEvents)
    cellEvents = {cellEvents(:)};
end
nGroups = numel(cellEvents);
nEvents = cellfun(@numel, cellEvents);
t = zeros(sum(nEvents), 1);
ids = zeros(sum(nEvents), 1, "int32");
idx = 0;
for ii = 1:nGroups
    if isempty(cellEvents{ii})
        continue
    end
    t(idx+1:idx+nEvents(ii)) = cellEvents{ii}(:);
    ids(idx+1:idx+nEvents(ii)) = ii;
    idx = idx + nEvents(ii);
end
[~, idc] = sort(t);
t = t(idc);
ids = ids(idc);
if ~isempty(epochs)
    gaps = epochs(2:end, 1) - epochs(1:end-1, 2);
    tooShort = find(gaps < binSize*(halfBins+0.5));
    if ~isempty(tooShort)
        warning("Epochs %s are followed by too-short gaps", strjoin(string(tooShort), " "));
    end
    [t, idc] = spiky.core.Periods(epochs).haveEvents(t);
    ids = ids(idc);
end
nEvents = numel(t);
nEventsPerGroup = zeros(nGroups, 1);
for ii = 1:nGroups
    nEventsPerGroup(ii) = sum(ids==ii);
end

%% Compute CCG
counts = double(spiky.mex.ccg(t, ids, binSize, int32(halfBins)));
if isempty(epochs)
    tRange = max(t)-min(t);
else
    tRange = sum(diff(epochs, [], 2));
end
tCcg = (-halfBins:halfBins)'*binSize;

%% Compute bias
nBins = 2*halfBins+1;
if isempty(epochs)
    bias = ones(nBins, 1);
else
    nTerm = [halfBins:-1:1, 0.25, 1:halfBins];
    bias = zeros(nBins, 1);
    totLen = 0;
    for ii = 1:size(epochs, 1)
        epochLen = epochs(ii, 2) - epochs(ii, 1);
        epochBias = max(epochLen-nTerm*binSize, 0)*binSize;
        bias = bias+epochBias';
        totLen = totLen+epochLen;
    end
    bias = bias/totLen/binSize;
end

%% Normalize
ccg = zeros(nBins, nGroups, nGroups);
for ii = 1:nGroups
    for jj = 1:nGroups
        switch normalization
            case "count"
                factor = 1;
            case "hz"
                factor = 1/(binSize*nEventsPerGroup(ii));
            case "hz2"
                factor = 1/(tRange*binSize);
            case "scale"
                factor = tRange/(binSize*nEventsPerGroup(ii)*nEventsPerGroup(jj));
        end
        ccg(:, ii, jj) = flipud(counts(:, ii, jj))*factor./bias;
        ccg(:, jj, ii) = counts(:, ii, jj)*factor./bias;
    end
end

