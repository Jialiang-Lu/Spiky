classdef ChannelGroup < spiky.core.MappableArray & spiky.core.Array
    %CHANNELGROUP Class representing a group of channels
    %
    %   Fields:
    %       Name: name of the channel group
    %       NChannels: number of channels in the group
    %       ChannelType: type of the channels
    %       ChannelNames: names of the channels
    %       Probe: probe information
    %       BitVolts: conversion factor from digital units to volts
    %       ToMv: conversion factor from raw to millivolts
    
    methods (Static)
        function obj = createExtGroup(channelType, channelNames, bitVolts, toMv)
            %CREATEEXTGROUP Create a standard external channel group
            arguments
                channelType spiky.ephys.ChannelType
                channelNames (:, 1) cell
                bitVolts (1, 1) double = 0.195
                toMv (1, 1) double = 1e-3
            end
            nChannels = numel(channelNames);
            probe = spiky.ephys.Probe();
            obj = spiky.ephys.ChannelGroup(string(channelType), nChannels, channelType, ...
                channelNames, probe, bitVolts, toMv);
        end
    end

    methods
        function obj = ChannelGroup(name, nChannels, channelType, channelNames, probe, ...
            bitVolts, toMv)
            %CHANNELGROUP Create a new instance of ChannelGroup
            arguments
                name (:, 1) string = string.empty
                nChannels (:, 1) double = []
                channelType (:, 1) spiky.ephys.ChannelType = spiky.ephys.ChannelType.empty
                channelNames (:, 1) cell = {}
                probe (:, 1) spiky.ephys.Probe = spiky.ephys.Probe.empty
                bitVolts (:, 1) double = [] % 0.195
                toMv (:, 1) double = [] % 1e-3
            end
            obj = obj.initTable(Name=name, NChannels=nChannels, ...
                ChannelType=channelType, ChannelNames=channelNames, ...
                Probe=probe, BitVolts=bitVolts, ToMv=toMv);
        end

        function [ch, idcGroup] = getChannel(obj, idc, resample)
            %GETCHANNEL Get a channel by index

            arguments
                obj spiky.ephys.ChannelGroup
                idc double
                resample = true
            end

            chs = [obj.NChannels]';
            chsCum = [0; cumsum(chs)];
            intervals = spiky.core.Intervals([chsCum(1:end-1)+1, chsCum(2:end)]);
            [ch, ~, idcGroup] = intervals.haveEvents(idc, CellMode=false, Offset=0, RightClose=true, Sorted=false);
            ch = ch+1;
            if ~resample
                groups = unique(idcGroup);
                for ii = 1:numel(groups)
                    idc1 = idcGroup==groups(ii);
                    ch(idc1) = obj(groups(ii)).Probe.ChanMap(ch(idc1));
                end
            end
        end

        function idc = getGroupIndices(obj, group)
            %GETGROUPINDICES Get indices of a group

            arguments
                obj spiky.ephys.ChannelGroup
                group double
            end

            chs = [obj.NChannels]';
            chsCum = [0; cumsum(chs)];
            idc = chsCum(group)+1:chsCum(group+1);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end