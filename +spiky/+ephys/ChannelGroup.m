classdef ChannelGroup < spiky.core.Metadata & spiky.core.MappableArray
    % CHANNELGROUP Class representing a group of channels
    
    properties %(SetAccess = {?spiky.core.Metadata, ?spiky.ephys.ChannelGroup})
        Name string
        NChannels (1, 1) double
        ChannelType (1, 1) spiky.ephys.ChannelType = spiky.ephys.ChannelType.Neural
        ChannelNames (:, 1) string
        Probe spiky.ephys.Probe
        BitVolts (1, 1) double
        ToMv (1, 1) double
    end

    methods (Static)
        function obj = createExtGroup(channelType, channelNames, bitVolts, toMv)
            arguments
                channelType spiky.ephys.ChannelType
                channelNames (:, 1) string
                bitVolts (1, 1) double = 0.195
                toMv (1, 1) double = 1e-3
            end
            nChannels = numel(channelNames);
            probe = spiky.ephys.Probe.empty();
            obj = spiky.ephys.ChannelGroup(string(channelType), nChannels, channelType, channelNames, probe, bitVolts, toMv);
        end
    end

    methods
        function obj = ChannelGroup(name, nChannels, channelType, channelNames, probe, ...
            bitVolts, toMv)
            % CHANNELGROUP Create a new instance of ChannelGroup

            arguments
                name string = ""
                nChannels (1, 1) double = 0
                channelType (1, 1) spiky.ephys.ChannelType = spiky.ephys.ChannelType.Neural
                channelNames (:, 1) string = ""
                probe spiky.ephys.Probe = spiky.ephys.Probe.empty
                bitVolts (1, 1) double = 0.195
                toMv (1, 1) double = 1e-3
            end

            obj.Name = name;
            obj.NChannels = nChannels;
            obj.ChannelType = channelType;
            obj.ChannelNames = channelNames;
            if isempty(probe)
                probe = spiky.ephys.Probe.empty();
            end
            obj.Probe = probe;
            obj.BitVolts = bitVolts;
            obj.ToMv = toMv;
        end

        function [ch, idcGroup] = getChannel(obj, idc)
            % GETCHANNEL Get a channel by index

            arguments
                obj spiky.ephys.ChannelGroup
                idc double
            end

            chs = [obj.NChannels]';
            chsCum = [0; cumsum(chs)];
            periods = spiky.core.Periods([chsCum(1:end-1)+1, chsCum(2:end)]);
            [ch, ~, idcGroup] = periods.haveEvents(idc, false, 0, true, false);
            ch = ch+1;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end