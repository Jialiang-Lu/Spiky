classdef Session < spiky.core.Metadata
    %SESSION information about a recording session.

    properties (SetAccess = {?spiky.core.Metadata, ?spiky.ephys.Session})
        Name string
    end

    properties (Dependent)
        Fdir string
    end

    methods
        function obj = Session(name)
            % Constructor for Session class.
            % name: name of the session
            
            arguments
                name string = ""
            end
            
            if name==""
                return
            end
            obj.Name = name;
        end

        function fdir = get.Fdir(obj)
            fdir = fullfile(spiky.config.loadConfig("fdirData"), obj.Name);
        end

        function out = eq(obj, other)
            %EQ Compare two sessions.
            out = obj.Name == other.Name;
        end

        function fpth = getFpth(obj, type)
            %GETFPTH Get the Fpth to a file of a given type.
            fpth = fullfile(obj.Fdir, obj.Name + "." + type);
        end

        function fdir = getFdir(obj, subdirs)
            %GETFDIR Get the Fdir of a subdirectory.
            arguments
                obj spiky.ephys.Session
            end
            arguments (Repeating)
                subdirs string
            end
            fdir = fullfile(obj.Fdir, subdirs{:});
        end

        function info = getInfo(obj)
            %GETINFO Get the session info.
            info = obj.loadData("spiky.ephys.SessionInfo.mat");
            if ~exist(info.FpthDat(1), "file")
                for ii = 1:numel(info.FpthDat)
                    info.FpthDat(ii) = fullfile(obj.Fdir, extractAfter(info.FpthDat(ii), obj.Name));
                end
                for ii = 1:numel(info.FpthLfp)
                    info.FpthLfp(ii) = fullfile(obj.Fdir, extractAfter(info.FpthLfp(ii), obj.Name));
                end
                obj.saveMetaData(info);
            end
        end

        function [spikes, units] = getSpikes(obj, options)
            %GETSPIKES Get the spikes of the session.
            %   [spikes, units] = getSpikes(obj, ...)
            %
            %   Name-value arguments:
            %       ConvertRegionNames: whether to convert region names using brainRegionMap
            %       RegionSubset: subset of regions to keep
            arguments
                obj spiky.ephys.Session
                options.ConvertRegionNames (1, 1) logical = true
                options.RegionSubset string = string.empty
            end
            spikes = obj.loadData("spiky.ephys.SpikeInfo.mat");
            spikes = spikes.Spikes;
            units = vertcat(spikes.Neuron);
            for ii = 1:height(spikes)
                spikes(ii).Neuron.Waveform{1} = []; % clear waveform to save memory
            end
            if options.ConvertRegionNames
                map = spiky.config.loadConfig("brainRegionMap");
                [regions, ~, idcRegions] = unique(units.Region);
                regions = string(regions);
                regions = replace(regions, lineBoundary("start")+"l"|"r", "");
                names = string(fieldnames(map));
                for ii = 1:numel(names)
                    regions = replace(regions, names(ii), map.(names(ii)));
                end
                regions = categorical(regions);
                units.Region = regions(idcRegions);
                for ii = 1:height(spikes)
                    spikes(ii).Neuron.Region = units.Region(ii);
                end
            end
            if ~isempty(options.RegionSubset)
                idcKeep = ismember(units.Region, options.RegionSubset);
                spikes = spikes(idcKeep, :);
                units = units(idcKeep, :);
            end
        end

        function minos = getMinos(obj)
            %GETMINOS Get the minos of the session.
            minos = obj.loadData("spiky.minos.MinosInfo.mat");
        end

        function tr = getTransform(obj)
            %GETTRANSFORM Get the transform of the session.
            tr = obj.loadData("spiky.minos.Transform.mat");
        end
        
        function info = processRaw(obj, options)
            arguments
                obj spiky.ephys.Session
                options.FsLfp (1, 1) double = 1000
                options.Period (1, 2) double = [0 Inf]
                options.BrainRegions string = "brain"
                options.ChannelConfig = []
                options.Probe = "NP1032"
                options.MainProbe (1, 1) double = 1
                options.ResampleDat (1, 1) logical = false
                options.ResampleLfp (1, 1) logical = true
                options.Plot (1, 1) logical = true
            end
            
            %% Load configuration
            if ~isa(options.ChannelConfig, "spiky.ephys.ChannelConfig")
                configs = spiky.config.loadConfig("channelConfig");
                if isempty(options.ChannelConfig)
                    names = fieldnames(configs);
                    options.ChannelConfig = spiky.ephys.ChannelConfig.read(configs.(names{end}));
                elseif isnumeric(options.ChannelConfig)
                    options.ChannelConfig = spiky.ephys.ChannelConfig.read(configs.(sprintf("v%d", ...
                        options.ChannelConfig)));
                elseif isstring(options.ChannelConfig)
                    options.ChannelConfig = spiky.ephys.ChannelConfig.read(configs.(options.ChannelConfig));
                else
                    names = fieldnames(configs);
                    options.ChannelConfig = spiky.ephys.ChannelConfig.read(configs.(names{end}));
                end
            end
            if ~isa(options.Probe, "spiky.ephys.Probe")
                options.Probe = spiky.config.loadProbe(options.Probe);
            end
            options.BrainRegions = options.BrainRegions(:);
            if isscalar(options.Probe)&&~isscalar(options.BrainRegions)
                options.Probe = repmat(options.Probe, length(options.BrainRegions), 1);
            end

            %% Load Raw
            rawData = spiky.ephys.RawData(obj.getFdir("Raw"));
            eventGroups = rawData.getEvents(options.ChannelConfig.Dig, plot=options.Plot);
            channelGroups = rawData.getChannels(options.BrainRegions, options.Probe, ...
                options.ChannelConfig.Adc);
            [nSamples, nSamplesLfp, fpthDat] = rawData.resampleRaw(obj.getFpth("dat"), obj.getFpth("lfp"), ...
                options.Probe, options.FsLfp, options.ResampleDat, options.ResampleLfp, [eventGroups(1:end-1).Sync]);
            info = spiky.ephys.SessionInfo(obj, sum([channelGroups.NChannels]), 30000, options.FsLfp, ...
                nSamples, nSamplesLfp, nSamples/30000, "int16", fpthDat, ...
                obj.getFpth("lfp"), channelGroups, eventGroups, options);
            info.createNsXml();
            obj.saveMetaData(info);
        end

        function varargout = loadData(obj, type, varargin)
            %   type: type of data to load
            %
            %   Examples:
            %   loadData(fn, "session.mat")
            %   loadData(fn, "dat", chs, period, precisionOut, precisionIn)
            fpth = obj.getFpth(type);
            [~, ~, fext] = fileparts(fpth);
            switch fext
                case {".dat", ".lfp", ".bin", ".fil"}
                    [data, chInfo] = loadBinary(fn, type, varargin{:});
                    varargout{1} = data;
                    if nargout>1
                        varargout{2} = chInfo;
                    end
                case {".mat"}
                    varargout{1} = spiky.core.Metadata.load(fpth);
                case {".xml"}
                    varargout{1} = readstruct(fpth);
                otherwise
                    error("Unkown file type specified!")
            end
        end

        function saveMetaData(obj, data)
            %SAVEMETADATA saves metadata to a file
            %
            %   data: metadata to save
            arguments
                obj spiky.ephys.Session
                data spiky.core.Metadata
            end

            data.save(obj.getFpth(class(data)+".mat"));
        end

        function [data, chInfo] = loadBinary(obj, type, chs, period, precisionOut, precisionIn)
            %LOADBINARY loads binary data into memory by default using memory mapping
            %
            %   type: dat, lfp or other file extensions
            %   chs: channels to load
            %   period: time period to load [beg fin] (s) or indices (#sample)
            %   precisionOut: format of returned data
            %   precisionIn: format of stored data
            %
            %   data: binary data
            %   chInfo: info about each channel of the data
            
            arguments
                obj spiky.ephys.Session
                type string = "lfp"
                chs double = []
                period = [0 Inf]
                precisionOut string = "int16"
                precisionIn string = "int16"
            end
            if type~="lfp"
                error("Not implemented yet!")
            end
            fpth = obj.getFpth(type);

            %% Preprocessing
            info = obj.loadData("info.mat");
            [~, ~, ext] = fileparts(fpth);
            type = ext(2:end);
            switch type
                case "dat"
                    fs = info.fs;
                    nSample = info.nSample;
                    nCh = info.nCh;
                case "lfp"
                    fs = info.fsLfp;
                    nSample = info.nSampleLfp;
                    nCh = info.nCh;
                otherwise
                    error("Unknown binary file extension!")
            end
            chInfo = info.chs;
            if isempty(chs)
                chs = find(strcmp(chInfo.type, "ch"));
            elseif ischar(chs)
                chs = {chs};
            elseif isnumeric(chs)
                chs = chs';
            end
            if iscell(chs)
                ch2 = [];
                for k = 1:numel(chs)
                    if isnumeric(chs{k})
                        ch2 = [ch2; chs{k}];
                    else
                        ch2 = [ch2; find(startsWith(chInfo.name, chs{k}))];
                    end
                end
                chs = ch2;
            end
            nChLoad = length(chs);
            if isscalar(period)
                period = [0 period];
            end
            if length(period)<=2
                period = round(period*fs);
                period = [max(period(1), 1) min(period(2), nSample)];
                nSampleLoad = diff(period)+1;
                idc = period(1):period(2);
            else
                idc = period(:)';
                nSampleLoad = length(idc);
            end
            
            %% Load data
            data = zeros(nChLoad, nSampleLoad, precisionOut);
            m = memmapfile(fpth, "Format", {precisionIn, [nCh nSample], "m"}, ...
                "Writable", false);
            data(:, :) = m.Data.m(chs, idc);
            if isfloat(data)
                data = data.*chInfo.bitVolts(chs).*chInfo.toMv(chs);
            end
            chInfo = chInfo(chs, :);
            
            end
            
    end
end