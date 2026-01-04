classdef Events < spiky.core.ArrayBase
    %EVENTS Class representing discrete events in Time.
    
    properties (Hidden)
        T_ (:, 1) double % Time vector in seconds
        Start_ double % Start time in seconds
        Step_ double % Step in seconds
        N_ double % Number of events
    end

    properties (Dependent)
        Time (:, 1) double % Time vector in seconds
        Length double % Number of events
        Start double % Start time in seconds
        End double % End time in seconds
        Step double % Step in seconds
        IsUniform logical % Whether the events are uniformly spaced
        Fs double % Sampling frequency if uniform
    end

    methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = "Time";
        end
    end

    methods
        function obj = Events(time, n, step)
            % Constructor for Events class
            %
            %   Events(time) create a non-uniform events object
            %   Events(start, n, step) create a uniform events object

            arguments
                time double = []
                n double = 1
                step double = 1
            end
            if nargin<=1
                obj.T_ = time(:);
            else
                obj.Start_ = time;
                obj.Step_ = step;
                obj.N_ = n;
            end
        end

        function t = get.Time(obj)
            % Get the time vector
            if obj.IsUniform
                t = (obj.Start_:obj.Step_:obj.Start_+(obj.N_-1)*obj.Step_)';
            else
                t = obj.T_;
            end
        end
        
        function obj = set.Time(obj, t)
            % Set the time vector
            obj.T_ = t(:);
            obj.Start_ = [];
            obj.Step_ = [];
            obj.N_ = [];
        end

        function l = get.Length(obj)
            % Get the number of events
            if obj.IsUniform
                l = obj.N_;
            else
                l = length(obj.T_);
            end
        end

        function s = get.Start(obj)
            % Get the start time
            if obj.IsUniform
                s = obj.Start_;
            else
                s = obj.T_(1);
            end
        end

        function e = get.End(obj)
            % Get the end time
            if obj.IsUniform
                e = obj.Start_+(obj.N_-1)*obj.Step_;
            else
                e = obj.T_(end);
            end
        end

        function s = get.Step(obj)
            % Get the step
            if obj.IsUniform
                s = obj.Step_;
            else
                s = NaN;
            end
        end

        function u = get.IsUniform(obj)
            % Check if the events are uniformly spaced
            u = ~isempty(obj.Start_) && ~isempty(obj.Step_) && ~isempty(obj.N_);
        end

        function f = get.Fs(obj)
            % Get the sampling frequency
            if obj.IsUniform
                f = 1./obj.Step_;
            else
                f = NaN;
            end
        end

        function obj = updateFields(obj, s)
            % Update fields of the object from a struct of older version
            if isfield(s, "Time")
                obj.T_ = s.Time(:);
                obj.Start_ = [];
                obj.Step_ = [];
                obj.N_ = [];
            end
        end

        function d = diff(obj, n)
            %DIFF Calculate the difference between events
            %
            %   obj: events
            %   n: number of differences
            %
            %   d: difference between events
            
            arguments
                obj spiky.core.Events
                n double {mustBeInteger} = 1
            end
            
            d = diff(obj.Time, n);
        end

        function [obj, idc] = sort(obj, direction)
            %SORT Sort events by time
            %
            %   obj: events
            %   [direction]: "ascend" or "descend", default "ascend"
            %
            %   obj: sorted events
            %   idc: indices of the sorted events

            arguments
                obj spiky.core.Events
                direction string {mustBeMember(direction, ["ascend" "descend"])} = "ascend"
            end

            isUniform = obj.IsUniform;
            if isUniform
                if xor(strcmp(direction, "ascend"), obj.Step_>0);
                    newStart = obj.End;
                    newStep = -obj.Step_;
                    idc = (obj.Length:-1:1)';
                else
                    newStart = obj.Start_;
                    newStep = obj.Step_;
                    idc = (1:obj.Length)';
                end
            else
                [~, idc] = sort(obj.T_);
            end
            obj = obj.subIndex({idc, ':', ':', ':', ':', ':'});
            if isUniform
                obj.T_ = [];
                obj.Start_ = newStart;
                obj.Step_ = newStep;
                obj.N_ = length(idc);
            end
        end

        function [events, idc, idcIntervals] = inIntervals(obj, intervals, options)
            %ININTERVALS Find events within intervals
            %   [events, idc, idcIntervals] = inIntervals(obj, intervals, ...)
            %
            %   obj: events
            %   intervals: intervals object
            %   Name-value arguments:
            %       CellMode: if true, events is an array with the same size as intervals
            %       Offset: events is relative time to the beginning of the intervals plus offset if 
            %           non-empty and absolute time otherwise
            %       RightClose: whether the right boundary is closed. By default false.
            %       Sorted: whether the events are sorted by time already. By default true.
            %       KeepType: whether to keep the output events as Events type. By default false.
            %
            %   events: events within intervals, cell if cellmode is true
            %   idc: indices of events within intervals, events.Time = obj.Time(idc), or cell of it
            %   idcIntervals: indices of intervals for each event, or count of events within each 
            %       interval when cellmode is true (similar to histcounts, but much slower so 
            %       don't use for this purpose)
            arguments
                obj spiky.core.Events
                intervals % spiky.core.Intervals or double Nx2
                options.CellMode logical = false
                options.Offset double = []
                options.RightClose logical = false
                options.Sorted logical = true
                options.KeepType logical = false
            end
            ts = obj.Time;
            if isa(intervals, "spiky.core.Intervals")
                intervals = intervals.Time;
            elseif ~isnumeric(intervals) || size(intervals, 2)~=2
                error("Intervals must be spiky.core.Intervals or Nx2 numeric array.");
            end
            if options.Sorted
                % Use faster method for sorted events
                [idcStart, counts] = spiky.mex.findInIntervals(ts, intervals, options.RightClose);
                n = sum(counts);
                idc = zeros(n, 1);
                idcIntervals = zeros(n, 1);
                acc = 0;
                for ii = 1:size(intervals, 1)
                    count = counts(ii);
                    if count==0
                        continue
                    end
                    idc(acc+1:acc+count) = idcStart(ii):idcStart(ii)+count-1;
                    idcIntervals(acc+1:acc+count) = ii;
                    acc = acc+count;
                end
            else
                % Unsorted events, use slower method
                if options.RightClose
                    isIn = ts>=intervals(:, 1)'&ts<=intervals(:, 2)';
                else
                    isIn = ts>=intervals(:, 1)'&ts<intervals(:, 2)';
                end
                idcIn = find(isIn(:));
                [idc, idcIntervals] = ind2sub(size(isIn), idcIn);
                counts = sum(isIn, 1)';
            end
            if ~options.KeepType
                events = ts(idc);
                if ~isempty(options.Offset)
                    events = events-intervals(idcIntervals, 1)+options.Offset;
                end
            else
                events = obj.subIndex({idc, ':', ':', ':', ':', ':'});
                if ~isempty(options.Offset)
                    events.Time = events.Time-intervals(idcIntervals, 1)+options.Offset;
                end
            end
            if options.CellMode
                events = mat2cell(events, counts);
                idc = mat2cell(idc, counts);
                idcIntervals = counts;
            end
        end

        function [intervals, idc] = findContinuous(obj, minGap, minInterval)
            %FINDCONTINUOUS Find continuous intervals of events
            %
            %   intervals = findContinuous(obj, minGap, minInterval)
            %   
            %   obj: events
            %   [minGap]: minimum gap between intervals
            %   [minInterval]: minimum interval duration
            %
            %   intervals: Intervals object
            %   idc: indices of the intervals

            arguments
                obj spiky.core.Events
                minGap double = []
                minInterval double = 0
            end
            dt = [diff(obj.Time); Inf];
            if isempty(minGap)
                minGap = max(dt);
            end
            isCross = dt>=minGap;
            idc = find(isCross);
            prd = [[1; idc(1:end-1)+1] idc];
            prd0 = obj.Time(prd);
            if iscolumn(prd0)
                prd0 = prd0';
            end
            intervals = spiky.core.Intervals(prd0);
            isValid = intervals.ChunkDuration>=minInterval;
            intervals.Time = intervals.Time(isValid, :);
            prd1 = prd(isValid, 1);
            prd2 = prd(isValid, 2);
            idc = arrayfun(@(x, y) x:y, prd1, prd2, UniformOutput=false);
        end

        function s = sync(obj, obj2, name, varargin, options)
            %SYNC Synchronize two events objects
            %
            %   s = sync(obj, obj2, name, varargin, options)
            %
            %   obj: events
            %   obj2: events
            %   name: name of the synchronized events
            %   varargin: additional options passed to fit
            %   options
            %       AllowStep: allow fitting with heavyside step function
            %
            %   s: synchronized events
            arguments
                obj spiky.core.Events
                obj2 spiky.core.Events
                name string = "sync"
            end
            arguments (Repeating)
                varargin
            end
            arguments
                options.AllowStep logical = true
                options.Plot logical = false
            end
            if (obj.Length<2)||(obj2.Length<2)
                error("Not enough events to synchronize.")
            end
            if obj.Length~=obj2.Length
                error("Number of events must be the same.")
            end
            t1 = obj.Time;
            t2 = obj2.Time;
            td = t2-t1;
            d = diff(td);
            if sum(abs(d-mean(d))/std(d)>10)==0 || ~options.AllowStep
                [f, gof] = fit(t1, t2, "poly1", "Robust", "Bisquare", varargin{:});
                s = spiky.core.Sync(name, f, @(y) (y-f.p2)/f.p1, f.p1, f.p2, gof);
            else
                ft = fittype(@(a, b, c, d, x) a.*x+b.*sign(x-c)+d);
                [~, idx] = max(abs(d));
                [f, gof] = fit(t1, t2, ft, "StartPoint", ...
                    [1 diff(td(idx:idx+1))/2 mean(t1(idx:idx+1)) td(1)], ...
                    "TolFun", 1e-16, "MaxFunEvals", 10000, "MaxIter", 5000);
                s = spiky.core.Sync(name, f, @(y) (y<=f.a*f.c-f.b+f.d).*(y-f.d+f.b)./f.a+...
                    (y>f.a*f.c-f.b+f.d).*(y-f.d-f.b)./f.a, f.a, f.d-f.b, gof);
            end
            if options.Plot
                figure
                plot(t1, td-td(1), "ro", t1, f(t1)-t1-td(1), "b.-");
                xlabel("t1");
                ylabel('td-td(1)');
                legend(["Data", "Fit"]);
                title(name);
                spiky.plot.fixfig
            end
        end

        function h = plot(obj, plotOps, options)
            %PLOT Plot events as vertical lines
            arguments
                obj spiky.core.Events
                plotOps.?matlab.graphics.chart.decoration.ConstantLine
                options.Parent matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
            end
            if isempty(options.Parent)
                options.Parent = gca;
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = xline(options.Parent, obj.Time, plotArgs{:});
            if nargout>0
                h = h1;
            end
        end
    end
end