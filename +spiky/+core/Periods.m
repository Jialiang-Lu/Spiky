classdef Periods < matlab.mixin.CustomDisplay
    % PERIODS Class representing time periods, left closed and right open

    properties
        Time (:, 2) double % start and end in seconds
    end

    properties (Dependent)
        Length
        Duration
    end

    methods (Static)
        function periods = union(varargin)
            % UNION Union of periods
            if nargin==1
                periods = varargin{1};
                return
            end
            for ii = 1:nargin
                if isa(varargin{ii}, "spiky.core.Periods")
                    varargin{ii} = varargin{ii}.Time;
                elseif size(varargin{ii}, 2)~=2
                    error("Time must have two columns.")
                elseif ~isnumeric(varargin{ii})
                    error("Wrong input type %s.", class(varargin{ii}))
                end
            end
            per = cell2mat(varargin');
            per = per(diff(per, 1, 2)>0, :);
            n = size(per, 1);
            [edges, idc] = sort(reshape(per.', 1, []), 'ascend');
            [~, idc2] = sort(idc);
            idc2 = reshape(idc2, 2, []).';
            intervals = zeros([1, n*2-1]);
            for ii = 1:n
                intervals(idc2(ii, 1):idc2(ii, 2)-1) = 1;
            end
            intervals = spiky.core.TimeTable(intervals);
            idcOut = intervals.findPeriods;
            idcOut = idcOut.Time;
            periods = [edges(idcOut(:, 1))' edges(idcOut(:, 2)+1)'];
            periods = spiky.core.Periods(periods);
        end

        function periods = intersect(varargin)
            % INTERSECT Intersection of periods
            if nargin==1
                periods = varargin{1};
                return
            end
            for ii = 1:nargin
                if isa(varargin{ii}, "spiky.core.Periods")
                    varargin{ii} = varargin{ii}.Time;
                elseif size(varargin{ii}, 2)~=2
                    error("Time must have two columns.")
                elseif ~isnumeric(varargin{ii})
                    error("Wrong input type %s.", class(varargin{ii}))
                end
            end
            per = cell2mat(varargin');
            per = per(diff(per, 1, 2)>0, :);
            n = size(per, 1);
            [edges, idc] = sort(reshape(per.', 1, []), "ascend");
            [~, idc2] = sort(idc);
            idc2 = reshape(idc2, 2, []).';
            intervals = zeros([1, n*2-1]);
            for ii = 1:n
                intervals(idc2(ii, 1):idc2(ii, 2)-1) = 1;
            end
            idcOut = find(intervals==nargin);
            periods = [edges(idcOut)' edges(idcOut+1)'];
            periods = spiky.core.Periods(periods);
        end
    end

    methods
        function obj = Periods(time)
            % Constructor for Periods class
            arguments
                time double = double.empty(0, 2)
            end
            if size(time, 2)~=2
                error("Time must have two columns.")
            end
            obj.Time = time;
        end

        function len = get.Length(obj)
            % Getter for Length property
            len = size(obj.Time, 1);
        end

        function dur = get.Duration(obj)
            % Getter for Duration property
            dur = diff(obj.Time, 1, 2);
        end

        function periods = unionWith(obj, periods)
            % UNIONWITH Union with another periods object
            arguments
                obj spiky.core.Periods
            end
            arguments (Repeating)
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.union(obj, periods{:});
        end

        function periods = and(obj, periods)
            % AND Intersect with another periods object
            arguments
                obj spiky.core.Periods
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.intersect(obj, periods);
        end

        function periods = intersectWith(obj, periods)
            % INTERSECTWITH Intersect with another periods object
            arguments
                obj spiky.core.Periods
            end
            arguments (Repeating)
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.intersect(obj, periods{:});
        end

        function periods = or(obj, periods)
            % OR Union with another periods object
            arguments
                obj spiky.core.Periods
                periods spiky.core.Periods
            end
            periods = spiky.core.Periods.union(obj, periods);
        end

        function periods = minus(obj, periods)
            % MINUS Subtract another periods object
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
            % COMPLEMENT Complement with respect to a period
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

        function [events, idc, idcPeriods] = haveEvents(obj, events, cellmode, offset)
            % HAVEEVENTS Find events within periods
            %
            %   obj: periods
            %   periods: events object
            %   cellmode: if true, events is an array with the same size as periods
            %   offset: events is relative time to the beginning of the periods plus offset if 
            %       non-empty and absolute time otherwise
            %
            %   events: events within periods, cell if cellmode is true
            %   idc: indices of events within periods, events.Time = obj.Time(idc), or cell of it
            %   idcPeriods: indices of periods for each event, or count of events within each 
            %       period when cellmode is true (similar to histcounts, but much slower so 
            %       don't use for this purpose)
            arguments
                obj spiky.core.Periods
                events % double or spiky.core.Events
                cellmode logical = false
                offset double {mustBeScalarOrEmpty} = []
            end
            if isnumeric(events)
                events = spiky.core.Events(events);
            end
            [events, idc, idcPeriods] = events.inPeriods(obj, cellmode, offset);
        end
    end
end