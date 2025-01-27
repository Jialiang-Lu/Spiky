classdef Neuron

    properties
        Session spiky.ephys.Session
        Group double
        Id double
        Region string
        Ch double
        ChInGroup double
        Label string
        Waveform spiky.lfp.Lfp
        Amplitude double
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
                waveform spiky.lfp.Lfp = spiky.lfp.Lfp.empty
            end
            obj.Session = session;
            obj.Group = group;
            obj.Id = id;
            obj.Region = region;
            obj.Ch = ch;
            obj.ChInGroup = chInGroup;
            obj.Label = label;
            obj.Waveform = waveform;
            if ~isempty(waveform)
                obj.Amplitude = max(waveform.Data) - min(waveform.Data);
            else
                obj.Amplitude = 0;
            end
        end

        function str = get.Str(obj)
            str = sprintf("%s_%s_%d", obj.Session.Name, obj.Region, obj.Id);
        end

        function out = eq(obj, other)
            out = obj.Session == other.Session & obj.Group == other.Group & obj.Id == other.Id;
        end

        function obj = updateFields(obj, s)
            if isfield(s, "Waveform")
                obj.Waveform = spiky.lfp.Lfp((length(s.Waveform)-1)/2/30000, 30000, s.Waveform);
            end
        end
    end
end