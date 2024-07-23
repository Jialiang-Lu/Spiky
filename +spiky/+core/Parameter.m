classdef Parameter < spiky.core.MappableArray & spiky.core.Metadata
    % PARAMETER A parameter that can be changed during an experiment

    properties
        Name string
        Type string
        Values spiky.core.TimeTable
    end

    properties (Dependent)
        Time
        Data
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
            obj.Values = spiky.core.TimeTable(time, values);
        end

        function t = get.Time(obj)
            t = obj.Values.Time;
        end

        function obj = set.Time(obj, time)
            obj.Values.Time = time;
        end

        function d = get.Data(obj)
            d = obj.Values.Data;
        end

        function obj = set.Data(obj, data)
            obj.Values.Data = data;
        end

        function value = get(obj, time)
            % GET Get the value of the parameter at a specific time point
            %
            %   time: time point(s)
            %
            %   value: value(s) of the parameter
            if isempty(obj.Time)
                value = [];
            else
                periods = spiky.core.Periods([[-Inf; obj.Time(2:end)], [obj.Time(2:end); Inf]]);
                [~, ~, idc] = periods.haveEvents(time);
                value = obj.Values(idc).Data;
            end
        end

        function obj = syncTime(obj, func)
            % SYNCTIME Synchronize events to a synchronization object
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