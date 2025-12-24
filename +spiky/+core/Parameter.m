classdef Parameter < spiky.core.MappableArray
    %PARAMETER A parameter that can be changed during an experiment
    %
    %   Fields:
    %       Name: name
    %       Type: class type in the stimulus presentation program
    %       Data: cell array of spiky.core.EventsTable objects representing the values at
    %               different time points

    properties
        Name (:, 1) string % Name of the parameter
        Type (:, 1) string % Type of the parameter in the stimulus presentation program
    end

    properties (Dependent)
        Time (:, 1) double % Time points when the parameter changes
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
            dimLabelNames = {["Name" "Type"]};
        end
    end

    methods
        function obj = Parameter(name, type, data)
            arguments
                name (:, 1) string = ""
                type (:, 1) string = ""
                data (:, 1) cell = {}
            end
            assert(all(cellfun(@(x) isa(x, "spiky.core.EventsTable"), data)), ...
                "All values must be spiky.core.EventsTable objects");
            obj.Name = name;
            obj.Type = type;
            obj.Data = data;
            obj.verifyDimLabels();
        end

        function varargout = get.Time(obj)
            t = cellfun(@(x) x.Time, obj.Data, UniformOutput=false);
            [varargout{1:numel(t)}] = t{:};
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
            if isempty(obj.Time)
                value = [];
            else
                intervals = spiky.core.Intervals([[-Inf; obj.Time(2:end)], [obj.Time(2:end); Inf]]);
                [~, ~, idc] = intervals.haveEvents(time);
                value = obj.Data{1}.Data(idc);
                if iscell(obj.Data{1}.Data)
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
            if iscell(obj.Data{1}.Data)
                h = @(c) cellfun(h, c);
            end
            n = length(obj.Time);
            idc = find(h(obj.Data{1}.Data));
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

        function obj = syncTime(obj, func)
            %SYNCTIME Synchronize events to a synchronization object
            %
            %   obj: parameter(s)
            %   func: function to transform the time
            %
            %   obj: updated parameter(s)

            arguments
                obj spiky.core.Parameter
                func
            end

            for ii = 1:height(obj.Data)
                obj.Data{ii}.Time = func(obj.Data{ii}.Time);
            end
        end    
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end