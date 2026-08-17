classdef Subspaces < spiky.stat.Decoder
    %SUBSPACES Class representing a set of subspaces

    methods (Static)
        function obj = fromDecoders(decoders)
            arguments (Repeating)
                decoders spiky.stat.Decoder
            end
            decoders = decoders(:);
            szs = cellfun(@(d) size(d, 1:3), decoders, UniformOutput=false);
            assert(isequal(szs{:}), ...
                "All decoders must have the same size in the first 3 dimensions (time, groups, samples)");
            nCs = cellfun(@(d) size(d, 4), decoders);
            nCMax = max(nCs);
            idxMax = find(nCs==nCMax, 1);
            assert(all(ismember(nCs, [1 nCMax])), ...
                "The number of conditions must be either 1 or the maximum across decoders");
            nD = numel(decoders);
            nC = round(ones(nD, 1)+(0:nCMax-1).*(nCs>1)); % nD x nCMax
            [nT, nGroups, nSamples] = size(decoders{1}, 1:3);
            data = cell(nT, nGroups, nSamples, nCMax);
            n = nT*nGroups*nSamples*nCMax;
            nNeurons = numel(decoders{1}.Data{1}.BinaryLearners{1}.Beta);
            for ii = 1:n
                try
                    [idxT, idxG, idxS, idxC] = ind2sub([nT nGroups nSamples nCMax], ii);
                    idcC = nC(:, idxC);
                    nNeurons = sum(decoders{1}.GroupIndices(idxG, :));
                    w = zeros(nNeurons, nD);
                    b = zeros(nD, 1);
                    for jj = 1:nD
                        w(:, jj) = decoders{jj}.Data{idxT, idxG, idxS, idcC(jj)}.BinaryLearners{1}.Beta;
                        b(jj) = decoders{jj}.Data{idxT, idxG, idxS, idcC(jj)}.BinaryLearners{1}.Bias;
                    end
                    wNorm = vecnorm(w, 2, 1)'; % nD x 1
                    B = w./wNorm'; % nNeurons x nD unit basis vectors
                    bNorm = b./wNorm; % nD x 1 normalized biases
                    origin = -B*((B'*B)\bNorm); % nNeurons x 1 origin of the subspace
                    data{idxT, idxG, idxS, idxC} = spiky.stat.Coords(origin, B);
                catch
                    data{idxT, idxG, idxS, idxC} = spiky.stat.Coords(zeros(nNeurons, 1), ones(nNeurons, nD));
                end
            end
            obj = spiky.stat.Subspaces(decoders{1}.Time, data, decoders{1}.Groups, decoders{1}.GroupIndices);
            obj.Conditions = decoders{idxMax}.Conditions;
        end
    end

    methods
        function obj = Subspaces(time, data, ...
                groups, groupIndices, partitions, conditions, weights, options)
            %SUBSPACES Create a new instance of Subspaces
            arguments
                time double = []
                data = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions (:, 1) = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                weights cell = cell(size(data))
                options.X cell = cell(size(data))
                options.Y cell = cell(size(data, 4), 1)
                options.Type (1, 1) string = "subspaces"
                options.DataTest cell = cell(size(data))
            end
            obj@spiky.stat.Decoder(time, data, options.X, options.Y, ...
                groups, groupIndices, partitions, conditions, weights, Type=options.Type, ...
                DataTest=options.DataTest);
        end

        function obj = mean(obj, options)
            %MEAN Compute the mean of the subspaces across samples
            arguments
                obj spiky.stat.Subspaces
                options.Type string {mustBeMember(options.Type, ["stiefel" "grassmann" "simple"])} = "grassmann"
            end
            data1 = cellfun(@(c) spiky.stat.Coords.meanCoords(c{:}, Type=options.Type), num2cell(obj.Data, 3), ...
                UniformOutput=false);
            % obj = subsref(obj, substruct("()", {':', ':', 1, ':'}));
            sz = size(obj.Data);
            sz(3) = 1;
            obj = obj.resize(sz);
            obj.Data = data1;
        end

        function obj = concat(obj, obj2)
            %CONCAT Concatenate two subspaces
            arguments
                obj spiky.stat.Subspaces
                obj2 spiky.stat.Subspaces
            end
            assert(isequal(size(obj.Data), size(obj2.Data)))
            obj.Data = cellfun(@horzcat, obj.Data, obj2.Data, UniformOutput=false);
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
            %   data: projected data, nT x nEvents x (nBases x nGroups) x nPartitions x nConditions
            arguments
                obj spiky.stat.Subspaces
                data spiky.trig.TrigFr
                idcDim double = 1:obj.Data{1}.NBases
                options.Individual logical = false
            end
            groupedFr = data.group(GroupTime=true); % nT x nGroups of 1 x nEvents x nNeurons
            [nT, nGroups] = size(groupedFr);
            nEvents = width(groupedFr{1});
            [~, ~, nPartitions, nConditions] = size(obj);
            nBases = obj.Data{1}.NBases;
            if height(obj)==1
                idcT = ones(nT, 1);
            elseif height(obj)==nT
                idcT = 1:nT;
            else
                error("The number of time points does not match the Subspaces")
            end
            proj = cell(nT, 1, nGroups, nPartitions, nConditions);
            n = nT*nGroups*nPartitions*nConditions;
            for ii = 1:n
                [idxT, idxG, idxS, idxC] = ind2sub([nT nGroups nPartitions nConditions], ii);
                coords = obj.Data{idcT(idxT), idxG, idxS, idxC};
                v = permute(groupedFr{idxT, idxG}, [3 2 1]); % nNeurons x nEvents
                v = coords.project(v, idcDim, Individual=options.Individual); % nBases x nEvents
                proj{idxT, 1, idxG, idxS, idxC} = permute(v, [3 2 1]); % 1 x nEvents x nBases
            end
            proj = cell2mat(proj); % nT x nEvents x (nBases x nGroups) x nPartitions x nConditions
            t = data.Time;
            data = spiky.trig.TrigFr(0, 1, proj, data.Events, ...
                data.Window, spiky.core.Neuron.create(data.Neuron.Session(1), obj.Groups, nBases), ...
                (1:nPartitions)');
            data.Time = t;
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

        function obj = pca(obj, nDims, options)
            %PCA Perform PCA on the subspaces
            %
            %   obj = PCA(obj, nDims)
            %
            %   obj: Subspaces object with PCA applied
            %   nDims: number of dimensions to keep
            %   Name-value arguments:
            %       Type: whether to perform PCA on the dimensions ("dims") or the bases ("bases") (default: "bases")
            arguments
                obj spiky.stat.Subspaces
                nDims double
                options.Type string {mustBeMember(options.Type, ["dims" "bases"])} = "bases"
            end
            data1 = cellfun(@(x) x.pca(nDims, Type=options.Type), obj.Data, UniformOutput=false);
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
                        V1 = permute(V(ii, :, obj.GroupIndices(jj, :)), [3 2 1]);
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
            %   other: another Subspaces object. If not provided, calculates similarity across
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

        function [h, hMean, hConnect] = plotScatter(obj, sz, plotOps, options)
            arguments
                obj spiky.stat.Subspaces
                sz double = 50
                plotOps.?matlab.graphics.chart.primitive.Scatter
                options.Parent matlab.graphics.axis.Axes = gca
                options.ConnectMean = []
            end
            plotArgs = namedargs2cell(plotOps);
            basisNames = obj.Data{1}.BasisNames;
            data = spiky.utils.cellfun(@(x) x.Data, obj.Data(1, 1, :, 1, 1)); % nDims x nCats x nSamples
            data = permute(data, [3 2 1]); % nSamples x nCats x nDims
            [~, nCats, ~] = size(data);
            cs = lines(nCats);
            holdState = options.Parent.NextPlot;
            h1 = gobjects(nCats, 1);
            for ii = 1:nCats
                if ii>1
                    hold(options.Parent, "on");
                end
                if sz(1)>0
                    h1(ii) = scatter(options.Parent, data(:, ii, 1), data(:, ii, 2), sz(1), cs(ii, :), ...
                        "filled", "DisplayName", string(basisNames(ii)), plotArgs{:});
                end
            end
            if numel(sz)==2
                m = mean(data, 1);
                hMean1 = gobjects(nCats, 1);
                hold(options.Parent, "on");
                for ii = 1:nCats
                    hMean1(ii) = scatter(options.Parent, m(1, ii, 1), m(1, ii, 2), sz(2), cs(ii, :), ...
                        "filled", plotArgs{:});
                    hMean1(ii).Annotation.LegendInformation.IconDisplayStyle = "off";
                end
                if ~isempty(options.ConnectMean)
                    if isnumeric(options.ConnectMean)
                        idcConnect = options.ConnectMean;
                    elseif iscategorical(options.ConnectMean)
                        [~, idcConnect] = ismember(options.ConnectMean, basisNames);
                    else
                        error("ConnectMean must be numeric or categorical")
                    end
                    idcConnect = [idcConnect(:); idcConnect(1)]; % connect in a loop
                    dataConnect = m(1, idcConnect, :);
                    hConnect1 = plot(options.Parent, dataConnect(1, :, 1), dataConnect(1, :, 2), "k");
                    hConnect1.Annotation.LegendInformation.IconDisplayStyle = "off";
                else
                    hConnect1 = gobjects(0, 1);
                end
            else
                hMean1 = gobjects(0, 1);
                hConnect1 = gobjects(0, 1);
            end
            options.Parent.NextPlot = holdState;
            if nargout>0
                h = h1;
            end
            if nargout>1
                hMean = hMean1;
            end
            if nargout>2
                hConnect = hConnect1;
            end
        end
    end
end