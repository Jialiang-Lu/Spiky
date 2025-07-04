classdef TimeTable < spiky.core.Events & spiky.core.ArrayTable & matlab.mixin.CustomDisplay
    % TIMETABLE Represents data indexed by time points in seconds

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = "Time";
        end
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

        function out = interp(obj, t, method, extrap, options)
            %INTERP Interpolate the data at specific time points
            %
            %   out = interp(obj, t, varargin)
            %
            %   obj: TimeTable
            %   t: time points
            %   method: interpolation method
            %   extrap: extrapolation method
            %   options: options
            %       AsTimeTable: return as TimeTable
            %
            %   out: interpolated data

            arguments
                obj spiky.core.TimeTable
                t
                method string {mustBeMember(method, ["linear" "nearest" "next" "previous" "pchip" ...
                    "cubic" "v5cubic" "makima" "spline"])} = "nearest"
                extrap = "extrap"
                options.AsTimeTable (1, 1) logical = false
            end
            
            t = t(:);
            if height(obj)==1
                out = obj.Data;
                return
            end
            if ismember(method, ["nearest" "next" "previous"])
                idc = interp1(obj.Time, 1:height(obj), t, method, extrap);
                if ndims(obj.Data)==3
                    out = obj.Data(idc, :, :);
                else
                    out = obj.Data(idc, :);
                end
            elseif isnumeric(obj.Data)
                out = interp1(obj.Time, obj.Data, t, method, extrap);
            else
                error("Method %s is not supported for non-numeric data", method)
            end
            if options.AsTimeTable
                out = spiky.core.TimeTable(t, out);
            end
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
            if ~isvector(obj.Data)||(~isnumeric(obj.Data)&&~islogical(obj.Data))
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
            isCross = x>=thr;
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

        % function varargout = subsref(obj, s)
        %     if isempty(obj)
        %         [varargout{1:nargout}] = builtin("subsref", obj, s);
        %         return
        %     end
        %     switch s(1).type
        %         case '()'
        %             sd = s(1);
        %             st = sd;
        %             st.subs = sd.subs(1);
        %             obj.Time = subsref(obj.Time, st);
        %     end
        %     [varargout{1:nargout}] = subsref@spiky.core.ArrayTable(obj, s);
        % end

        % function obj = subsasgn(obj, s, varargin)
        %     obj = subsasgn@spiky.core.ArrayTable(obj, s, varargin{:});
        %     switch s(1).type
        %         case '()'
        %             sd = s(1);
        %             st = sd;
        %             st.subs = sd.subs(1);
        %             obj1 = varargin{1};
        %             obj.Time = subsasgn(obj.Time, st, obj1.Time);
        %     end
        % end
    end
end