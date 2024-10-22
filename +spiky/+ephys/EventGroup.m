classdef EventGroup < spiky.core.Metadata & spiky.core.MappableArray
    % EVENTSGROUP Class containing information of events and their synchronization
    
    properties %(SetAccess = {?spiky.core.Metadata, ?spiky.ephys.EventGroup})
        Name string
        Type spiky.ephys.ChannelType
        Events spiky.ephys.RecEvents
        TsRange (1, 2) double
        Sync spiky.core.Sync
    end

    properties (Dependent)
        NSamples double
    end
    
    methods
        function obj = EventGroup(name, type, events, tsRange, sync)
            % RECSYNC Create a new instance of EventGroup
            
            arguments
                name string = ""
                type spiky.ephys.ChannelType = spiky.ephys.ChannelType.Neural
                events spiky.ephys.RecEvents = spiky.ephys.RecEvents.empty
                tsRange (1, 2) double = [0, 0]
                sync spiky.core.Sync = spiky.core.Sync.empty
            end
            
            obj.Name = name;
            obj.Type = type;
            obj.Events = events;
            obj.TsRange = tsRange;
            obj.Sync = sync;
        end

        function obj = updateFields(obj, s)
            types = [s.Events.Value.Type];
            types = struct("Class", s.Events.Value(1).Type.Class, "Value", ...
                [types.Value]');
            obj.Events = spiky.ephys.RecEvents([s.Events.Value.Time], [s.Events.Value.Timestamp], ...
                spiky.core.Metadata.structToObj(types), [s.Events.Value.Channel], [s.Events.Value.ChannelName], ...
                [s.Events.Value.Rising], [s.Events.Value.Message]);
        end

        function n = get.NSamples(obj)
            n = diff(obj.TsRange)+1;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end