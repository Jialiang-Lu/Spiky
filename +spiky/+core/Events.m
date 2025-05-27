classdef Events
    % EVENTS Class representing discrete events
    
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

            idc = (1:obj.Length)';
            if obj.IsUniform
                if xor(strcmp(direction, "ascend"), obj.Step_>0)
                    obj.Start_ = obj.End;
                    obj.Step_ = -obj.Step_;
                    idc = flipud(idc);
                end
            else
                [~, idc] = sort(obj.T_);
                obj.T_ = obj.T_(idc);
            end
        end

        function [events, idc, idcPeriods] = inPeriods(obj, periods, cellmode, offset, ...
            rightClose, sorted, options)
            %INPERIODS Find events within periods
            %
            %   obj: events
            %   periods: periods object
            %   [cellmode]: if true, events is an array with the same size as periods
            %   [offset]: events is relative time to the beginning of the periods plus offset if 
            %       non-empty and absolute time otherwise
            %   [rightClose]: whether the right boundary is closed. By default false.
            %   [sorted]: whether the events are sorted by time already. By default true.
            %
            %   events: events within periods, cell if cellmode is true
            %   idc: indices of events within periods, events.Time = obj.Time(idc), or cell of it
            %   idcPeriods: indices of periods for each event, or count of events within each 
            %       period when cellmode is true (similar to histcounts, but much slower so 
            %       don't use for this purpose)
            arguments
                obj spiky.core.Events
                periods spiky.core.Periods
                cellmode logical = false
                offset double {mustBeScalarOrEmpty} = []
                rightClose logical = false
                sorted logical = true
                options.KeepType logical = false
            end
            ts = obj.Time;
            periods = periods.Time;
            if sorted
                [indices, counts] = spiky.mex.findInPeriods(ts, periods, rightClose);
                if ~cellmode
                    idc = zeros(sum(counts), 1);
                    idcPeriods = zeros(sum(counts), 1);
                    acc = 0;
                    for ii = 1:size(periods, 1)
                        count = counts(ii);
                        if count==0
                            continue
                        end
                        idc(acc+1:acc+count) = indices(ii):indices(ii)+count-1;
                        idcPeriods(acc+1:acc+count) = ii;
                        acc = acc+count;
                    end
                    if ~options.KeepType
                        events = ts(idc);
                        if ~isempty(offset)
                            events = events-periods(idcPeriods, 1)+offset;
                        end
                    else
                        events = subsref(obj, substruct("()", {idc}));
                        if ~isempty(offset)
                            events.Time = events.Time-periods(idcPeriods, 1)+offset;
                        end
                    end
                else
                    idc = cell(size(periods, 1), 1);
                    idcPeriods = zeros(size(periods, 1), 1);
                    events = cell(size(periods, 1), 1);
                    acc = 0;
                    for ii = 1:size(periods, 1)
                        count = counts(ii);
                        if count==0
                            continue
                        end
                        idc1 = indices(ii):indices(ii)+count-1;
                        idc{ii} = idc1';
                        if ~options.KeepType
                            if ~isempty(offset)
                                events{ii} = ts(idc1)-periods(ii, 1)+offset;
                            else
                                events{ii} = ts(idc1);
                            end
                        else
                            events{ii} = subsref(obj, substruct("()", {idc1}));
                            if ~isempty(offset)
                                events{ii}.Time = events{ii}.Time-periods(ii, 1)+offset;
                            end
                        end
                    end
                end
                return
            end
            if rightClose
                tmp = ts'>=periods(:, 1)&ts'<=periods(:, 2);
            else
                tmp = ts'>=periods(:, 1)&ts'<periods(:, 2);
            end
            if ~cellmode
                tmp = tmp';
                idcIn = find(tmp(:));
                [idc, idcPeriods] = ind2sub(size(tmp), idcIn);
                if ~options.KeepType
                    events = ts(idc);
                    if ~isempty(offset)
                        events = events-periods(idcPeriods, 1)+offset;
                    end
                else
                    events = subsref(obj, substruct("()", {idc}));
                    if ~isempty(offset)
                        events.Time = events.Time-periods(idcPeriods, 1)+offset;
                    end
                end
        else
                idc = cell(size(tmp, 1), 1);
                events = cell(size(tmp, 1), 1);
                if ~isempty(offset)
                    for ii = 1:size(tmp, 1)
                        idc1 = find(tmp(ii, :));
                        if isempty(idc1)
                            continue
                        end
                        idc{ii} = idc1;
                        if ~options.KeepType
                            events{ii} = ts(idc1)-periods(ii, 1)+offset;
                        else
                            events{ii} = subsref(obj, substruct("()", {idc1}));
                            events{ii}.Time = events{ii}.Time-periods(ii, 1)+offset;
                        end
                    end
                else
                    for ii = 1:size(tmp, 1)
                        idc1 = find(tmp(ii, :));
                        if isempty(idc1)
                            continue
                        end
                        idc{ii} = idc1;
                        if ~options.KeepType
                            events{ii} = ts(idc1);
                        else
                            events{ii} = subsref(obj, substruct("()", {idc1}));
                        end
                    end
                end
                if nargout>2
                    idcPeriods = cellfun(@length, events);
                end
            end
        end

        function [periods, idc] = findContinuous(obj, minGap, minPeriod)
            %FINDCONTINUOUS Find continuous periods of events
            %
            %   periods = findContinuous(obj, minGap, minPeriod)
            %   
            %   obj: events
            %   [minGap]: minimum gap between periods
            %   [minPeriod]: minimum period duration
            %
            %   periods: Periods object
            %   idc: indices of the periods

            arguments
                obj spiky.core.Events
                minGap double = []
                minPeriod double = 0
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
            periods = spiky.core.Periods(prd0);
            isValid = periods.ChunkDuration>=minPeriod;
            periods.Time = periods.Time(isValid, :);
            prd1 = prd(isValid, 1);
            prd2 = prd(isValid, 2);
            idc = arrayfun(@(x, y) x:y, prd1, prd2, UniformOutput=false);
        end

        function s = sync(obj, obj2, name, varargin, options)
            % SYNC Synchronize two events objects
            %
            %   s = sync(obj, obj2, name, varargin, options)
            %
            %   obj: events
            %   obj2: events
            %   name: name of the synchronized events
            %   varargin: additional options passed to fit
            %   options
            %       allowStep: allow fitting with heavyside step function
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
                spiky.plot.fig
                plot(t1, td-td(1), "ro", t1, f(t1)-t1-td(1), "b.-");
                xlabel("t1");
                ylabel('td-td(1)');
                legend(["Data", "Fit"]);
                title(name);
                spiky.plot.fixfig
            end
        end
    end
end