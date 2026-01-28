classdef Intervals < spiky.core.ArrayBase
    %INTERVALS Class representing time intervals, left closed and right open

    properties
        Time (:, 2) double = double.empty(0, 2)
    end

    properties (Dependent)
        Length double
        Duration double
        ChunkDuration double
        Start double
        End double
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

    methods (Static, Hidden)
        function [c, ct] = count(varargin)
            %COUNT Count number of intervals that contains the current time
            %   [c, ct] = count(time1, time2, ...)
            %
            %   time1, time2, ...: time intervals as n x 2 double or spiky.core.Intervals
            %
            %   c: EventsTable with time index and count of intervals
            %   ct: EventsTable with time and count of intervals
            arguments (Repeating)
                varargin
            end
            for ii = 1:nargin
                if isa(varargin{ii}, "spiky.core.Intervals")
                    varargin{ii} = varargin{ii}.Time;
                elseif size(varargin{ii}, 2)~=2
                    error("Time must have two columns.")
                elseif ~isnumeric(varargin{ii})
                    error("Wrong input type %s.", class(varargin{ii}))
                end
                varargin{ii} = varargin{ii}(diff(varargin{ii}, 1, 2)>0, :);
            end
            n = nargin;
            t = cell2mat(varargin')';
            d = zeros(size(t))+[1; -1];
            t = t(:);
            d = d(:);
            [t, idc] = sort(t, "ascend");
            d = d(idc);
            d = cumsum(d);
            c = spiky.core.EventsTable(1:numel(t), d);
            ct = spiky.core.EventsTable(t, d);
        end

        function intervals = combine(varargin, options)
            arguments (Repeating)
                varargin
            end
            arguments
                options.Op string {mustBeMember(options.Op, ["Union", "Intersect"])}
            end
            [c, ct] = spiky.core.Intervals.count(varargin{:});
            switch options.Op
                case "Union"
                    thr = 0.5;
                case "Intersect"
                    thr = numel(varargin);
                otherwise
                    error("Unknown operation %s.", options.Op)
            end
            prds = c.findIntervals(thr, 1, 0);
            prds = prds.Time+[0 1];
            t = ct.Time;
            t = reshape(t(prds), height(prds), 2);
            t = t(diff(t, 1, 2)>0, :);
            intervals = spiky.core.Intervals(t);
        end
    end

    methods (Static)
        function intervals = concat(varargin)
            %CONCAT Concatenate intervals
            %   intervals = concat(obj) concatenates all intervals into one interval
            arguments (Repeating)
                varargin spiky.core.Intervals
            end
            c = cellfun(@(x) vertcat(x.Time), varargin, UniformOutput=false);
            c = c(:);
            t = cell2mat(c);
            intervals = spiky.core.Intervals(t);
        end

        function intervals = union(varargin)
            %UNION Union of intervals
            if nargin==1
                intervals = varargin{1};
                return
            end
            intervals = spiky.core.Intervals.combine(varargin{:}, Op="Union");
        end

        function intervals = intersect(varargin)
            %INTERSECT Intersection of intervals
            if nargin==1
                intervals = varargin{1};
                return
            end
            intervals = spiky.core.Intervals.combine(varargin{:}, Op="Intersect");
        end
    end

    methods
        function obj = Intervals(time)
            arguments
                time (:, 2) double = double.empty(0, 2)
            end
            if size(time, 2)~=2
                error("Time must have two columns.")
            end
            obj.Time = time;
        end

        function len = get.Length(obj)
            len = size(obj.Time, 1);
        end

        function dur = get.Duration(obj)
            dur = sum(diff(obj.Time, 1, 2));
        end

        function dur = get.ChunkDuration(obj)
            dur = diff(obj.Time, 1, 2);
        end

        function start = get.Start(obj)
            start = obj.Time(:, 1);
        end

        function ed = get.End(obj)
            ed = obj.Time(:, 2);
        end

        function obj = sel(obj, idc)
            %SEL Select intervals by index
            obj.Time = obj.Time(idc, :);
        end

        function [obj, idc] = sort(obj, direction)
            %SORT Sort intervals
            arguments
                obj spiky.core.Intervals
                direction string {mustBeMember(direction, ["ascend" "descend"])} = "ascend"
            end
            [~, idc] = sort(obj.Time(:, 1), direction);
            obj = obj.subIndex({idc, ':', ':', ':', ':', ':'});
        end

        function intervals = unionAll(obj)
            %UNIONALL Union all intervals
            arguments
                obj spiky.core.Intervals
            end
            c = num2cell(obj);
            intervals = spiky.core.Intervals.union(c{:});
        end

        function intervals = unionWith(obj, intervals)
            %UNIONWITH Union with another intervals object
            arguments
                obj spiky.core.Intervals
            end
            arguments (Repeating)
                intervals spiky.core.Intervals
            end
            intervals = spiky.core.Intervals.union(obj, intervals{:});
        end

        function intervals = and(obj, intervals)
            %AND Intersect with another intervals object
            arguments
                obj spiky.core.Intervals
                intervals spiky.core.Intervals
            end
            intervals = spiky.core.Intervals.intersect(obj, intervals);
        end

        function intervals = intersectWith(obj, intervals)
            %INTERSECTWITH Intersect with another intervals object
            arguments
                obj spiky.core.Intervals
            end
            arguments (Repeating)
                intervals spiky.core.Intervals
            end
            intervals = spiky.core.Intervals.intersect(obj, intervals{:});
        end

        function intervals = or(obj, intervals)
            %OR Union with another intervals object
            arguments
                obj spiky.core.Intervals
                intervals spiky.core.Intervals
            end
            intervals = spiky.core.Intervals.union(obj, intervals);
        end

        function intervals = subtract(obj, intervals)
            %SUBTRACT Subtract another intervals object
            arguments
                obj spiky.core.Intervals
                intervals spiky.core.Intervals = spiky.core.Intervals
            end
            a = obj.Time(diff(obj.Time, 1, 2)>0, :);
            b = intervals.Time(diff(intervals.Time, 1, 2)>0, :);
            ha = size(a, 1);
            hb = size(b, 1);
            n = ha*2+hb*2;
            [xs, idc] = sort([reshape(a.', 1, []) reshape(b.', 1, [])], 'ascend');
            [~, idc2] = sort(idc);
            idcA = reshape(idc2(1:ha*2), 2, []).';
            idcB = reshape(idc2(ha*2+1:end), 2, []).';
            intervals = zeros([1, n-1]);
            for k = 1:ha
                intervals(idcA(k, 1):idcA(k, 2)-1) = 1;
            end
            for k = 1:hb
                intervals(idcB(k, 1):idcB(k, 2)-1) = -1;
            end
            idcOut = find(intervals==1);
            intervals = [xs(idcOut)' xs(idcOut+1)'];
            intervals = spiky.core.Intervals(intervals);
        end

        function intervals = complement(obj, interval)
            %COMPLEMENT Complement with respect to a interval
            arguments
                obj spiky.core.Intervals
                interval double = []
            end
            if isempty(interval)
                interval = [min(obj.Time, "all") max(obj.Time, "all")];
            end
            if isscalar(interval)
                interval = [0 interval];
            end
            interval = spiky.core.Intervals(interval);
            intervals = interval.subtract(obj);
        end

        function [intervals, idc, idcIntervals] = haveIntervals(obj, intervals)
            %HAVEINTERVALS Find intervals within intervals
            %   [intervals, idc, idcIntervals] = haveIntervals(obj, intervals)
            %
            %   obj: intervals
            %   intervals: intervals object
            %
            %   intervals: intervals within obj
            %   idc: indices of intervals within obj
            %   idcIntervals: indices of intervals for each interval
            arguments
                obj spiky.core.Intervals
                intervals %double or spiky.core.Intervals
            end
            if isnumeric(intervals)
                assert(width(intervals)==2, "Intervals must have two columns.");
                prd = intervals;
            elseif isa(intervals, "spiky.core.Intervals")
                prd = intervals.Time;
            else
                error("Wrong input type %s.", class(intervals))
            end
            [~, idc1, idcP1] = obj.haveEvents(prd(:, 1));
            [~, idc2, idcP2] = obj.haveEvents(prd(idc1, 2));
            idc2 = idc2(idcP2==idcP1(idc2));
            idc = idc1(idc2);
            idcIntervals = idcP1(idc2);
            intervals = subsref(intervals, substruct("()", {idc, ':'}));
        end

        function [events, idc, idcIntervals] = haveEvents(obj, events, options)
            %HAVEEVENTS Find events within intervals
            %   [events, idc, idcIntervals] = haveEvents(obj, events, ...)
            %
            %   obj: intervals
            %   intervals: events object
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
                obj spiky.core.Intervals
                events %double or spiky.core.Events
                options.CellMode logical = false
                options.Offset double = []
                options.RightClose logical = false
                options.Sorted logical = true
                options.KeepType logical = false
            end
            if isnumeric(events)
                events = spiky.core.Events(events);
            elseif ~isa(events, "spiky.core.Events")
                error("Wrong input type %s.", class(events))
            end
            optionsCell = namedargs2cell(options);
            [events, idc, idcIntervals] = events.inIntervals(obj, optionsCell{:});
        end

        function h = plot(obj, plotOps, options)
            %PLOT Plot intervals
            arguments
                obj spiky.core.Intervals
                plotOps.?matlab.graphics.chart.decoration.ConstantRegion
                options.Parent matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
            end
            if isempty(options.Parent)
                options.Parent = gca;
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = xregion(options.Parent, obj.Time(:, 1), obj.Time(:, 2), ...
                plotArgs{:});
            if nargout>0
                h = h1;
            end
        end
    end
end