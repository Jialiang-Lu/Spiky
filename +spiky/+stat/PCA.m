classdef PCA < spiky.stat.GroupedStat
    % PCA class of principal component analysis objects
    %
    % The first dimension is time, the second dimension is the group, and the third dimension 
    % is the sample

    methods
        function obj = PCA(time, data, groupIndices, groups, eventLabels, options)
            %PCA Principal component analysis
            %
            %   obj = PCA(time, data, eventLabels, groupIndices, groups, options)
            %
            %   time: time points
            %   data: data, nTime*nSamples cell array of matrices of nEvents*nVariables
            %   groupIndices: indices of variable groups
            %   groups: names of variable groups
            %   eventLabels: labels of events, PCA is peformed over average of each label group
            %   options: options for PCA
            %
            %   obj: PCA object

            arguments
                time (:, 1) double
                data (:, :) cell
                groupIndices = []
                groups = []
                eventLabels = []
                options.Centered logical = true
            end

            if height(data) ~= numel(time)
                error("The number of time points and values must be the same")
            end
            if isempty(eventLabels)
                eventLabels = (1:height(data{1}))';
            end
            if isempty(groupIndices)
                groupIndices = ones(width(data{1}), 1);
            end
            if isnumeric(groupIndices)
                groupIndices = arrayfun(@(x) groupIndices==x, unique(groupIndices), UniformOutput=false);
            end
            nGroups = numel(groupIndices);
            if ~isempty(groups) && nGroups~=numel(groups)
                error("The number of groups must be the same as the number of columns in the data")
            end
            optionArgs = namedargs2cell(options);
            nT = numel(time);
            nSamples = width(data);
            if ~iscell(eventLabels)
                eventLabels = repmat({eventLabels}, nSamples, 1);
            end
            n = nT*nGroups*nSamples;
            pcData = cell(nT, nGroups, nSamples);
            parfor ii = 1:n
                [idxT, idxG, idxS] = ind2sub([nT nGroups nSamples], ii);
                data1 = groupsummary(data{idxT, idxS}(:, groupIndices{idxG}), eventLabels{idxS}, @mean);
                [coeff, ~, latent, tsquared, explained, mu] = pca(data1, optionArgs{:});
                score = (data{idxT, idxS}(:, groupIndices{idxG})-mu)*coeff;
                pcData{ii} = struct("Coeff", coeff, "Score", score, "Latent", latent, ...
                    "Tsquared", tsquared, "Explained", explained, "Mu", mu);
            end
            obj@spiky.stat.GroupedStat(time, pcData, groups, groupIndices);
        end

        function c = coeff(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            c = obj.get("Coeff", indices{:});
        end

        function s = score(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            s = obj.get("Score", indices{:});
        end

        function l = latent(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            l = obj.get("Latent", indices{:});
        end

        function t = tsquared(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            t = obj.get("Tsquared", indices{:});
        end

        function e = explained(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            e = obj.get("Explained", indices{:});
        end

        function m = mu(obj, indices)
            arguments
                obj spiky.stat.PCA
            end
            arguments (Repeating)
                indices
            end
            if isempty(indices)
                indices = {1, 1, 1};
            end
            m = obj.get("Mu", indices{:});
        end

        function out = get(obj, varName, indices)
            arguments
                obj spiky.stat.PCA
                varName string {mustBeMember(varName, ...
                    ["Coeff" "Score" "Latent" "Tsquared" "Explained" "Mu"])} = "Coeff"
            end
            arguments (Repeating)
                indices
            end
            out = obj.Data{indices{:}}.(varName);
        end

        function data = transform(obj, data, indices)
            %TRANSFORM Transform data on the principal components
            %
            %   data = transform(obj, data, indices)
            %
            %   obj: PCA object
            %   data: data to transform
            %   indices: indices of the PCA object

            arguments
                obj spiky.stat.PCA
                data
            end
            arguments (Repeating)
                indices
            end

            if isempty(indices)
                indices = {1, 1, 1};
            end
            data = (data - obj.get("Mu", indices{:}))*obj.get("Coeff", indices{:});
        end

        function [obj, labels] = mean(obj, eventLabels, nBoot, data)
            %MEAN Calculate mean of the data
            %
            %   [obj, labels] = mean(obj, eventLabels, nBoot, data)
            %
            %   obj: PCA object
            %   eventLabels: labels of events, mean is calculated on each label group
            %   nBoot: number of bootstrap samples
            %   data: data to transform, if empty, use the original data

            arguments
                obj spiky.stat.PCA
                eventLabels (:, 1) = []
                nBoot double = 1
                data = []
            end

            if isempty(eventLabels)
                eventLabels = ones(height(obj.score()), 1);
            end
            if iscategorical(eventLabels)
                eventLabels = removecats(eventLabels);
            end
            if isa(data, "spiky.stat.PCA")
                data = data.Data;
                data = cellfun(@(x) x.Score*x.Coeff'+x.Mu, data, UniformOutput=false);
            end
            labels = unique(eventLabels);
            nLabels = numel(labels);
            n = numel(obj.Data);
            nT = height(obj);
            nGroups = width(obj);
            nSamples = size(obj, 3);
            for ii = 1:n
                [idxT, idxG, idxS] = ind2sub([nT nGroups nSamples], ii);
                if isempty(data)
                    d = obj.score(idxT, idxG, idxS);
                else
                    d = obj.transform(data{ii}, idxT, idxG, idxS);
                end
                % d1 = zeros(nBoot*nLabels, width(d));
                d1 = cell(nLabels, 1);
                parfor jj = 1:nLabels
                    d2 = d(eventLabels==labels(jj), :);
                    if nBoot==1
                        d1{jj} = mean(d2, 1);
                    else
                        d1{jj} = bootstrp(nBoot, @mean, d2);
                    end
                end
                d1 = cell2mat(d1);
                obj.Data{ii}.Score = d1;
            end
            labels = reshape(repmat(labels, 1, nBoot)', [], 1);
        end

        function d = dist(obj, otherObj, nDims, type)
            %ANGLE Calculate distance between (two) PC (hyper)planes
            %
            %   d = dist(obj, otherObj, nDims)
            %
            %   obj: PCA object
            %   otherObj: other PCA object
            %   nDims: number of dimensions to consider
            %   type: distance metric type
            %
            %   d: distance metric

            arguments
                obj spiky.stat.PCA
                otherObj = []
                nDims double = 2
                type string {mustBeMember(type, ["angle" "frob" "vaf"])} = "angle"
            end

            c1 = cellfun(@(x) x.Coeff(:, 1:nDims), obj.Data, UniformOutput=false);
            c2 = [];
            if ~isempty(otherObj)
                if ~isa(otherObj, "spiky.stat.PCA") || ~isequal(size(obj), size(otherObj))
                    error("The number of PCA objects must be the same")
                end
                c2 = cellfun(@(x) x.Coeff(:, 1:nDims), otherObj.Data, UniformOutput=false);
            end
            nT = height(obj);
            nGroups = width(obj);
            nSamples = size(obj, 3);
            d = zeros(nT, nGroups, nSamples);
            n = nT*nGroups*nSamples;
            parfor ii = 1:n
                [idxT, idxG, ~] = ind2sub([nT nGroups nSamples], ii);
                p1 = c1{ii};
                if isempty(c2)
                    p2 = cat(3, c1{idxT, idxG, :});
                else
                    p2 = cat(3, c2{idxT, idxG, :});
                end
                p2 = mean(p2, 3);
                if type=="angle"
                    d(ii) = spiky.core.Vector.planeAngle(p1, p2);
                elseif type=="frob"
                    d(ii) = norm(p1*p1'-p2*p2', "fro")./nDims;
                else
                    error("Unknown distance metric type")
                end
            end
        end
    end
end