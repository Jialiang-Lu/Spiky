classdef RecEvent < spiky.core.Metadata & spiky.core.MappableArray
    % RECEVENT Class representing recorded TTL/network events

    properties %(SetAccess = {?spiky.core.Metadata, ?spiky.ephys.RecEvent})
        Time double
        Timestamp int64
        Type spiky.ephys.ChannelType
        Channel int16
        ChannelName string
        Rising logical
        Message string
    end

    methods (Static)
        function obj = load(fpth, channelNames, tsStart, fs)
            % LOADEVENTS Load recorded events from file
            %
            %   fpth: path to the file/folder containing the events
            %   channelNames: names of the channels
            %   tsStart: start timestamp
            %   fs: sampling frequency

            arguments
                fpth string
                channelNames string = string.empty
                tsStart int64 = 0
                fs double = []
            end
            fi = spiky.core.FileInfo(fpth);
            if isempty(fi)
                obj = spiky.ephys.RecEvents.empty;
                return
            end
            if exist(fpth, "dir")
                sn = spiky.utils.npy.readNPY(fullfile(fpth, "sample_numbers.npy"))-tsStart;
                if ~isempty(fs)
                    t = double(sn)./fs;
                else
                    t = double(sn);
                end
                nEvents = length(sn);
                if ~exist(fullfile(fpth, "text.npy"), "file")
                    % TTL
                    st = spiky.utils.npy.readNPY(fullfile(fpth, "states.npy"));
                    if isempty(channelNames)
                        channelNames = repmat("", max(abs(st)), 1);
                    end
                    for ii = nEvents:-1:1
                        obj(ii, 1) = spiky.ephys.RecEvent(t(ii), sn(ii), spiky.ephys.ChannelType.Dig, ...
                            abs(st(ii)), channelNames(abs(st(ii))), st(ii)>0, "");
                    end
                else
                    % Network
                    txt = spiky.utils.npy.readNPY(fullfile(fpth, "text.npy"));
                    for ii = nEvents:-1:1
                        obj(ii, 1) = spiky.ephys.RecEvent(t(ii), sn(ii), spiky.ephys.ChannelType.Net, ...
                            0, "", true, string(txt{ii}));
                    end
                end
            else
                error("spiky:NotImplemented", "Loading events from a file is not implemented yet")
            end
        end
    end

    methods
        function obj = RecEvent(time, timestamp, type, channel, name, rising, message)
            % RECEVENTS Create a new instance of RecEvents

            arguments
                time double = 0
                timestamp int64 = 0
                type spiky.ephys.ChannelType = spiky.ephys.ChannelType.Dig
                channel int16 = 0
                name string = ""
                rising logical = false
                message string = ""
            end

            obj.Time = time;
            obj.Timestamp = timestamp;
            obj.Type = type;
            obj.Channel = channel;
            obj.ChannelName = name;
            obj.Rising = rising;
            obj.Message = message;
        end

        function obj = sort(obj)
            % SORT Sort events by time

            [~, idc] = sort([obj.Time]);
            obj = obj(idc);
        end

        function [sync, obj2] = syncWith(obj, obj2, name, tol)
            % SYNCWITH Synchronize two event objects
            %
            %   obj: events
            %   obj2: events to synchronize with
            %   name: name of the synchronization
            %   tol: tolerance in seconds
            %
            %   sync: synchronization object
            %   obj2: updated events

            arguments (Input)
                obj spiky.ephys.RecEvent
                obj2 spiky.ephys.RecEvent
                name string
                tol double = 0.01
            end
            arguments (Output)
                sync spiky.core.Sync
                obj2 spiky.ephys.RecEvent
            end

            t1 = spiky.core.Events([obj.Time]);
            t2 = spiky.core.Events([obj2.Time]);
            if t1.Length~=t2.Length
                dl = t1.Length-t2.Length;
                d1 = diff(t1);
                d2 = diff(t2);
                dlmax = min([max(abs(dl), 4) t1.Length-1 t2.Length-1]);
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
                t1 = spiky.core.Events(t1.T(idc1));
                t2 = spiky.core.Events(t2.T(idc2));
            end
            sync = t1.sync(t2, name);
            obj2 = obj2.syncTime(sync.Inv);
        end

        function obj = syncTime(obj, func)
            % SYNCTIME Synchronize events to a synchronization object
            %
            %   obj: events
            %   func: function to transform the time
            %
            %   obj: updated events

            arguments
                obj spiky.ephys.RecEvent
                func
            end

            t = func([obj.Time]);
            for ii = 1:length(obj)
                obj(ii).Time = t(ii);
            end
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.ChannelName;
        end
    end
end