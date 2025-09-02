classdef Classifier < spiky.stat.GroupedStat
    %CLASSIFIER Class representing an error-correcting output codes (ECOC) model classifier
    
    properties (Dependent)
        IsCrossValidated logical
        Accuracy
        NNeurons double
    end

    methods
        function obj = Classifier(time, data, groups, groupIndices)
            arguments
                time double = []
                data cell = {}
                groups string = ""
                groupIndices cell = {}
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
        end

        function b = get.IsCrossValidated(obj)
            b = ~isempty(obj) && isprop(obj.Data{1}, "Partition");
        end

        function varargout = predict(obj, x, options)
            %PREDICT Predict the class labels for the input data
            %
            %   labels = PREDICT(obj, x)
            %
            %   obj: classifier
            %   x: input data
            %   Name-Value pairs:
            %       BinaryLoss: binary loss function (default: [])
            %       Decoding: decoding method, either "lossweighted" or "lossbased" (default:
            %           "lossweighted")
            %       PosteriorMethod: method for posterior probability estimation, 
            %           either "kl" or "qp" (default: "kl")
            %
            %   labels: predicted class labels

            arguments
                obj spiky.stat.Classifier
                x = []
                options.BinaryLoss = []
                options.Decoding {mustBeMember(options.Decoding, ["lossweighted", "lossbased"])} ...
                    = "lossweighted"
                options.PosteriorMethod {mustBeMember(options.PosteriorMethod, ["kl", "qp"])} = "kl"
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
            events = obj.Data{1}.Y;
            varargout{1} = spiky.trig.Labels(obj.Time, labels, events, obj.Groups);
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
                acc = cell2mat(cellfun(func, obj.Data, UniformOutput=false));
            end
            acc = spiky.stat.Accuracy(obj.Time, acc, obj.Groups, obj.GroupIndices, ...
                spiky.stat.Accuracy.getChance(obj.Data{1}.Y'));
        end

        function acc = getAccuracy(obj, x, y, groupIndices)
            %GETACCURACY Get accuracy of the classifier
            %
            %   acc = GETACCURACY(obj, x, y)
            %
            %   obj: classifier
            %   x: input data
            %   y: target data
            %   groupIndices: group indices
            %
            %   acc: accuracy
            arguments
                obj spiky.stat.Classifier
                x = []
                y = []
                groupIndices = obj.GroupIndices
            end
            if isnumeric(groupIndices) || iscategorical(groupIndices)
                groupIndices = arrayfun(@(x) find(x==groupIndices), unique(groupIndices), ...
                    UniformOutput=false);
            end
            groupIndices = groupIndices(:)';
            if ~isempty(x)
                if isa(x, "spiky.trig.TrigFr")
                    x = permute(x.Data, [3 2 1]);
                end
                x1 = x;
                x = cell(numel(obj.Time), numel(groupIndices));
                for ii = 1:height(x)
                    for jj = 1:width(x)
                        x{ii, jj} = x1(obj.GroupIndices{jj}, :, ii);
                    end
                end
                clear x1;
            else
                x = cellfun(@(c) c.X', obj.Data, UniformOutput=false);
            end
            if isempty(y)
                y = obj.Data{1}.Y';
            end
            if ~obj.IsCrossValidated
                func = @(c, x) 1-c.loss(x, y, ObservationsIn="columns");
                acc = cellfun(func, obj.Data, x);
            else
                func = @(c, x) permute(cell2mat(cellfun(@(c1) 1-c1.loss(x, y, ObservationsIn="columns"), ...
                    c.Trained, UniformOutput=false)), [3 2 1]);
                acc = cell2mat(cellfun(func, obj.Data, x, UniformOutput=false));
            end
            acc = spiky.stat.Accuracy(obj.Time, acc, obj.Groups, groupIndices', ...
                spiky.stat.Accuracy.getChance(y));
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