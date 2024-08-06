classdef TimeTable < spiky.core.Events & ...
    matlab.mixin.CustomDisplay
    % TIMETABLE Represents data indexed by time points in seconds

    properties
        Data (:, :)
    end

    methods
        function obj = TimeTable(time, data)
            arguments
                time = []
                data = []
            end
            if ~isempty(time) && isempty(data)
                data = time;
                if isvector(data)
                    data = data(:);
                end
                time = 1:size(data, 1);
            end
            obj.Time = time(:);
            obj.Data = data;
            if length(obj.Time)~=size(obj.Data, 1)
                error("The number of time points and values must be the same")
            end
        end

        function periods = findPeriods(obj, thr, mingap, minperiod, extrapolate)
            %FINDPERIODS finds period intervals of the input crossing the threshold
            %
            %   x: input vector, or a cell {time, input vector}
            %   thr: threshold
            %   mingap: minimum distance to be considered a different period. 
            %       Otherwise it gets concatenated
            %   minperiod: minimum duration of a period to be considered
            %   extrapolate: if true, periods end at the first value below the
            %       threshold, not the last value above
            %
            %   periods: Period object
            arguments
                obj spiky.core.TimeTable
                thr (1, 1) double = 0
                mingap (1, 1) double = NaN
                minperiod (1, 1) double = 0
                extrapolate (1, 1) logical = false
            end
            if ~isvector(obj.Data) || ~isnumeric(obj.Data)
                error("Data must be a numeric vector")
            end
            if isnan(mingap)
                mingap = max(diff(obj.Time));
            end
            if isinf(mingap)
                mingap = realmax;
            end
            t = obj.Time;
            x = obj.Data;
            isCross = x>thr;
            if isscalar(t) && isscalar(isCross)
                if isCross
                    periods = [t Inf];
                else
                    periods = double.empty(0, 2);
                end
                return
            end
            if extrapolate
                isCross = [false; isCross(1:end-1)]|isCross;
            end
            tCross = t(isCross);
            tDiff = abs(diff([-Inf ; tCross ; Inf]));
            jumps = find(tDiff>mingap);
            periods = [tCross(jumps(1:end-1)) tCross(jumps(2:end)-1)];
            periods(diff(periods, [], 2)<minperiod, :)=[];
            periods = spiky.core.Periods(periods);
        end

        function varargout = subsref(obj, s)
            switch s(1).type
                case '.'
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        obj = obj.Data;
                    end
                case '()'
                    sd = s(1);
                    st = sd;
                    st.subs = sd.subs(1);
                    obj = spiky.core.TimeTable(subsref(obj.Time, st), subsref(obj.Data, sd));
                    if isscalar(s)
                        varargout{1} = obj;
                    else
                        [varargout{1:nargout}] = subsref(obj, s(2:end));
                    end
                    return
                case '{}'
                    s.type = '()';
                    [varargout{1:nargout}] = subsref(obj.Data, s);
                    return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end

        function obj = subsasgn(obj, s, varargin)
            if isequal(obj, [])
                obj = spiky.core.TimeTable.empty;
            end
            switch s(1).type
                case '.'
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        obj1 = obj.Data;
                        obj1 = builtin("subsasgn", obj1, s, varargin{:});
                        obj.Data = obj1;
                        return
                    end
                case '()'
                    sd = s(1);
                    st = sd;
                    st.subs = sd.subs{1};
                    if ~isscalar(s)
                        error("Assigning properties using parentheses is not allowed. Use braces instead.")
                    end
                    if ~isscalar(varargin) || ~isa(varargin{1}, "spiky.core.TimeTable")
                        error("Assignment must be a TimeTable object")
                    end
                    obj1 = varargin{1};
                    obj = spiky.core.TimeTable(subsasgn(obj.Time, st, obj1.Time), ...
                        subsasgn(obj.Data, sd, obj1.Data));
                    return
                case '{}'
                    s.type = '()';
                    obj1 = obj.Data;
                    obj1 = builtin("subsasgn", obj1, s, varargin{:});
                    obj.Data = obj1;
                    return
            end
            obj = builtin("subsasgn", obj, s, varargin{:});
        end
    end
end