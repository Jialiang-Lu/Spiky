classdef EventsTable < spiky.core.Events
    % TIMETABLE Represents data indexed by time points in seconds

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {"Time"};
        end
    end

    methods
        function obj = EventsTable(varargin)
            % TIMETABLE Create a new instance of EventsTable
            %
            %   EventsTable(time, data) creates a non-uniformly sampled time table
            %   EventsTable(start, step, data) creates a uniformly sampled time table
            %   EventsTable(data) creates a uniformly sampled time table at 0, 1, 2,... seconds

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
                obj.T_ = varargin{1}(:);
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

        function out = interp(obj, t, method, extrap, options)
            %INTERP Interpolate the data at specific time points
            %
            %   out = interp(obj, t, varargin)
            %
            %   obj: EventsTable
            %   t: time points
            %   method: interpolation method
            %   extrap: extrapolation method
            %   options: options
            %       AsEventsTable: return as EventsTable
            %
            %   out: interpolated data

            arguments
                obj spiky.core.EventsTable
                t
                method string {mustBeMember(method, ["linear" "nearest" "next" "previous" "pchip" ...
                    "cubic" "v5cubic" "makima" "spline"])} = "nearest"
                extrap = "extrap"
                options.AsEventsTable (1, 1) logical = false
            end
            
            t = t(:);
            if height(obj)==1
                out = obj.Data;
                return
            end
            if ismember(method, ["nearest" "next" "previous"])
                [t0, idcT] = unique(obj.Time);
                idc = interp1(t0, idcT, t, method, extrap);
                if method=="next"
                    idc(isnan(idc)) = height(obj);
                elseif method=="previous"
                    idc(isnan(idc)) = 1;
                end
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
            if options.AsEventsTable
                out = spiky.core.EventsTable(t, out);
            end
        end

        function intervals = findIntervals(obj, thr, mingap, mininterval, extrapolate)
            %FINDINTERVALS finds interval intervals of the input crossing the threshold
            %
            %   intervals = findIntervals(obj, thr, mingap, mininterval, extrapolate)
            %
            %   obj: EventsTable
            %   thr: threshold
            %   mingap: minimum distance to be considered a different interval. 
            %       Otherwise it gets concatenated
            %   mininterval: minimum duration of a interval to be considered
            %   extrapolate: if true, intervals end at the first value below the
            %       threshold, not the last value above
            %
            %   intervals: Intervals object

            arguments
                obj spiky.core.EventsTable
                thr (1, 1) double = 0
                mingap (1, 1) double = NaN
                mininterval (1, 1) double = 0
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
            if islogical(x)
                isCross = x;
            else
                isCross = x>=thr;
            end
            if isscalar(t) && isscalar(isCross)
                if isCross
                    intervals = [t Inf];
                else
                    intervals = double.empty(0, 2);
                end
                return
            end
            if extrapolate
                isCross = [false; isCross(1:end-1)]|isCross;
            end
            tCross = t(isCross);
            tDiff = abs(diff([-Inf ; tCross ; Inf]));
            jumps = find(tDiff>mingap);
            intervals = [tCross(jumps(1:end-1)) tCross(jumps(2:end)-1)];
            intervals(diff(intervals, [], 2)<mininterval, :)=[];
            intervals = spiky.core.Intervals(intervals);
        end

        function out = densify(obj, t, options)
            %DENSIFY Densify the EventsTable to a regular time grid
            %
            %   out = densify(obj, t, options)
            %
            %   obj: EventsTable
            %   t: time points to densify to
            %   Name-Value options:
            %       IgnoreContent: ignore the content of the EventsTable
            %       OneHot: return one-hot encoded data
            %       AsEventsTable: return as EventsTable
            %
            %   out: densified EventsTable

            arguments
                obj spiky.core.EventsTable
                t (:, 1) double
                options.IgnoreContent (1, 1) logical = false
                options.OneHot (1, 1) logical = false
                options.AsTable (1, 1) logical = true
                options.AsEventsTable (1, 1) logical = false
            end
            
            nT = length(t);
            res = t(2)-t(1);
            centers = (t(1:end-1)+t(2:end))/2;
            prds = [[centers(1)-res/2; centers] [centers; centers(end)+res/2]];
            [~, idcObj, idcT] = obj.inIntervals(prds);
            if options.IgnoreContent
                obj.Data = ones(height(obj.Data), 1);
            end
            data = obj.Data;
            if istable(data) && width(data)==1 && ~options.AsTable
                data = data{:, 1};
            end
            nD = width(data);
            if istable(data)
                out = table();
                for ii = 1:nD
                    obj.Data = data{:, ii};
                    out.(data.Properties.VariableNames{ii}) = ...
                        obj.densify(t, IgnoreContent=options.IgnoreContent, ...
                        OneHot=options.OneHot, AsEventsTable=false);
                end
                if options.AsEventsTable
                    out = spiky.core.EventsTable(t, out);
                end
                return
            elseif iscell(data)
                out = cell(nT, nD);
            elseif isstring(data) && ~options.OneHot
                out = strings(nT, nD);
            elseif iscategorical(data) && ~options.OneHot
                out = categorical(NaN(nT, nD));
            elseif options.OneHot
                if iscategorical(data)
                    cn = categories(data);
                else
                    if islogical(data)
                        data = int8(data);
                    end
                    cn = unique(data);
                end
                data = onehotencode(data, 2, ClassNames=cn);
                out = zeros(nT, width(data));
            else
                out = zeros(nT, nD);
            end
            out(idcT, :) = data(idcObj, :);
            if options.AsEventsTable
                out = spiky.core.EventsTable(t, out);
            end
        end
    end

    methods (Access=protected)
        function data = getData(obj)
            %GETDATA Get the Data property.
            data = obj.Data_;
        end

        function obj = setData(obj, data)
            %SETDATA Set the Data property.
            obj.Data_ = data;
        end
    end
end