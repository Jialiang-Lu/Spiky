classdef (Abstract) GroupedStat < spiky.core.TimeTable
    % GroupedStat Abstract class representing grouped statistics
    %
    % The first dimension is time and the second dimension is the groups, which can be neurons or
    % events, the third dimension is the samples.

    properties
        Groups (:, 1)
    end

    properties (Dependent)
        NGroups double
        NSamples double
    end

    methods
        function obj = GroupedStat(time, data, groups)
            arguments
                time double = []
                data cell = {}
                groups = []
            end
            if isempty(time) && isempty(data) && isempty(groups)
                return
            end
            if width(data) ~= numel(groups)
                error("The number of groups must be the same as the number of columns in the data")
            end
            if height(data) ~= numel(time)
                error("The number of time points and values must be the same")
            end
            obj.Time = time;
            obj.Data = data;
            obj.Groups = groups;
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
            [~, idc] = filter(obj.Groups);
            obj = obj(:, idc, :);
        end
    end
end