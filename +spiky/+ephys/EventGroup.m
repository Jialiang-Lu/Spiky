classdef EventGroup < spiky.core.MappableArray
    %EVENTSGROUP Class containing information of events and their synchronization
    %
    %   Fields:
    %       Name: name of the event group
    %       Type: type of the events
    %       Events: spiky.ephys.RecEvents object containing the events
    %       TsRange: timestamp range of the events
    %       Sync: spiky.core.Sync object containing the synchronization information

    properties
        Name string
        Type spiky.ephys.ChannelType
        Events spiky.core.ObjArray = spiky.core.ObjArray % ObjArray of spiky.ephys.RecEvents
        TsRange double
        Sync spiky.core.Sync
    end

    properties (Dependent)
        NSamples double
    end

        methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = "Events";
        end

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
            dimLabelNames = {["Name"; "Type"; "TsRange"; "Sync"]};
        end
    end

    methods
        function obj = EventGroup(name, type, events, tsRange, sync)
            %RECSYNC Create a new instance of EventGroup
            
            arguments
                name (:, 1) string = string.empty
                type (:, 1) spiky.ephys.ChannelType = spiky.ephys.ChannelType.empty
                events (:, 1) cell = {} % cell array of spiky.ephys.RecEvents
                tsRange (:, 2) double = []
                sync (:, 1) spiky.core.Sync = spiky.core.Sync
            end
            
            obj.Name = name;
            obj.Type = type;
            obj.Events = spiky.core.ObjArray(events);
            obj.TsRange = tsRange;
            obj.Sync = sync;
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