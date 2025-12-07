function [C, ia, ic] = balance(A, options)
%BALANCE Balance class counts in a vector by random down/upsampling.
%   [C, ia, ic] = balance(A, options)
%
%   A: Vector of values (categorical, numeric, string, etc.)
%   Name-Value arguments:
%       Count: string scalar, "min" to match minimum count (downsample),
%           "max" to match maximum count (upsample). Default: "min"
%       Sort: logical scalar, true to sort output C by class, false to preserve
%           original order. Default: true
%
%   C: Balanced vector with equal count per unique value
%   ia: Indices such that A(ia) == C
%   ic: Indices such that C(ic) == A; for elements dropped 
%       during downsampling, ic is NaN. When a value appears multiple 
%       times in C, the first match is used.

%% Input validation & defaults
arguments
    A {mustBeVector}
    options.Count (1, 1) string {mustBeMember(options.Count, ["min", "max"])} = "max"
    options.Sort (1, 1) logical = true
end

%% Normalize shape and derive classes
isRow = isrow(A);
xCol  = A(:);
[classes, ~, classIds] = unique(xCol, "sorted");
nClasses = numel(classes);
counts = accumarray(classIds, 1, [nClasses, 1]);

useMin = options.Count=="min";
insertAdjacent = ~options.Sort;

%% Determine target count per class
if useMin
    targetCount = min(counts);
else
    targetCount = max(counts);
end

%% Downsample to minimum (UseMin = true)
if useMin
    keepIdx = zeros(targetCount * nClasses, 1);
    pos = 0;
    for kk = 1:nClasses
        idxK = find(classIds == kk);
        nK   = counts(kk);
        if nK > targetCount
            take = randperm(nK, targetCount);
            sel  = idxK(take);
        else
            sel  = idxK;
        end
        keepIdx(pos + (1:numel(sel))) = sel;
        pos = pos + numel(sel);
    end
    keepIdx = sort(keepIdx(1:pos), "ascend");                 % preserve original order
    yCol         = xCol(keepIdx);
    ia = keepIdx;

    % Build inverse map: position in C for each original A (NaN when dropped)
    ic = nan(numel(xCol), 1);
    ic(keepIdx) = (1:numel(yCol)).';

%% Upsample to maximum (UseMin = false)
else
    totalLen = nClasses * targetCount;

    if insertAdjacent
        % Decide how many duplicates to insert after each original position
        dupCountsPerIndex = zeros(numel(xCol), 1);
        for kk = 1:nClasses
            idxK = find(classIds == kk);
            nK   = counts(kk);
            need = targetCount - nK;
            if need > 0
                r = randi(nK, need, 1);                        % with replacement
                baseIdx = idxK(r);
                for ii = 1:numel(baseIdx)
                    dupCountsPerIndex(baseIdx(ii)) = dupCountsPerIndex(baseIdx(ii)) + 1;
                end
            end
        end

        % Build C indices by inserting duplicates adjacent to originals
        yInds = zeros(totalLen, 1);
        pos = 0;
        for ii = 1:numel(xCol)
            pos = pos + 1;
            yInds(pos) = ii;
            d = dupCountsPerIndex(ii);
            if d > 0
                yInds(pos + (1:d)) = ii;                       % insert duplicates
                pos = pos + d;
            end
        end

    else
        % Group into continuous class chunks of equal size
        yInds = zeros(totalLen, 1);
        pos = 0;
        for kk = 1:nClasses
            idxK = find(classIds == kk);
            nK   = counts(kk);
            need = targetCount - nK;
            if need > 0
                r = randi(nK, need, 1);                        % with replacement
                dupIdx = idxK(r);
                block  = [idxK; dupIdx];
            else
                block  = idxK;
            end
            % Keep original order within each class block
            yInds(pos + (1:targetCount)) = block(1:targetCount);
            pos = pos + targetCount;
        end
    end

    yCol         = xCol(yInds);
    ia = yInds;

    % For each original A position, record the first occurrence in C
    ic = nan(numel(xCol), 1);
    for jj = 1:numel(yInds)
        iIn = yInds(jj);
        if isnan(ic(iIn))
            ic(iIn) = jj;
        end
    end
end

%% Restore shape
if isRow
    C = yCol.';
else
    C = yCol;
end
end
