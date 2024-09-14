classdef Neuron

    properties
        Session spiky.ephys.Session
        Group double
        Id double
        Region string
        Ch double
        ChInGroup double
        Label string
        Waveform double
    end

    properties (Dependent)
        Str string
    end

    methods
        function obj = Neuron(session, group, id, region, ch, chInGroup, label, waveform)
            arguments
                session spiky.ephys.Session = spiky.ephys.Session.empty
                group double = 0
                id double = 0
                region string = ""
                ch double = 0
                chInGroup double = 0
                label string = ""
                waveform double = 0
            end
            obj.Session = session;
            obj.Group = group;
            obj.Id = id;
            obj.Region = region;
            obj.Ch = ch;
            obj.ChInGroup = chInGroup;
            obj.Label = label;
            obj.Waveform = waveform;
        end

        function str = get.Str(obj)
            str = sprintf("%s_%s_%d", obj.Session.Name, obj.Region, obj.Id);
        end

        function out = eq(obj, other)
            out = obj.Session == other.Session & obj.Group == other.Group & obj.Id == other.Id;
        end
    end
end