classdef Parameter < spiky.core.MappableArray
    %PARAMETER A parameter that can be changed during an experiment

    properties
        Name string
        Type string
        Data spiky.core.TimeTable
    end

    properties (Dependent)
        Time
    end

    methods
        function obj = Parameter(name, type, time, values)
            arguments
                name string = ""
                type string = ""
                time = []
                values = []
            end
            obj.Name = name;
            obj.Type = type;
            obj.Data = spiky.core.TimeTable(time, values);
        end

        function t = get.Time(obj)
            t = obj.Data.Time;
        end

        function obj = set.Time(obj, time)
            obj.Data.Time = time;
        end

        function value = get(obj, time)
            %GET Get the value of the parameter at a specific time point
            %
            %   time: time point(s), double or spiky.core.Events
            %
            %   value: value(s) of the parameter
            arguments
                obj spiky.core.Parameter
                time = 0 % double or spiky.core.Events
            end
            if isempty(obj.Time)
                value = [];
            else
                periods = spiky.core.Periods([[-Inf; obj.Time(2:end)], [obj.Time(2:end); Inf]]);
                [~, ~, idc] = periods.haveEvents(time);
                value = obj.Data.Data(idc);
                if iscell(obj.Data.Data)
                    value = value{:};
                end
            end
        end

        function periods = getPeriods(obj, value, partialMatch)
            %GETPERIODS Get the periods when the parameter has a specific value
            %
            %   value: value(s) or function handle
            %   partialMatch: whether to use partial match
            %
            %   periods: periods when the parameter has the value
            arguments
                obj spiky.core.Parameter
                value % value(s) or function handle
                partialMatch logical = true
            end
            if isempty(obj.Time)
                periods = spiky.core.Periods.empty;
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
            if iscell(obj.Data.Data)
                h = @(c) cellfun(h, c);
            end
            n = length(obj.Time);
            idc = find(h(obj.Data.Data));
            if isempty(idc)
                periods = spiky.core.Periods.empty;
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
            periods = spiky.core.Periods(t);
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

            for ii = 1:length(obj)
                obj(ii).Time = func(obj(ii).Time);
            end
        end    
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end