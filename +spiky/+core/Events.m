classdef Events < matlab.mixin.CustomDisplay
    % EVENTS Class representing discrete events
    
    properties
        Time (:, 1) double % Time vector in seconds
    end

    properties (Dependent)
        Length double % Number of events
    end

    methods
         function obj = Events(Time)
            % Constructor for Events class
            if isnumeric(Time)
                obj.Time = Time(:);
            elseif iscell(Time)
                obj = cellfun(@(x) spiky.core.Events(x), Time);
            else
                error("Wrong input type.")
            end
        end

        function len = get.Length(obj)
            % Getter for Length property
            len = length(obj.Time);
        end

        function d = diff(obj, n)
            % DIFF Calculate the difference between events
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

        function [events, idc, idcPeriods] = inPeriods(obj, periods, arraymode, offset)
            % INPERIODS Find events within periods
            %
            %   obj: events
            %   periods: periods object
            %   arraymode: if true, events is an array with the same size as periods
            %   offset: events is relative time to the beginning of the periods plus offset if 
            %       non-empty and absolute time otherwise
            %
            %   events: events within periods, scalar if arraymode is false
            %   idc: indices of events within periods, events.Time = obj.Time(idc), or cell of it
            %   idcPeriods: indices of periods for each event, or count of events within each 
            %       period when arraymode is true (similar to histcounts, but much slower so 
            %       don't use for this purpose)
            arguments
                obj spiky.core.Events
                periods spiky.core.Periods
                arraymode logical = false
                offset double {mustBeScalarOrEmpty} = []
            end
            spikes = obj.Time;
            periods = periods.Time;
            tmp = spikes'>=periods(:, 1)&spikes'<periods(:, 2);
            if ~arraymode
                tmp = tmp';
                idcIn = find(tmp(:));
                [idc, idcPeriods] = ind2sub(size(tmp), idcIn);
                s = spikes(idc);
                if ~isempty(offset)
                    s = s-periods(idcPeriods, 1)+offset;
                end
            else
                idc = cell(size(tmp, 1), 1);
                s = cell(size(tmp, 1), 1);
                if ~isempty(offset)
                    for c = 1:size(tmp, 1)
                        idc{c} = find(tmp(c, :));
                        s{c} = spikes(idc{c})-periods(c, 1)+offset;
                    end
                else
                    for c = 1:size(tmp, 1)
                        idc{c} = find(tmp(c, :));
                        s{c} = spikes(idc{c});
                    end
                end
                idcPeriods = cellfun(@length, s);
            end
            events = spiky.core.Events(s);
        end

        function s = sync(obj, obj2, name, varargin)
            % SYNC Synchronize two events objects
            %
            %   obj: events
            %   obj2: events
            %   name: name of the synchronized events
            %   varargin: additional options passed to fit
            %
            %   s: synchronized events
            arguments (Input)
                obj spiky.core.Events
                obj2 spiky.core.Events
                name string = "sync"
            end
            arguments (Input, Repeating)
                varargin
            end
            arguments (Output)
                s spiky.core.Sync
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
            if sum(abs(d-mean(d))/std(d)>10)==0
                [f, gof] = fit(t1, t2, "poly1", "Robust", "Bisquare", varargin{:});
                s = spiky.core.Sync(name, f, @(y) (y-f.p2)/f.p1, f.p1, f.p2, gof);
            else
                ft = fittype(@(a, b, c, d, x) a.*x+b.*sign(x-c)+d);
                [~, idx] = max(abs(d));
                [f, gof] = fit(t1, t2, ft, "StartPoint", [1 diff(td(idx:idx+1))/2 mean(t1(idx:idx+1)) td(1)], ...
                    "TolFun", 1e-16, "MaxFunEvals", 10000, "MaxIter", 5000);
                s = spiky.core.Sync(name, f, @(y) (y<=f.a*f.c-f.b+f.d).*(y-f.d+f.b)./f.a+...
                    (y>f.a*f.c-f.b+f.d).*(y-f.d-f.b)./f.a, f.a, f.d-f.b, gof);
            end
            h = spiky.plot.Fig;
            plot(t1, t2-t1, "ro", t1, f(t1)-t1, "b.-");
            xlabel("t1");
            ylabel('t2-t1');
            legend(["Data", "Fit"]);
            title(name);
            h.fix
        end
    end

    methods (Access = protected)
        function footer = getFooter(obj)
            % Override the getFooter method
            if ~isscalar(obj)
                footer = getFooter@matlab.mixin.CustomDisplay(obj);
            else
                footer = [sprintf('%g, ', obj.Time(1:min(obj.Length, 20))) ...
                    spiky.utils.ternary(obj.Length>20, '.....', '') sprintf('\b\b\n')];
            end
        end
    end
end