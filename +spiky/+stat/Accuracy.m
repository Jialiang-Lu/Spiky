classdef Accuracy < spiky.stat.GroupedStat
    %ACCURACY Class representing the accuracy of a classifier
    %
    %   First dimension is time, second dimension is groups (e.g., brain regions), third dimension
    %   is cross-validation folds, fourth dimension is conditions for testing if any, fifth
    %   dimension is conditions for training if any.

    properties
        Chance double % Chance level
        TestConditions categorical % Conditions for testing
        TrainConditions categorical % Conditions for training
    end

    properties (Dependent)
        NFold double
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the EventsTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Groups,GroupIndices" "" "TestConditions,Chance" "TrainConditions"];
        end

        function chance = getChance(data)
            %GETCHANCE Get the chance level for the data
            %
            %   chance: chance level
            data = data(~ismissing(data));
            data = data(:);
            b = groupcounts(data);
            chance = max(b)./sum(b);
        end

        function h = boxcharts(objs, plotOps, options)
            %BOXCHARTS Plot multiple Accuracy objects as box charts
            %
            %   h = BOXCHARTS(objs, plotOps, options)
            %
            %   objs: Accuracy objects
            %   plotOps: options passed to boxchart()
            %   options: additional options for the plot
            %
            %   h: handle to the boxchart
            arguments (Repeating)
                objs spiky.stat.Accuracy
            end
            arguments
                plotOps.?matlab.graphics.chart.primitive.BoxChart
                options.Parent matlab.graphics.axis.Axes = gca
                options.ClassLabels string = compose("Class %d", 1:numel(objs))'
                options.PlotChance logical = true
            end
            objs = objs(:);
            plotArgs = namedargs2cell(plotOps);
            options.ClassLabels = categorical(options.ClassLabels, options.ClassLabels);
            nFolds = cellfun(@(acc) size(acc, 3), objs);
            nGroups = width(objs{1});
            data = spiky.utils.cellfun(@(x) permute(x.Data(1, :, :)*100, [3 2 1]), objs, Dim=1);
            g = repmat(categorical(objs{1}.Groups'), height(data), 1);
            c = repmat(repelem(options.ClassLabels, nFolds), 1, nGroups);
            h1 = boxchart(options.Parent, g(:), data(:), plotArgs{:}, GroupByColor=c(:));
            ylabel("Accuracy (%)");
            legend(options.ClassLabels);
            if ~isempty(objs{1}.Chance) && options.PlotChance
                yline(objs{1}.Chance*100, "-", "Chance");
            end
            if nargout>0
                h = h1;
            end
        end
    end
    
    methods
        function obj = Accuracy(time, data, groups, groupIndices, chance, testConditions, trainConditions)
            arguments
                time double = []
                data double = []
                groups (:, 1) = []
                groupIndices cell = cell(height(groups), 1)
                chance double = NaN
                testConditions categorical = categorical(zeros(size(data, 4), 1))
                trainConditions categorical = categorical(zeros(size(data, 5), 1))
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
            obj.Chance = chance;
            obj.TestConditions = testConditions;
            obj.TrainConditions = trainConditions;
        end

        function n = get.NFold(obj)
            % Get the number of folds
            if isempty(obj.Data)
                n = 0;
            else
                n = size(obj.Data, 3);
            end
        end
        
        function [h, hError] = plot(obj, lineSpec, plotOps, options)
            %PLOT Plot the accuracy
            %
            %   h = PLOT(obj, lineSpec, ...)
            %
            %   obj: Accuracy object
            %   lineSpec: line specification
            %   Name-value arguments:
            %       Color, LineWidth, ...: options passed to plot() 
            %       Chance: chance level to plot
            %       FaceAlpha: face alpha for the error bars
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot
            %   hError: handle to the error bars
            arguments
                obj spiky.stat.Accuracy
                lineSpec string = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Smooth double = 0
                options.Chance double = []
                options.FaceAlpha double = .3
                options.Parent matlab.graphics.axis.Axes = gca
            end
            
            plotArgs = namedargs2cell(plotOps);
            if isempty(options.Chance) && ~isempty(obj.Chance)
                options.Chance = obj.Chance;
            end
            if obj.NFold==1
                options.FaceAlpha = 0;
            end
            m = mean(obj.Data, 3)*100;
            if options.Smooth > 0
                res = obj.Time(2)-obj.Time(1);
                kSize = 2*ceil(2.5*options.Smooth/res)+1;
                kernel = fspecial("gaussian", [kSize 1], options.Smooth/res);
                m = imfilter(m, kernel, "replicate");
            end
            if options.FaceAlpha==0
                h1 = plot(obj.Time, m, lineSpec, plotArgs{:}, ...
                    Parent=options.Parent);
                hError1 = gobjects(0, 1);
            else
                se = std(obj.Data, 0, 3)./sqrt(obj.NFold)*100;
                if options.Smooth > 0
                    se = imfilter(se, kernel, "replicate");
                end
                [h1, hError1] = spiky.plot.plotError(obj.Time, m, se, lineSpec, plotArgs{:});
            end
            if obj.NGroups>1
                legend(options.Parent, obj.Groups);
            end
            box off
            xlim(obj.Time([1 end]));
            l = xline(0, "g", LineWidth=1);
            l.Annotation.LegendInformation.IconDisplayStyle = "off";
            if ~isempty(options.Chance)
                l2 = yline(options.Chance*100, "-", "Chance", LineWidth=1);
                l2.Annotation.LegendInformation.IconDisplayStyle = "off";
            end
            xlabel("Time (s)");
            ylabel("Accuracy (%)");
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end

        function h = boxchart(obj, plotOps, options)
            %BOXCHART Plot the accuracy as box charts
            %
            %   h = BOXCHART(obj, plotOps, options)
            %
            %   obj: Accuracy object
            %   plotOps: options passed to boxchart()
            %   Name-Value pairs:
            %       Parent: parent axes for the plot
            %
            %   h: handle to the boxchart
            arguments
                obj spiky.stat.Accuracy
                plotOps.?matlab.graphics.chart.primitive.BoxChart
                options.Parent matlab.graphics.axis.Axes = gca
                options.PlotChance logical = true
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = boxchart@spiky.stat.GroupedStat(obj, plotArgs{:}, Parent=options.Parent);
            h1.YData = h1.YData*100;
            if ~isempty(obj.Chance) && options.PlotChance
                l2 = yline(obj.Chance*100, "-", "Chance", LineWidth=1);
                l2.Annotation.LegendInformation.IconDisplayStyle = "off";
            end
            ylabel("Accuracy (%)");
            if nargout>0
                h = h1;
            end
        end
    end
end