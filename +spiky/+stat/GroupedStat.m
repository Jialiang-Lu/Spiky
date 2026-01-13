classdef GroupedStat < spiky.core.EventsTable
    %GROUPEDSTAT Base class representing grouped statistics
    %
    % The first dimension is time and the second dimension is the groups, which can be neurons or
    % events, the third dimension is the samples.

    properties
        Groups (:, 1)
        GroupIndices (:, 1) cell
    end

    properties (Dependent)
        NGroups double
        NSamples double
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
            dimLabelNames = {"Time", ["Groups"; "GroupIndices"]};
        end
    end

    methods
        function obj = GroupedStat(time, data, groups, groupIndices)
            arguments
                time double = []
                data = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices cell = cell(height(groups), 1)
            end
            if isempty(time) && isempty(data) && isempty(groups)
                return
            end
            if width(data) ~= height(groups)
                error("The number of groups must be the same as the number of columns in the data")
            end
            if width(data) ~= height(groupIndices)
                error("The number of group indices must be the same as the number of columns in the data")
            end
            if height(data) ~= numel(time)
                error("The number of time points and values must be the same")
            end
            obj.Time = time;
            obj.Data = data;
            obj.Groups = groups;
            obj.GroupIndices = groupIndices;
        end

        function n = get.NGroups(obj)
            n = numel(obj.Groups);
        end

        function n = get.NSamples(obj)
            n = size(obj.Data, 3);
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

        function h = boxchart(obj, plotOps, options)
            %BOXCHART Plot the accuracy as box charts
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