classdef Parameter < spiky.core.MappableObjArray
    %PARAMETER A parameter that can be changed during an experiment

    properties
        Name string
        Type string % Type in the stimulus presentation program
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
            dimLabelNames = {["Name"; "Type"]};
        end
    end

    methods
        function obj = Parameter(name, type, array)
            arguments
                name (:, 1) string = string.empty
                type (:, 1) string = string.empty
                array (:, 1) cell = {} % cell array of spiky.core.EventsTable
            end
            obj@spiky.core.MappableObjArray(array, Class="spiky.core.EventsTable");
            obj.Name = name;
            obj.Type = type;
            obj.verifyDimLabels();
        end

        function value = get(obj, time)
            %GET Get the value of the parameter at a specific time point
            %
            %   time: time point(s), double or spiky.core.Events
            %
            %   value: value(s) of the parameter
            arguments
                obj (1, 1) spiky.core.Parameter
                time = 0 % double or spiky.core.Events
            end
            obj = obj.Array{1};
            if isempty(obj.Time)
                value = [];
            else
                intervals = spiky.core.Intervals([[-Inf; obj.Time(2:end)], [obj.Time(2:end); Inf]]);
                [~, ~, idc] = intervals.haveEvents(time);
                value = obj.Data(idc);
                if iscell(obj.Data)
                    value = value{:};
                end
            end
        end

        function intervals = getIntervals(obj, value, partialMatch)
            %GETINTERVALS Get the intervals when the parameter has a specific value
            %
            %   value: value(s) or function handle
            %   partialMatch: whether to use partial match
            %
            %   intervals: intervals when the parameter has the value
            arguments
                obj (1, 1) spiky.core.Parameter
                value % value(s) or function handle
                partialMatch logical = true
            end
            obj = obj.Array{1};
            if isempty(obj.Time)
                intervals = spiky.core.Intervals;
                return
            end
            if ~isa(value, "function_handle")
                if isstring(value) && partialMatch
                    h = @(x) contains(x, value);
                else
                    h = @(x) isequal(x, value);
                end
            else
                h = value;
            end
            if iscell(obj.Data)
                h = @(c) cellfun(h, c);
            end
            n = length(obj.Time);
            idc = find(h(obj.Data));
            if isempty(idc)
                intervals = spiky.core.Intervals;
                return
            end
            idc1 = idc;
            idc2 = idc+1;
            idc2(idc2>n) = n;
            t = [obj.Time(idc1) obj.Time(idc2)];
            if idc(1)==1
                t(1) = 0;
            end
            if idc(end)==n
                t(end) = Inf;
            end
            intervals = spiky.core.Intervals(t);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end