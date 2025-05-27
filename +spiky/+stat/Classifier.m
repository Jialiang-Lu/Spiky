classdef Classifier < spiky.stat.GroupedStat
    %CLASSIFIER Class representing an error-correcting output codes (ECOC) model classifier
    
    properties (Dependent)
        IsCrossValidated logical
        Accuracy double
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

        function acc = get.Accuracy(obj)
            if ~obj.IsCrossValidated
                func = @(c) 1-c.loss(c.X, c.Y);
                acc = cellfun(func, obj.Data);
            else
                func = @(c) 1-c.kfoldLoss(Mode="individual");
                acc = cellfun(func, obj.Data, UniformOutput=false);
            end
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
                x
                y
                groupIndices
            end
            if isa(x, "spiky.trig.TrigFr")
                x = permute(x.Data, [3 2 1]);
            end
            if isnumeric(groupIndices) || iscategorical(groupIndices)
                groupIndices = arrayfun(@(x) find(x==groupIndices), unique(groupIndices), ...
                    UniformOutput=false);
            end
            groupIndices = groupIndices(:)';
            x = cellfun(@(idc) x(idc, :, :), groupIndices, UniformOutput=false);
            if ~obj.IsCrossValidated
                func = @(c, x) 1-c.loss(x, y, ObservationsIn="columns");
                acc = cellfun(func, obj.Data, x);
            else
                func = @(c, x) cell2mat(cellfun(@(c1) 1-c1.loss(x, y, ObservationsIn="columns"), ...
                    c.Trained, UniformOutput=false));
                acc = cellfun(func, obj.Data, x, UniformOutput=false);
            end
        end

        function h = plotBox(obj, acc, plotOps)
            %PLOTBOX Plot box plot of classifier accuracy
            arguments
                obj spiky.stat.Classifier
                acc = []
                plotOps.?matlab.graphics.chart.primitive.BoxChart
            end

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
            if nargin>0
                h = h1;
            end
        end
    end
end