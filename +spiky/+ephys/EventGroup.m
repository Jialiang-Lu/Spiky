classdef EventGroup < spiky.core.Metadata & spiky.core.MappableArray
    % EVENTSGROUP Class containing information of events and their synchronization
    
    properties %(SetAccess = {?spiky.core.Metadata, ?spiky.ephys.EventGroup})
        Name string
        Type spiky.ephys.ChannelType
        Events spiky.ephys.RecEvent
        TsRange (1, 2) double
        Sync spiky.core.Sync
    end
    
    methods
        function obj = EventGroup(name, type, events, tsRange, sync)
            % RECSYNC Create a new instance of EventGroup
            
            arguments
                name string = ""
                type spiky.ephys.ChannelType = spiky.ephys.ChannelType.Neural
                events spiky.ephys.RecEvent = spiky.ephys.RecEvent.empty
                tsRange (1, 2) double = [0, 0]
                sync spiky.core.Sync = spiky.core.Sync.empty
            end
            
            obj.Name = name;
            obj.Type = type;
            obj.Events = events;
            obj.TsRange = tsRange;
            obj.Sync = sync;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end