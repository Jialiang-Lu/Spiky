classdef RecEvents < spiky.core.TimeTable & spiky.core.MappableArray

    properties (Dependent)
        Timestamp int64
        Type spiky.ephys.ChannelType
        Channel int16
        ChannelName string
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
                name string = string.empty
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
                if isscalar(name)
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
                tol double = 0.01
                options.allowStep logical = true
            end

            t1 = spiky.core.Events(obj.Time);
            t2 = spiky.core.Events(obj2.Time);
            if t1.Length~=t2.Length
                dl = t1.Length-t2.Length;
                d1 = diff(t1);
                d2 = diff(t2);
                dlmax = min([max(abs(dl), 4) t1.Length-2 t2.Length-2]);
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
            end
            optionsArgs = namedargs2cell(options);
            sync = t1.sync(t2, name, optionsArgs{:});
            obj2.Time = sync.Inv(obj2.Time);
        end

        function varargout = subsref(obj, s)
            s(1) = obj.useKey(s(1));
            [varargout{1:nargout}] = subsref@spiky.core.TimeTable(obj, s);
        end

        function obj = subsasgn(obj, s, varargin)
            s(1) = obj.useKey(s(1));
            obj = subsasgn@spiky.core.TimeTable(obj, s, varargin{:});
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Data.ChannelName;
        end
    end
end