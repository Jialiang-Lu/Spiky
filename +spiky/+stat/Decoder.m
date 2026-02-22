classdef Decoder < spiky.stat.GroupedStat

    properties
        XTrain
        XTest
        YTrain
        YTest
    end

    properties (Dependent)
        Type (1, 1) string
    end

    properties (Hidden)
        Type_ (1, 1) string
    end

    methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = ["Data" "XTrain" "XTest" "YTrain" "YTest"]';
        end

        function mdls = buildDecoder(obj, name, labels, options)
            arguments
                obj spiky.trig.TrigFr
                name (1, 1) categorical
                labels (:, 1) categorical
                options.Type (1, 1) string = "mean"
                options.IdcEvents = []
                options.SubSet = []
                options.KFold (1, 1) double = 5
                options.Holdout (1, 1) double = 0.2
                options.Center logical = false
            end
            %% Preprocess data
            idcEvents = options.IdcEvents;
            if islogical(idcEvents)
                idcEvents = find(idcEvents);
            end
            if isempty(idcEvents)
                idcEvents = 1:width(obj);
            end
            obj = subsref(obj, substruct("()", {':', idcEvents, ':'}));
            if numel(labels)>=width(obj)
                labels = labels(idcEvents);
            end
            if ~isempty(options.SubSet)
                idcEvents = ismember(labels, options.SubSet);
                obj = subsref(obj, substruct("()", {':', idcEvents, ':'}));
                labels = labels(idcEvents);
            end
            nT = height(obj);
            nEvents = width(obj);
            cats = categories(labels, OutputType="categorical");
            nCats = numel(cats);
            if options.Holdout==1/options.KFold
                cv = cvpartition(labels, KFold=options.KFold);
                testIdc = cv.test("all")';
            else
                cv = cvpartition(labels, Holdout=options.Holdout);
                testIdc = false(options.KFold, nEvents);
                for ii = 1:options.KFold
                    testIdc(ii, :) = cv.test;
                    cv = repartition(cv);
                end
            end
            nPartitions = height(testIdc);
            [groupedFr, groupedFrTest] = obj.group(GroupTime=true, Permute=[3 2 1], Partition=testIdc);
            dataTrain = groupedFr.Data; % nT x nGroups x nPartitions cell of nNeurons x nTrials
            dataTest = groupedFrTest.Data;
            labelTrain = cell(size(dataTrain));
            labelTest = cell(size(dataTest));
            nGroups = width(groupedFr);
            mdls = cell(nT, nGroups, nPartitions);
            sz = size(mdls);
            n = numel(mdls);
            pb = spiky.plot.ProgressBar(n, "Building decoders "+string(name), Parallel=1);
            parfor ii = 1:n
                [idxT, idxG, idxP] = ind2sub(sz, ii);
                X = dataTrain{ii}; % nNeurons x nTrials
                y = labels(~testIdc(idxP, :)); % nTrials x 1
                labelTrain{ii} = y;
                labelTest{ii} = labels(testIdc(idxP, :));
                switch options.Type
                    case "mean"
                        mu = mean(X, 2); % nNeurons x 1 overall mean
                        Xc = X-mu; % nNeurons x nTrials centered data
                        m = groupsummary(Xc', y, "mean")';
                            % nCats x nNeurons mean response for each category
                        mdls{ii} = spiky.stat.Coords(mu, m, 1:height(X), cats);
                    otherwise
                        error("Unsupported decoder type: "+options.Type)
                end
                pb.step
            end
            mdls = spiky.stat.Decoder(obj.Time, mdls, dataTrain, dataTest, labelTrain, labelTest, ...
                groupedFr.Groups, groupedFr.GroupIndices, ...
                {testIdc}, name, Type=options.Type);
        end

        function stat = varExplained(mdl, X, y, options)
            arguments
                mdl spiky.stat.Coords
                X double
                y categorical
                options.Type string {mustBeMember(options.Type, ["trace", "max", "pillai", "wilks"])} = "trace"
            end
            switch options.Type
                case "trace"
                    [isValid, idcY] = ismember(y, mdl.BasisNames);
                    idcY = idcY(isValid);
                    X = X(:, isValid);
                    y = y(isValid);
                    mu = mean(X, 2); % nNeurons x 1 overall mean
                    Xc = X-mu; % nNeurons x nTrials centered data
                    totalSSE = sum(Xc(:).^2, "all", "omitmissing"); % total sum of squares
                    m = mdl.Bases(:, idcY); % nNeurons x nTrials mean response from training data
                    resSSE = sum((X-mdl.Origin-m).^2, "all", "omitmissing"); 
                        % residual sum of squares
                    stat = 1-resSSE/totalSSE;
            end
        end
    end

    methods
        function obj = Decoder(time, data, xTrain, xTest, yTrain, yTest, ...
                groups, groupIndices, partitions, conditions, options)
            arguments
                time double = []
                data = []
                xTrain = []
                xTest = []
                yTrain = []
                yTest = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions (:, 1) = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                options.Type (1, 1) string = "mean"
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices, partitions, conditions)
            assert(isequal(size(data), size(xTrain), size(yTrain), size(xTest), size(yTest)), ...
                "Data, XTrain, YTrain, XTest, and YTest must have the same size.")
            obj.XTrain = xTrain;
            obj.XTest = xTest;
            obj.YTrain = yTrain;
            obj.YTest = yTest;
            obj.Type_ = options.Type;
        end

        function type = get.Type(obj)
            type = obj.Type_;
        end

        function stats = getStats(obj, options)
            arguments
                obj spiky.stat.Decoder
                options.Metric (1, 1) string {mustBeMember(options.Metric, ["varExplained"])} = "varExplained"
                options.VarType string {mustBeMember(options.VarType, ["trace", "max", "pillai", "wilks"])} = "trace"
            end
            chance = NaN;
            switch options.Metric
                case "varExplained"
                    assert(obj.Type=="mean")
                    chance = 0;
            end
            nT = height(obj);
            nGroups = width(obj);
            nPartitions = size(obj.Data, 3);
            nConditions = size(obj.Data, 4);
            stats = cell(nT, nGroups, nPartitions, 1, nConditions);
            mdls = obj.Data; % nT x nGroups x nPartitions x nConditions cell of decoder models
            xTest = obj.XTest; % nT x nGroups x nPartitions x nConditions cell of test data
            yTest = obj.YTest; % nT x nGroups x nPartitions x nConditions cell of test labels
            n = numel(mdls);
            parfor ii = 1:n
                [idxT, idxG, idxP, idxC] = ind2sub(size(mdls), ii);
                % data to compare to
                X = xTest{ii}; % nNeurons x nTrials
                y = yTest{ii}; % nTrials x 1
                stat1 = NaN(1, 1, 1, nConditions);
                for jj = 1:nConditions
                    % model to compare from
                    mdl = mdls{idxT, idxG, idxP, jj};
                    switch options.Metric
                        case "varExplained"
                            stat1(jj) = spiky.stat.Decoder.varExplained(mdl, X, y, Type=options.VarType);
                    end
                end
                stats{ii} = stat1;
            end
            stats = cell2mat(stats); % nT x nGroups x nPartitions x nConditions x nConditions
            stats = spiky.stat.GroupedStat(obj.Time, stats, obj.Groups, obj.GroupIndices, ...
                obj.Partitions, obj.Conditions);
            stats.Chance = chance;
        end
    end
end