classdef RecEvents < spiky.core.TimeTable & spiky.core.MappableArray

    properties (Dependent)
        Timestamp int64
        Type spiky.ephys.ChannelType
        Channel int16
        ChannelName categorical
        Rising logical
        Message string
    end

    methods
        function obj = RecEvents(time, timestamp, type, channel, name, rising, message)
            % RECEVENTS Create a new instance of RecEvents

            arguments
                time double = []
                timestamp int64 = []
                type spiky.ephys.ChannelType = spiky.ephys.ChannelType.empty
                channel int16 = []
                name categorical = categorical.empty
                rising logical = logical.empty
                message string = string.empty
            end

            time = time(:);
            timestamp = timestamp(:);
            type = type(:);
            channel = channel(:);
            name = name(:);
            rising = rising(:);
            message = message(:);
            if ~isempty(time) && ~isscalar(time)
                if isscalar(type)
                    type = repmat(type, size(time));
                end
                if isscalar(channel)
                    channel = repmat(channel, size(time));
                end
                if isempty(name)
                    name = categorical(strings(size(time)));
                elseif isscalar(name)
                    name = repmat(name, size(time));
                end
                if isscalar(rising)
                    rising = repmat(rising, size(time));
                end
                if isscalar(message)
                    message = repmat(message, size(time));
                end
            end
            obj@spiky.core.TimeTable(time, table(timestamp, type, channel, name, rising, message, ...
                VariableNames=["Timestamp" "Type" "Channel" "ChannelName" "Rising" "Message"]));
        end

        function [sync, obj2] = syncWith(obj, obj2, name, tol, options)
            % SYNCWITH Synchronize two event objects
            %
            %   obj: events
            %   obj2: events to synchronize with
            %   name: name of the synchronization
            %   tol: tolerance in seconds
            %   options
            %       allowStep: allow fitting with heavyside step function
            %
            %   sync: synchronization object
            %   obj2: updated events

            arguments
                obj spiky.ephys.RecEvents
                obj2 spiky.ephys.RecEvents
                name string
                tol double = 0.02
                options.AllowStep logical = true
                options.Plot logical = true
            end

            t1 = spiky.core.Events(obj.Time);
            t2 = spiky.core.Events(obj2.Time);
            dl = t1.Length-t2.Length;
            d1 = diff(t1);
            d2 = diff(t2);
            dlmax = min([max(abs(dl), 6) t1.Length-2 t2.Length-2]);
            shifts = -dlmax:dlmax;
            d = zeros(length(shifts), 1);
            for ii = 1:length(shifts)
                s = shifts(ii);
                if s<0
                    l = min(t1.Length-1, t2.Length-1+s);
                    idc1 = 1:l;
                    idc2 = 1-s:l-s;
                else
                    l = min(t1.Length-1-s, t2.Length-1);
                    idc1 = 1+s:l+s;
                    idc2 = 1:l;
                end
                d(ii) = max(abs(d1(idc1)-d2(idc2)));
            end
            [dmin, idx] = min(d);
            if dmin>tol
                error("Max jitter is %.3f s, which is larger than the tolerance %.3f s", dmin, tol)
            end
            shift = shifts(idx);
            if shift<0
                l = min(t1.Length, t2.Length+shift);
                idc1 = 1:l;
                idc2 = 1-shift:l-shift;
            else
                l = min(t1.Length-shift, t2.Length);
                idc1 = 1+shift:l+shift;
                idc2 = 1:l;
            end
            t1 = spiky.core.Events(t1.Time(idc1));
            t2 = spiky.core.Events(t2.Time(idc2));
            optionsArgs = namedargs2cell(options);
            sync = t1.sync(t2, name, optionsArgs{:});
            obj2.Time = sync.Inv(obj2.Time);
        end

        function h = plot(obj, linespec, plotOps, options)
            % PLOT Plot the events
            %
            %   h = obj.plot(plotOps, options)
            %
            %   plotOps: plotting options
            %   options: additional options for the plot
            %
            %   h: handle to the plot object

            arguments
                obj spiky.ephys.RecEvents
                linespec = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Parent matlab.graphics.axis.Axes = gca
            end

            if isempty(obj.Time)
                h = gobjects(0);
                return;
            end

            plotArgs = namedargs2cell(plotOps);
            n = height(obj);
            x = reshape([obj.Time, obj.Time]', [], 1);
            y = zeros(2*n, 1);
            idc = (1:2:2*n)';
            y(idc+obj.Data.Rising) = 1;
            h1 = plot(options.Parent, x, y, linespec, plotArgs{:});
            box off
            ylim([-0.1, 1.1]);
            if nargout>0
                h = h1;
            end
        end

        function varargout = subsref(obj, s)
            s(1) = obj.useKey(s(1));
            [varargout{1:nargout}] = subsref@spiky.core.TimeTable(obj, s);
        end

        function obj = subsasgn(obj, s, varargin)
            if isequal(obj, [])
                obj = spiky.ephys.RecEvents.empty;
            end
            s(1) = obj.useKey(s(1));
            obj = subsasgn@spiky.core.TimeTable(obj, s, varargin{:});
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            [s(1), use] = obj.useKey(s(1));
            switch s(1).type
                case '{}'
                    s(1).type = '()';
            end
            if isscalar(s)
                if use
                    n = 1;
                else
                    n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
                end
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Data.ChannelName;
        end
    end
end