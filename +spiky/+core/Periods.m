classdef Periods
    %PERIODS Class representing time periods, left closed and right open

    properties
        Time (:, 2) double = double.empty
    end

    properties (Dependent)
        Length double
        Duration double
        ChunkDuration double
        Start double
        End double
    end

    methods (Static, Hidden)
        function periods = combine(varargin, options)
            arguments (Repeating)
                varargin
            end
            arguments
                options.Op string {mustBeMember(options.Op, ["Union", "Intersect"])}
            end
            for ii = 1:nargin
                if isa(varargin{ii}, "spiky.core.Periods")
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
            c = spiky.core.TimeTable(1:numel(t), d);
            switch options.Op
                case "Union"
                    thr = 0.5;
                case "Intersect"
                    thr = numel(varargin);
                otherwise
                    error("Unknown operation %s.", options.Op)
            end
            prds = c.findPeriods(thr, 1, 0);
            prds = prds.Time+[0 1];
            t = reshape(t(prds), height(prds), 2);
            t = t(diff(t, 1, 2)>0, :);
            periods = spiky.core.Periods(t);
        end
    end

    methods (Static)
        function periods = concat(varargin)
            %CONCAT Concatenate periods
            %   periods = concat(obj) concatenates all periods into one period
            arguments (Repeating)
                varargin spiky.core.Periods
            end
            c = cellfun(@(x) vertcat(x.Time), varargin, UniformOutput=false);
            c = c(:);
            t = cell2mat(c);
            periods = spiky.core.Periods(t);
        end

        function periods = union(varargin)
            %UNION Union of periods
            if nargin==1
                periods = varargin{1};
                return
            end
            periods = spiky.core.Periods.combine(varargin{:}, Op="Union");
        end

        function periods = intersect(varargin)
            %INTERSECT Intersection of periods
            if nargin==1
                periods = varargin{1};
                return
            end
            periods = spiky.core.Periods.combine(varargin{:}, Op="Intersect");
        end
    end

    methods
        function obj = Periods(time)
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
            %SEL Select periods by index
            obj.Time = obj.Time(idc, :);
        end

        function [obj, idc] = sort(obj)
            %SORT Sort periods
            [~, idc] = sort(obj.Time(:, 1));
            obj.Time = obj.Time(idc, :);
        end

        function periods = unionAll(obj)
            %UNIONALL Union all periods
            arguments
                obj spiky.core.Periods
            end
            c = num2cell(obj);
            periods = spiky.core.Periods.union(c{:});
        end

        function periods = unionWith(obj, periods)
            %UNIONWITH Union with another periods object
            arguments
                obj spiky.core.Periods
            end
            arguments (Repeating)
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.union(obj, periods{:});
        end

        function periods = and(obj, periods)
            %AND Intersect with another periods object
            arguments
                obj spiky.core.Periods
                periods spiky.core.Periods
            end
            periods = spiky.utils.bsxfun(@spiky.core.Periods.intersect, obj, periods);
        end

        function periods = intersectWith(obj, periods)
            %INTERSECTWITH Intersect with another periods object
            arguments
                obj spiky.core.Periods
            end
            arguments (Repeating)
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.intersect(obj, periods{:});
        end

        function periods = or(obj, periods)
            %OR Union with another periods object
            arguments
                obj spiky.core.Periods
                periods spiky.core.Periods
            end
            periods = spiky.utils.bsxfun(@spiky.core.Periods.union, obj, periods);
        end

        function periods = minus(obj, periods)
            %MINUS Subtract another periods object
            arguments
                obj spiky.core.Periods
                periods spiky.core.Periods = spiky.core.Periods.empty()
            end
            a = obj.Time(diff(obj.Time, 1, 2)>0, :);
            b = periods.Time(diff(periods.Time, 1, 2)>0, :);
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
            periods = [xs(idcOut)' xs(idcOut+1)'];
            periods = spiky.core.Periods(periods);
        end

        function periods = complement(obj, period)
            %COMPLEMENT Complement with respect to a period
            arguments
                obj spiky.core.Periods
                period double = []
            end
            if isempty(period)
                period = [min(obj.Time, "all") max(obj.Time, "all")];
            end
            if isscalar(period)
                period = [0 period];
            end
            period = spiky.core.Periods(period);
            periods = period - obj;
        end

        function [events, idc, idcPeriods] = haveEvents(obj, events, cellmode, offset, ...
                rightClose, sorted)
            %HAVEEVENTS Find events within periods
            %
            %   obj: periods
            %   periods: events object
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
                obj spiky.core.Periods
                events %double or spiky.core.Events
                cellmode logical = false
                offset double {mustBeScalarOrEmpty} = []
                rightClose logical = false
                sorted logical = true
            end
            if isnumeric(events)
                events = spiky.core.Events(events);
            end
            [events, idc, idcPeriods] = events.inPeriods(obj, cellmode, offset, rightClose, sorted);
        end

        function h = plot(obj, plotOps, options)
            %PLOT Plot periods
            arguments
                obj spiky.core.Periods
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

        function obj = updateFields(obj, s)
            %Update fields of the object from a struct of older version
            if isfield(s, "Data")
                obj.Time = s.Data;
            end
        end
    end
end