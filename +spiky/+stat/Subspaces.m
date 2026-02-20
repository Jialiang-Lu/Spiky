classdef Subspaces < spiky.stat.GroupedStat
    %SUBSPACES Class representing a set of subspaces

    methods
        function obj = Subspaces(time, data, groups, groupIndices)
            %SUBSPACES Create a new instance of Subspaces
            %   Subspaces(time, data, groups, groupIndices)
            %
            %   time: time points
            %   data: coordinates
            %   groups: groups
            %   groupIndices: indices of the groups
            %
            %   obj: Subspaces object
            arguments
                time double = []
                data cell = {} % spiky.stat.Coords
                groups = []
                groupIndices cell = {}
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
        end

        function obj = addBasis(obj, data, options)
            %ADDBASIS Add basis to the subspaces
            %
            %   obj = ADDBASIS(obj, data, options)
            %
            %   obj: Subspaces object
            %   data: data to add, nT x nBases x nNeurons
            %   Name-value arguments:
            %       BasisNames: names of the added bases
            %       Orth: if true, added basis will be orthogonal to existing bases
            %       Normalize: if true, normalize the added bases to unit length
            %       LearnerIndex: index of the learner if data is Classifier
            arguments
                obj spiky.stat.Subspaces
                data
                options.BasisNames (:, 1) string = compose("Add%d", 1:width(data))
                options.Orth logical = false
                options.Normalize logical = false
                options.LearnerIndex double = []
            end
            if isa(data, "spiky.stat.Classifier")
                assert(~isempty(options.LearnerIndex), ...
                    "LearnerIndex must be provided if data is a Classifier");
                V = cellfun(@(x) x.BinaryLearners{options.LearnerIndex}.Beta, ...
                    data.Data, UniformOutput=false);
            elseif isa(data, "spiky.core.EventsTable")
                V = cellfun(@(x) permute(data.Data(:, :, x), [3 2 1]), obj.GroupIndices, ...
                    UniformOutput=false);
            elseif isnumeric(data)
                V = cellfun(@(x) permute(data(:, :, x), [3 2 1]), obj.GroupIndices, ...
                    UniformOutput=false);
            else
                error("Data must be a numeric array or a spiky.core.EventsTable or a spiky.stat.Classifier")
            end
            nT = size(V{1}, 3);
            if nT~=height(obj)
                assert(height(obj)==1, "The number of time points must be the same as the "+...
                    "number of time points in the Subspaces, or the Subspaces must have only one time point");
                idcT = ones(nT, 1);
            else
                idcT = 1:nT;
            end
            data1 = cell(nT, obj.NGroups);
            for ii = 1:nT
                idxT = idcT(ii);
                for jj = 1:obj.NGroups
                    V1 = V{jj}(:, :, idxT);
                    coords = obj.Data{idxT, jj};
                    if options.Orth
                        [~, proj1] = coords.project(V1);
                        V1 = V1-proj1;
                    else
                        V1 = V1-coords.Origin;
                    end
                    if options.Normalize
                        V1 = V1./vecnorm(V1, 2, 1);
                    end
                    data1{ii, jj} = spiky.stat.Coords(coords.Origin, ...
                        [coords.Bases V1], coords.DimNames, ...
                        [coords.BasisNames; options.BasisNames]);
                end
            end
            obj.Data = data1;
        end

        function data = project(obj, data, idcDim, options)
            %PROJECT Project the data onto the coordinates
            %
            %   data = PROJECT(obj, data, idcDim)
            %
            %   obj: Subspaces
            %   data: data to project, nT x nEvents x nNeurons
            %   idcDim: indices of the dimensions to project
            %   Name-value arguments:
            %       Individual: whether to project each basis vector individually
            %
            %   data: projected data, nT x nEvents x (nBases x nGroups) x nSamples
            arguments
                obj spiky.stat.Subspaces
                data
                idcDim double = 1:obj.Data{1}.NBases
                options.Individual logical = false
            end
            if isa(data, "spiky.core.EventsTable")
                V = data.Data;
            elseif isnumeric(data)
                V = data;
            else
                error("Data must be a numeric array or a spiky.core.EventsTable")
            end
            nT = size(V, 1);
            nEvents = size(V, 2);
            nNeurons = size(V, 3);
            nBases = numel(idcDim);
            nGroups = obj.NGroups;
            nSamples = size(obj, 3);
            if nT~=height(obj)
                assert(height(obj)==1, "The number of time points must be the same as the "+...
                    "number of time points in the Subspaces, or the Subspaces must have only one time point");
                idcT = ones(height(V), 1);
            else
                idcT = 1:height(V);
            end
            if nNeurons~=sum(cellfun(@numel, obj.GroupIndices))
                error("The number of neurons must be the same as the number of neurons in the Subspaces")
            end
            C = zeros(nT, nEvents, nBases*nGroups, nSamples);
            for ii = 1:nT
                idxT = idcT(ii);
                for jj = 1:nGroups
                    for kk = 1:nSamples
                        V1 = permute(V(ii, :, obj.GroupIndices{jj}), [3 2 1]);
                        C1 = obj.Data{idxT, jj, kk}.project(V1, idcDim, Individual=options.Individual);
                        C1 = permute(C1, [3 2 1]);
                        C(ii, :, (1:nBases)+(jj-1)*nBases, kk) = C1;
                    end
                end
            end
            if isa(data, "spiky.core.EventsTable")
                data.Data = C;
                if isa(data, "spiky.core.Spikes")
                    data.Neuron = spiky.core.Neuron.create(...
                        data.Neuron.Session(1), obj.Groups, nBases);
                    % ses = data.Neuron.Session(1);
                    % data.Neuron = spiky.core.Neuron.zeros(nBases*nGroups);
                    % data.Neuron.Session = repmat(ses, height(data.Neuron), 1);
                    % data.Neuron.Region = categorical(repelem(string(obj.Groups), nBases, 1));
                    % data.Neuron.Group = repelem((1:nGroups)', nBases, 1);
                    % data.Neuron.Id = repmat((1:nBases)', nGroups, 1);
                end
                if isa(data, "spiky.trig.TrigFr")
                    data.Samples = (1:nSamples)';
                end
            else
                data = C;
            end
        end

        function projs = projectByPair(obj, data, cats1, cats2, options)
            %PROJECTBYPPAIR Project the data onto the pairwise combinations of bases
            %   projs = PROJECTBYPPAIR(obj, data, cats1, cats2, ...)
            %
            %   obj: Subspaces
            %   data: data to project, nT x nEvents x nNeurons
            %   cats1, cats2: categories of the bases to combine, nEvents x 1 categorical
            %   Name-value arguments:
            %       IdcEvents: indices of the events to use for projection
            %
            %   projs: cell array of projected data for each pair of bases, nT x nEvents x 2 x nSamples
            arguments
                obj spiky.stat.Subspaces
                data
                cats1 (:, 1) categorical
                cats2 (:, 1) categorical
                options.IdcEvents = []
            end
            if ~isempty(options.IdcEvents)
                data = data(:, options.IdcEvents, :);
                cats1 = cats1(options.IdcEvents);
                cats2 = cats2(options.IdcEvents);
            end
            basisNames = obj.Data{1}.BasisNames;
            assert(all(ismember(cats1, basisNames)) && all(ismember(cats2, basisNames)), ...
                "All categories must be present in the basis names of the Subspaces");
            nBases = numel(basisNames);
            idcUpper = find(triu(true(nBases), 1));
            nUpper = numel(idcUpper);
            [idc1, idc2] = ind2sub([nBases nBases], idcUpper);
            projs = cell(nUpper, 1);
            for ii = 1:nUpper
                idx1 = idc1(ii);
                idx2 = idc2(ii);
                idcI = (cats1==basisNames(idx1) & cats2==basisNames(idx2)) | ...
                    (cats1==basisNames(idx2) & cats2==basisNames(idx1));
                events1 = zeros(sum(idcI), 1);
                events1(cats1(idcI)==basisNames(idx1)) = 1;
                events1(cats1(idcI)==basisNames(idx2)) = 2;
                projs{ii} = obj.project(data(:, idcI, :), [idx1 idx2]);
                projs{ii}.Events = events1;
            end
        end

        function obj = pca(obj, nDims)
            %PCA Perform PCA on the subspaces
            %
            %   obj = PCA(obj, nDims)
            %
            %   obj: Subspaces object with PCA applied
            %   nDims: number of dimensions to keep
            arguments
                obj spiky.stat.Subspaces
                nDims double
            end
            data1 = cellfun(@(x) x.pca(nDims), obj.Data, UniformOutput=false);
            obj.Data = data1;
        end

        function P = varExplained(obj, data, idcDim)
            %VAREXPLAINED Compute the variance explained by the subspaces
            %
            %   P = VAREXPLAINED(obj, data, idcDim)
            %
            %   obj: Subspaces
            %   data: data to project, nT x nEvents x nNeurons
            %   idcDim: indices of the dimensions to project
            %
            %   P: variance explained, nT x nEvents x nGroups x nSamples
            arguments
                obj spiky.stat.Subspaces
                data
                idcDim double = 1:obj.Data{1}.NBases
            end
            if isa(data, "spiky.core.EventsTable")
                V = data.Data;
            elseif isnumeric(data)
                V = data;
            else
                error("Data must be a numeric array or a spiky.core.EventsTable")
            end
            nT = size(V, 1);
            nEvents = size(V, 2);
            nNeurons = size(V, 3);
            nBases = numel(idcDim);
            nGroups = obj.NGroups;
            nSamples = size(obj, 3);
            if nT~=height(obj)
                if height(obj)>1
                    error("The number of time points must be the same as the number of time points in the Subspaces")
                end
                idcT = ones(height(V), 1);
            else
                idcT = 1:height(V);
            end
            if nNeurons~=sum(cellfun(@numel, obj.GroupIndices))
                error("The number of neurons must be the same as the number of neurons in the Subspaces")
            end
            P = zeros(nT, nEvents, nGroups, nSamples);
            for ii = 1:nT
                idxT = idcT(ii);
                for jj = 1:nGroups
                    for kk = 1:nSamples
                        coords = obj.Data{idxT, jj, kk};
                        V1 = permute(V(ii, :, obj.GroupIndices{jj}), [3 2 1]);
                        V2 = V1-coords.Origin;
                        C1 = coords.project(V1, idcDim);
                        V3 = coords.Bases(:, idcDim)*C1;
                        r2 = vecnorm(V3, 2, 1).^2./vecnorm(V2, 2, 1).^2;
                        P(ii, :, jj, kk) = (r2-nBases/coords.NDims)./(1-nBases/coords.NDims);
                    end
                end
            end
        end

        function obj = pairwiseExpand(obj)
            %PAIRWISEEXPAND Expand the subspaces to pairwise combinations of bases
            %
            %   obj = PAIRWISEEXPAND(obj)
            %
            %   obj: Subspaces object with pairwise combinations of bases
            nBases = obj.Data{1}.NBases;
            nT = height(obj.Data);
            nGroups = obj.NGroups;
            data1 = cell(nT, nGroups, nBases, nBases);
            for ii = 1:nBases
                for jj = 1:nBases
                    if ii==jj
                        data1(:, :, ii, jj) = cellfun(@(x) x(:, ii), obj.Data, UniformOutput=false);
                    else
                        data1(:, :, ii, jj) = cellfun(@(x) x(:, [ii jj]), obj.Data, UniformOutput=false);
                    end
                end
            end
            obj.Data = data1;
        end

        function obj = addPCA(obj, trigFr, options)
            %ADDPCA Add PCA basis to the subspaces
            %
            %   obj = ADDPCA(obj, trigFr, options)
            %
            %   obj: Subspaces object with PCA bases added
            %   trigFr: spiky.trig.TrigFr object
            %   Name-value arguments:
            %       NAdd: number of PCA basis vectors to add
            arguments
                obj spiky.stat.Subspaces
                trigFr spiky.trig.TrigFr
                options.NAdd double = 1
            end
            optionsCell = namedargs2cell(options);
            data = cellfun(@(x) permute(trigFr.Data(1, :, x), [3 2 1]), obj.GroupIndices, ...
                UniformOutput=false);
            func = @(coords, d) coords.addPCA(d, optionsCell{:});
            data1 = bsxfun(func, obj.Data, data);
            obj.Data = data1;
        end

        function sim = getSimilarity(obj, other, idcDims, options)
            %GETSIMILARITY Get the similarity between two Subspaces
            %   sim = GETSIMILARITY(obj, other, idcDims, options)
            %
            %   obj: Subspaces object
            %   other: another Subspaces object. If not provided, calculates similarity acroos
            %       different samples in the same Subspaces object
            %   idcDims: indices of the bases to use for similarity calculation
            %       (default: all bases)
            %   Name-value arguments:
            %       Metric: similarity metric ("projection" or "nuclear")
            %
            %   sim: similarity matrix, nT x nGroups x nSamples
            arguments
                obj spiky.stat.Subspaces
                other spiky.stat.Subspaces = spiky.stat.Subspaces
                idcDims double = 1:obj.Data{1}.NBases
                options.Metric string {mustBeMember(options.Metric, ["projection" "nuclear"])} = "projection"
            end
            if isempty(other)
                other = obj;
                other.Data = circshift(other.Data, 1, 3);
            end
            assert(isequal(size(obj.Data), size(other.Data)), ...
                "The two Subspaces must have the same size");
            optionsCell = namedargs2cell(options);
            sim = cellfun(@(x, y) x.getSimilarity(y, idcDims, optionsCell{:}), ...
                obj.Data, other.Data);
        end
    end
end