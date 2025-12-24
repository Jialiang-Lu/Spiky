classdef Classifier < spiky.stat.GroupedStat
    %CLASSIFIER Class representing an error-correcting output codes (ECOC) model classifier
    %
    %   First dimension is time, second dimension is brain regions, third dimension is conditions
    %   Each element in Data is a CompactClassificationECOC object or 
    %   ClassificationPartitionedLinearECOC object

    properties
        Conditions categorical % Conditions for classification
    end
    
    properties (Dependent)
        IsCrossValidated logical
        Accuracy
        NNeurons double
        Beta
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the EventsTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Groups,GroupIndices" "Conditions"];
        end

        function d = dist(obj1, obj2, metric, param)
            %DIST Compute the distance between the beta coefficients of two classifiers using the
            %   specified metric
            %
            %   a = dist(obj1, obj2, metric, param)
            %
            %   obj1: first classifier
            %   obj2: second classifier
            %   metric: distance metric, refer to pdist2() for options
            %   param: additional parameter for the distance metric
            %
            %   d: distance between the beta coefficients of the two classifiers
            arguments
                obj1 spiky.stat.Classifier
                obj2 spiky.stat.Classifier
                metric = "cosine"
                param = []
            end
            assert(isequal(obj1.Time, obj2.Time), "The time points must be the same");
            assert(isequal(obj1.Groups, obj2.Groups), "The groups must be the same");
            assert(isequal(obj1.GroupIndices, obj2.GroupIndices), "The group indices must be the same");
            beta1 = obj1.Beta;
            beta2 = obj2.Beta;
            if isempty(param)
                func = @(b1, b2) permute(diag(pdist2(b1', b2', metric)), [2 3 1]);
            else
                func = @(b1, b2) permute(diag(pdist2(b1', b2', metric, param)), [2 3 1]);
            end
            d = spiky.utils.cellfun(func, beta1.Data, beta2.Data);
            d = spiky.stat.GroupedStat(obj1.Time, d, obj1.Groups, obj1.GroupIndices);
        end
    end

    methods
        function obj = Classifier(time, data, groups, groupIndices, conditions)
            arguments
                time double = []
                data cell = {}
                groups string = ""
                groupIndices cell = {}
                conditions categorical = categorical(zeros(size(data, 3), 1))
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
            obj.Conditions = conditions;
        end

        function b = get.IsCrossValidated(obj)
            b = ~isempty(obj) && isprop(obj.Data{1}, "Partition");
        end

        function varargout = predict(obj, x, options, options2)
            %PREDICT Predict the class labels for the input data
            %
            %   labels = PREDICT(obj, x, ...)
            %
            %   obj: classifier
            %   x: input data
            %   Name-Value pairs:
            %       BinaryLoss: binary loss function (default: [])
            %       Decoding: decoding method, either "lossweighted" or "lossbased" (default:
            %           "lossweighted")
            %       PosteriorMethod: method for posterior probability estimation, 
            %           either "kl" or "qp" (default: "kl")
            %       Aggregate: if true, aggregate the predictions across time points and regions
            %           (default: false)
            %
            %   labels: predicted class labels

            arguments
                obj spiky.stat.Classifier
                x = []
                options.BinaryLoss = []
                options.Decoding {mustBeMember(options.Decoding, ["lossweighted", "lossbased"])} ...
                    = "lossweighted"
                options.PosteriorMethod {mustBeMember(options.PosteriorMethod, ["kl", "qp"])} = "kl"
                options2.Aggregate logical = false
            end

            if isempty(options.BinaryLoss)
                options = rmfield(options, "BinaryLoss");
            end
            optionsCell = namedargs2cell(options);
            if ~isempty(x) && ~obj.IsCrossValidated
                if isa(x, "spiky.trig.TrigFr")
                    x = permute(x.Data, [3 2 1]);
                end
                assert(height(x)==obj.NNeurons, ...
                    "Input data must have the same number of neurons as the classifier (%d)", ...
                    obj.NNeurons);
            elseif ~obj.IsCrossValidated
                error("Input data is required for prediction when not cross-validated");
            end
            nOuts = nargout;
            outs = repmat(cell(1, nOuts), obj.Length, obj.NGroups);
            pb = spiky.plot.ProgressBar(obj.Length*obj.NGroups, ...
                "Predicting class labels", Parallel=true);
            parfor ii = 1:obj.Length*obj.NGroups
                [~, idxGroup] = ind2sub([obj.Length, obj.NGroups], ii);
                if obj.IsCrossValidated
                    [outs{ii}{1:nOuts}] = obj.Data{ii}.kfoldPredict(optionsCell{:});
                else
                    [outs{ii}{1:nOuts}] = obj.Data{ii}.predict(x(obj.GroupIndices{idxGroup}), ...
                        optionsCell{:});
                end
                pb.step;
            end
            varargout = arrayfun(@(x) cellfun(@(c) c{x}, outs, UniformOutput=false), ...
                1:nargout, UniformOutput=false);
            labels = varargout{1};
            labels = horzcat(labels{:});
            % nEvents = numel(obj.Data{1}.Y);
            labels = reshape(labels, [], obj.Length, obj.NGroups);
            labels = permute(labels, [2 1 3]);
            labels = removecats(labels);
            events = obj.Data{1}.Y;
            varargout{1} = spiky.trig.Trig(obj.Time, labels, events, obj.Groups);
            if options2.Aggregate
                % Aggregate predictions across time points and regions
                labelsAgg = mode(labels, [1 3]);
                varargout{1} = spiky.trig.Trig(0, labelsAgg, events);
            end
        end

        function n = get.NNeurons(obj)
            %NNEURONS Get number of neurons in the classifier
            %
            %   n = NNEURONS(obj)
            %
            %   obj: classifier
            %
            %   n: number of neurons
            n = sum(cellfun(@numel, obj.GroupIndices));
        end

        function acc = get.Accuracy(obj)
            if ~obj.IsCrossValidated
                func = @(c) 1-c.loss(c.X, c.Y);
                acc = cellfun(func, obj.Data);
            else
                func = @(c) permute(1-c.kfoldLoss(Mode="individual"), [3 2 1]);
                acc = spiky.utils.cellfun(func, obj.Data);
            end
            acc = spiky.stat.Accuracy(obj.Time, acc, obj.Groups, obj.GroupIndices, ...
                spiky.stat.Accuracy.getChance(obj.Data{1}.Y'));
        end

        function beta = get.Beta(obj)
            func1 = @(c) spiky.utils.cellfun(@(c1) c1.Beta, c.BinaryLearners, Dim=2); % nDims x nCodes
            if obj.IsCrossValidated
                func2 = @(c) spiky.utils.cellfun(func1, c.Trained, Dim=3); % nDims x nCodes x nFolds
                beta = cellfun(func2, obj.Data, UniformOutput=false);
            else
                beta = cellfun(func1, obj.Data, UniformOutput=false);
            end
            beta = spiky.stat.GroupedStat(obj.Time, beta, obj.Groups, obj.GroupIndices);
        end

        function acc = getAccuracy(obj, x, y, eventsIndices, groupIndices, options)
            %GETACCURACY Get accuracy of the classifier
            %
            %   acc = GETACCURACY(obj, x, y)
            %
            %   obj: classifier
            %   x: input data, either nNeurons x nEvents matrix, or spiky.trig.TrigFr object, if
            %       empty use the data used for training
            %   y: target data
            %   eventsIndices: indices of events to use for accuracy calculation, if empty use all
            %       events
            %   groupIndices: group indices
            %   Name-Value pairs:
            %       Balance: if true, balance the number of events in each class
            %       Subset: subset of y to use for accuracy calculation
            %
            %   acc: accuracy, nT x nGroups x nFolds spiky.stat.Accuracy object
            arguments
                obj spiky.stat.Classifier
                x = []
                y = []
                eventsIndices = []
                groupIndices = obj.GroupIndices
                options.Balance string {mustBeMember(options.Balance, ["none", "min", "max"])} = "none"
                options.Subset = []
            end
            if isnumeric(groupIndices) || iscategorical(groupIndices)
                groupIndices = arrayfun(@(x) find(x==groupIndices), unique(groupIndices), ...
                    UniformOutput=false);
            end
            groupIndices = groupIndices(:)';
            if ~isempty(eventsIndices) && ~isempty(y)
                y = y(eventsIndices);
            end
            if ~isempty(x)
                if isa(x, "spiky.trig.TrigFr")
                    t = x.Time;
                    nT = numel(t);
                    x = permute(x.Data, [3 2 1]);
                else
                    t = 0;
                    nT = 1;
                end
                x1 = x;
                if ~isempty(eventsIndices)
                    x1 = x(:, eventsIndices, :);
                end
                x = cell(nT, numel(groupIndices));
                for ii = 1:nT
                    for jj = 1:width(x)
                        x{ii, jj} = x1(obj.GroupIndices{jj}, :, ii);
                    end
                end
                clear x1
            else
                t = obj.Time;
                nT = numel(t);
            end
            if isempty(y) || isempty(x)
                assert(isempty(x) && isempty(y), ...
                    "Either both x and y should be provided, or neither.");
                if options.Balance=="none"
                    acc = obj.Accuracy;
                    return
                end
                y = obj.Data{1}.Y';
                x = cellfun(@(c) c.X', obj.Data, UniformOutput=false);
                % if obj.IsCrossValidated
                %     nFolds = obj.Data{1}.Partition.NumTestSets;
                %     acc = zeros(obj.Length, obj.NGroups, nFolds);
                %     for ii = 1:obj.Length
                %         for jj = 1:obj.NGroups
                %             for kk = 1:nFolds
                %                 idcFold = obj.Data{ii, jj}.Partition.test(kk);
                %                 x1 = x{ii, jj}(:, idcFold);
                %                 y1 = y(idcFold);
                %                 [y1, idcY] = spiky.utils.balance(y1, Count=options.Balance);
                %                 x1 = x1(:, idcY);
                %                 acc(ii, jj, kk) = sum(obj.Data{ii, jj}.Trained{kk}.predict(x1, ...
                %                     ObservationsIn="columns")'==y1)./numel(y1);
                %             end
                %         end
                %     end
                %     acc = spiky.stat.Accuracy(obj.Time, acc, obj.Groups, groupIndices', ...
                %         1/numel(obj.Data{1}.ClassNames));
                %     return
                % end
            end
            if ~isempty(options.Subset)
                idcValid = ismember(y, options.Subset);
                y = y(idcValid);
                x = cellfun(@(c) c(:, idcValid), x, UniformOutput=false);
            end
            classifiers = repmat(obj.Data, nT/obj.Length, 1);
            y = y(:);
            if options.Balance~="none"
                [y, idcBalance] = spiky.utils.balance(y, Count=options.Balance);
                x = cellfun(@(c) c(:, idcBalance), x, UniformOutput=false);
            end
            if ~obj.IsCrossValidated
                func = @(c, x) 1-c.loss(x, y, ObservationsIn="columns");
                acc = cellfun(func, classifiers, x);
            else
                % func = @(c, x) permute(spiky.utils.cellfun(@(c1) ...
                %     1-c1.loss(x, y, ObservationsIn="columns"), c.Trained), [3 2 1]);
                % acc = spiky.utils.cellfun(func, classifiers, x);
                acc = cell(size(classifiers));
                parfor ii = 1:numel(classifiers)
                    c = classifiers{ii};
                    x1 = x{ii};
                    nFolds = c.Partition.NumTestSets;
                    idcTest = c.Partition.test("all");
                    if options.Balance~="none"
                        idcTest = idcTest(idcBalance, :);
                    end
                    acc1 = zeros(1, 1, nFolds);
                    for kk = 1:nFolds
                        idcFold = idcTest(:, kk);
                        xFold = x1(:, idcFold);
                        yFold = y(idcFold)';
                        acc1(kk) = sum(c.Trained{kk}.predict(xFold, ...
                            ObservationsIn="columns")'==yFold)./numel(yFold);
                    end
                    acc{ii} = acc1;
                end
                acc = cell2mat(acc);
            end
            acc = spiky.stat.Accuracy(t, acc, obj.Groups, groupIndices', ...
                spiky.stat.Accuracy.getChance(y));
        end

        function ss = getSubspaces(obj, nDims, options)
            %GETSUBSPACES Get the subspaces spanned by the beta coefficients of the classifier
            %   ss = GETSUBSPACES(obj, nDims)
            %
            %   obj: classifier
            %   nDims: number of dimensions for the subspace (max: number of classes - 1)
            %   Name-Value arguments:
            %       Window: time window to consider (default: full time range)
            %       TimeDependent: if false, pool the beta coefficients across time points before
            %           computing the subspace (default: true)
            %       FoldDependent: if false, pool the beta coefficients across folds before
            %           computing the subspace (default: true)
            arguments
                obj spiky.stat.Classifier
                nDims (1, 1) double = 0
                options.Window (1, 2) double = obj.Time([1 end])'
                options.TimeDependent logical = true
                options.FoldDependent logical = true
                options.Subtract spiky.stat.Classifier = spiky.stat.Classifier
                options.SubtractDim double = 20
            end
            if ~obj.IsCrossValidated
                error("Not implemented yet");
            end
            if nDims==0
                nDims = numel(obj.Data{1}.Trained{1}.BinaryLearners)-1;
            end
            assert(nDims<=numel(obj.Data{1}.Trained{1}.BinaryLearners)-1, ...
                "nDims must be less than or equal to the number of classes minus 1");
            idcInWindow = obj.Time>=options.Window(1) & obj.Time<=options.Window(2);
            obj.Data = obj.Data(idcInWindow, :);
            obj.Time = obj.Time(idcInWindow);
            nFolds = obj.Data{1}.Partition.NumTestSets;
            func1 = @(c) spiky.utils.cellfun(@(x) num2cell(x(:, 1:end-1, :)-x(:, end, :), [1 2]), c);
            betas = func1(obj.Beta.Data); % nT x nGroups x nFolds cell array of nDims x nCodes-1
            if ~isempty(options.Subtract)
                idcInWindowSub = options.Subtract.Time>=options.Window(1) & ...
                    options.Subtract.Time<=options.Window(2);
                options.Subtract.Data = options.Subtract.Data(idcInWindowSub, :);
                options.Subtract.Time = options.Subtract.Time(idcInWindowSub);
                betasSub = func1(options.Subtract.Beta.Data);
                hasSub = true;
            else
                hasSub = false;
            end
            if ~options.TimeDependent
                func2 = @(c) cellfun(@(b) horzcat(b{:}), num2cell(c, 1), UniformOutput=false);
                betas = func2(betas);
                if hasSub
                    betasSub = func2(betasSub);
                end
                t = 0;
            else
                t = obj.Time;
            end
            if ~options.FoldDependent
                func3 = @(c) cellfun(@(b) horzcat(b{:}), num2cell(c, 3), UniformOutput=false);
                betas = func3(betas);
                if hasSub
                    betasSub = func3(betasSub);
                end
            end
            if hasSub
                options.SubtractDim = min(options.SubtractDim, width(betas{1}));
                for ii = 1:numel(betas)
                    subDim = min(options.SubtractDim, height(betas{ii}));
                    [U, ~, ~] = svd(betas{ii});
                    U = U(:, 1:subDim);
                    [USub, ~, ~] = svd(betasSub{ii});
                    USub = USub(:, 1:subDim);
                    betas{ii} = U-(USub*USub')*U;
                end
            end
            ss = cell(size(betas));
            for ii = 1:numel(betas)
                [~, idxGroup, ~] = ind2sub(size(betas), ii);
                c = betas{ii};
                [U, ~, ~] = svd(c);
                ss{ii} = spiky.stat.Coords(zeros(size(c, 1), 1), U(:, 1:nDims), ...
                    obj.GroupIndices{idxGroup}, (1:nDims)');
            end
            ss = spiky.stat.Subspaces(t, ss, obj.Groups, obj.GroupIndices);
        end

        function h = plotBox(obj, acc, plotOps)
            %PLOTBOX Plot box plot of classifier accuracy
            arguments
                obj spiky.stat.Classifier
                acc = []
                plotOps.?matlab.graphics.chart.primitive.BoxChart
            end

            pChance = 1./numel(obj.Data{1}.ClassNames);
            pBest = max(obj.Data{1}.Prior);
            if isempty(acc)
                acc = obj.Accuracy;
            end
            if iscell(acc)
                acc = horzcat(acc{1, :});
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = boxchart(acc, plotArgs{:});
            yl = ylim;
            ylim([0 yl(2)]);
            ylabel("Accuracy");
            xticklabels(obj.Groups);
            yline(pChance, "-", "Chance", LineWidth=1, DisplayName="Chance");
            yline(pBest, "-", "Best", LineWidth=1, DisplayName="Best");
            if nargin>0
                h = h1;
            end
        end
    end
end