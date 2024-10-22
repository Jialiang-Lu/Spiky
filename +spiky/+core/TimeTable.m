classdef TimeTable < spiky.core.Events & matlab.mixin.CustomDisplay
    % TIMETABLE Represents data indexed by time points in seconds

    properties
        Data
    end

    methods
        function obj = TimeTable(varargin)
            % TIMETABLE Create a new instance of TimeTable
            %
            %   TimeTable(time, data) creates a non-uniformly sampled time table
            %   TimeTable(start, step, data) creates a uniformly sampled time table
            %   TimeTable(data) creates a uniformly sampled time table at 0, 1, 2,... seconds

            if nargin==0
                return
            elseif nargin==1
                data = varargin{1};
                if isvector(data)
                    data = data(:);
                end
                obj.Data = data;
                obj.Start_ = 0;
                obj.Step_ = 1;
                obj.N_ = height(data);
            elseif nargin==2
                obj.T_ = varargin{1};
                data = varargin{2};
                % if isvector(data)
                %     data = data(:);
                % end
                if length(obj.T_)~=height(data)
                    error("The number of time points and values must be the same")
                end
                obj.Data = data;
            elseif nargin==3
                obj.Start_ = varargin{1};
                obj.Step_ = varargin{2};
                data = varargin{3};
                if isvector(data)
                    data = data(:);
                end
                obj.N_ = height(data);
                obj.Data = data;
            else
                error("Invalid number of arguments")
            end
        end

        function [obj, idc] = sort(obj, direction)
            %SORT Sort data by time
            %
            %   direction: 'ascend' or 'descend'
            %
            %   obj: sorted TimeTable
            %   idc: indices of the sorted data
            arguments
                obj spiky.core.TimeTable
                direction string {mustBeMember(direction, ["ascend" "descend"])} = "ascend"
            end

            [obj, idc] = sort@spiky.core.Events(obj, direction);
            obj.Data = obj.Data(idc, :);
        end

        function periods = findPeriods(obj, thr, mingap, minperiod, extrapolate)
            %FINDPERIODS finds period intervals of the input crossing the threshold
            %
            %   periods = findPeriods(obj, thr, mingap, minperiod, extrapolate)
            %
            %   obj: TimeTable
            %   thr: threshold
            %   mingap: minimum distance to be considered a different period. 
            %       Otherwise it gets concatenated
            %   minperiod: minimum duration of a period to be considered
            %   extrapolate: if true, periods end at the first value below the
            %       threshold, not the last value above
            %
            %   periods: Periods object

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
                    obj1 = feval(class(obj));
                    obj1.T_ = subsref(obj.Time, st);
                    obj1.Data = subsref(obj.Data, sd);
                    obj = obj1;
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
                    st.subs = sd.subs(1);
                    obj1 = varargin{1};
                    obj.Time = subsasgn(obj.Time, st, obj1.Time);
                    obj.Data = subsasgn(obj.Data, sd, obj1.Data);
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

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            switch s(1).type
                case '{}'
                    s(1).type = '()';
            end
            if isscalar(s)
                n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end

        function varargout = size(obj, varargin)
            [varargout{1:nargout}] = size(obj.Data, varargin{:});
        end

        function obj = cat(dim, varargin)
            n = numel(varargin);
            if n==0
                obj = spiky.core.TimeTable.empty;
                return
            end
            obj = varargin{1};
            if n==1
                return
            end
            c = class(obj);
            for ii = 2:n
                assert(isa(varargin{ii}, c), "All inputs must be of the same class")
                assert(isequal(class(obj.Data), class(varargin{ii}.Data)), ...
                    "All inputs must have the same data type")
                switch dim
                    case 1
                        assert(isequal(size(obj.Data, 2), size(varargin{ii}.Data, 2)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data; varargin{ii}.Data];
                        if ~obj.IsUniform
                            obj.T_ = [obj.T_; varargin{ii}.Time];
                        end
                    case 2
                        assert(isequal(size(obj.Data, 1), size(varargin{ii}.Data, 1)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data varargin{ii}.Data];
                    case 3
                        assert(isequal(size(obj.Data, 1:2), size(varargin{ii}.Data, 1:2)), ...
                            "All inputs must have the same size")
                        obj.Data = cat(3, obj.Data, varargin{ii}.Data);
                    otherwise
                        error("Invalid dimension")
                end
            end
        end

        function obj = horzcat(varargin)
            obj = cat(2, varargin{:});
        end

        function obj = vertcat(varargin)
            obj = cat(1, varargin{:});
        end

        function ind = end(obj,k,n)
            sz = size(obj);
            if k < n
                ind = sz(k);
            else
                ind = prod(sz(k:end));
            end
        end
    end
end