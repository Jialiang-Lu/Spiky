classdef GroupedStat < spiky.core.EventsTable
    %GROUPEDSTAT Base class representing grouped statistics
    %
    % The first dimension is time
    % The second dimension is the groups, which can be neurons or events
    % The third dimension is the partions or samples
    % The fourth and higher dimensions are conditions.

    properties
        Groups (:, 1) % categorical names or spiky.core.Neuron array
        GroupIndices (:, :) logical % logical indices for each group, nGroups x nUnits
        Conditions (:, 1) categorical % condition labels for each condition, nConditions x 1
        Partitions (:, 1) cell % cvpartition for each condition, nConditions x 1
        Chance double % chance level for the statistic
    end

    properties (Dependent)
        NGroups double
        NPartitions double
        NConditions double
    end

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {"Time", ["Groups"; "GroupIndices"], string.empty, ...
                ["Conditions"; "Partitions"]};
        end
    end

    methods
        function obj = GroupedStat(time, data, groups, groupIndices, partitions, conditions)
            arguments
                time double = []
                data = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions (:, 1) = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
            end
            if isempty(time) && isempty(data) && isempty(groups)
                return
            end
            assert(height(data)==numel(time), ...
                "The number of time points and values must be the same")
            assert(width(data)==height(groups), ...
                "The number of groups must be the same as the number of columns in the data")
            assert(width(data)==height(groupIndices), ...
                "The number of group indices must be the same as the number of columns in the data")
            assert(size(data, 4)==height(partitions), ...
                "The number of partitions must be the same as the number of conditions")
            assert(size(data, 4)==height(conditions), ...
                "The number of conditions must be the same as the number of conditions")
            if iscell(groupIndices)
                nNeurons = max(cellfun(@max, groupIndices));
                groupIndicesMat = false(height(groups), nNeurons);
                for ii = 1:length(groupIndices)
                    groupIndicesMat(ii, groupIndices(ii, :)) = true;
                end
                groupIndices = groupIndicesMat;
            end
            obj.Time = time;
            obj.Data = data;
            obj.Groups = groups;
            obj.GroupIndices = groupIndices;
            obj.Partitions = partitions;
            obj.Conditions = conditions;
        end

        function n = get.NGroups(obj)
            n = width(obj.Data);
        end

        function n = get.NPartitions(obj)
            n = size(obj.Data, 3);
        end

        function n = get.NConditions(obj)
            n = size(obj.Data, 4);
        end

        function obj = filter(obj, filter, filterArg)
            %FILTER Filter the data
            %
            %   obj = FILTER(obj, filter)
            %
            %   obj: grouped statistics
            %   filter: filter
            %
            %   obj: filtered grouped statistics
            arguments
                obj spiky.stat.GroupedStat
                filter
                filterArg = []
            end
            if ischar(filter) || isstring(filter)
                if isempty(filterArg)
                    error("The filter argument must be provided if the filter is a string")
                end
                filter = @(x) ismember(x.(filter), filterArg);
            end
            [~, idc] = feval(filter, obj.Groups);
            obj = obj(:, idc, :);
        end

        function [h, hError] = plot(obj, lineSpec, plotOps, options)
            %PLOT Plot the GroupedStat
            %
            %   h = PLOT(obj, lineSpec, ...)
            %
            %   obj: GroupedStat object
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
                obj spiky.stat.GroupedStat
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
            if obj.NPartitions==1
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
                se = std(obj.Data, 0, 3)./sqrt(obj.NPartitions)*100;
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
            if ~isempty(options.Chance) && ~isnan(options.Chance)
                yline(options.Chance*100, "-", "Chance", LineWidth=1);
            end
            xlabel("Time (s)");
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end

        function h = boxchart(obj, plotOps, options)
            %BOXCHART Plot the data as box charts
            %
            %   h = BOXCHART(obj, plotOps, options)
            %
            %   obj: GroupedStat object
            %   plotOps: options passed to boxchart()
            %   Name-Value pairs:
            %       Parent: parent axes for the plot
            %
            %   h: handle to the boxchart
            arguments
                obj spiky.stat.GroupedStat
                plotOps.?matlab.graphics.chart.primitive.BoxChart
                options.Parent matlab.graphics.axis.Axes = gca
            end
            plotArgs = namedargs2cell(plotOps);
            data = obj.Data(1, :, :);
            g = repmat(categorical(obj.Groups'), 1, 1, size(data, 3));
            h1 = boxchart(options.Parent, g(:), data(:), plotArgs{:});
            box off
            if nargout>0
                h = h1;
            end
        end
    end
end