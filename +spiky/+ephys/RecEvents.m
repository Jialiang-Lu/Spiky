classdef RecEvents < spiky.core.TimeTable & spiky.core.MappableArray

    % properties (Dependent)
    %     Timestamp int64
    %     Type spiky.ephys.ChannelType
    %     Channel int16
    %     ChannelName categorical
    %     Rising logical
    %     Message string
    % end

    methods
        function obj = RecEvents(time, timestamp, type, channel, name, rising, message)
            %RECEVENTS Create a new instance of RecEvents

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
            %SYNCWITH Synchronize two event objects
            %
            %   obj: events
            %   obj2: events to synchronize with
            %   name: name of the synchronization
            %   tol: tolerance in seconds
            %   options
            %       AllowStep: allow fitting with heavyside step function
            %       AllowMissing: allow missing events
            %       Plot: plot the synchronization
            %
            %   sync: synchronization object
            %   obj2: updated events

            arguments
                obj spiky.ephys.RecEvents
                obj2 spiky.ephys.RecEvents
                name string
                tol double = 0.02
                options.AllowStep logical = true
                options.AllowMissing logical = false
                options.Plot logical = true
            end

            t1 = obj.Time;
            t2 = obj2.Time;
            n1 = length(t1);
            n2 = length(t2);
            dl = n1-n2;
            d1 = diff(t1);
            d2 = diff(t2);
            dlmax = min([max(abs(dl), 6) n1-2 n2-2]);
            shifts = -dlmax:dlmax;
            d = zeros(length(shifts), 1);
            %%
            for ii = 1:length(shifts)
                %%
                s = shifts(ii);
                if s<0
                    l = min(n1-1, n2-1+s);
                    idc1 = 1:l;
                    idc2 = 1-s:l-s;
                else
                    l = min(n1-1-s, n2-1);
                    idc1 = 1+s:l+s;
                    idc2 = 1:l;
                end
                d(ii) = max(abs(d1(idc1)-d2(idc2)));
            end
            
            %%
            [dmin, idx] = min(d);
            shift = shifts(idx);
            if dmin>tol
                if options.AllowMissing
                    t3 = [t1; t2];
                    id3 = [ones(n1, 1); 2*ones(n2, 1)];
                    idOld3 = [1:n1, 1:n2]';
                    [t3, idc3] = sort(t3);
                    id3 = id3(idc3);
                    idOld3 = idOld3(idc3);
                    d3 = diff(t3);
                    idc12 = find(id3(1:end-1)==1 & id3(2:end)==2);
                    idc21 = find(id3(1:end-1)==2 & id3(2:end)==1);
                    d12 = d3(idc12);
                    d21 = d3(idc21);
                    if ~isempty(d12) && ~isempty(d21)
                        if std(d12)<std(d21)
                            offset = median(d12);
                            idc = d12>=offset-tol & d12<=offset+tol;
                            idc = idc12(idc);
                            idc1 = idOld3(idc);
                            idc2 = idOld3(idc+1);
                        else
                            offset = median(d21);
                            idc = d21>=offset-tol & d21<=offset+tol;
                            idc = idc21(idc);
                            idc1 = idOld3(idc+1);
                            idc2 = idOld3(idc);
                        end
                        obj.Time = obj.Time(idc1);
                        obj.Data = obj.Data(idc1, :);
                        obj2.Time = obj2.Time(idc2);
                        obj2.Data = obj2.Data(idc2, :);
                        [sync, obj2] = obj.syncWith(obj2, name, tol, ...
                            AllowStep=options.AllowStep, Plot=options.Plot);
                        return
                    end
                end
                error("Max jitter is %.3f s, which is larger than the tolerance %.3f s", dmin, tol)
            end
            if shift<0
                l = min(n1, n2+shift);
                idc1 = 1:l;
                idc2 = 1-shift:l-shift;
            else
                l = min(n1-shift, n2);
                idc1 = 1+shift:l+shift;
                idc2 = 1:l;
            end
            t1 = spiky.core.Events(t1(idc1));
            t2 = spiky.core.Events(t2(idc2));
            optionsArgs = namedargs2cell(options);
            sync = t1.sync(t2, name, AllowStep=options.AllowStep, Plot=options.Plot);
            obj2.Time = sync.Inv(obj2.Time);
        end

        function h = plot(obj, linespec, plotOps, options)
            %PLOT Plot the events
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