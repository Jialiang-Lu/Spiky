classdef Session < spiky.core.Metadata
    % SESSION information about a recording session.

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
            % EQ Compare two sessions.
            out = obj.Name == other.Name;
        end

        function fpth = getFpth(obj, type)
            % GETFPTH Get the Fpth to a file of a given type.
            fpth = fullfile(obj.Fdir, obj.Name + "." + type);
        end

        function fdir = getFdir(obj, subdirs)
            % GETFDIR Get the Fdir of a subdirectory.
            arguments
                obj spiky.ephys.Session
            end
            arguments (Repeating)
                subdirs string
            end
            fdir = fullfile(obj.Fdir, subdirs{:});
        end

        function info = getInfo(obj)
            % GETINFO Get the session info.
            info = obj.loadData("spiky.ephys.SessionInfo.mat");
        end

        function spikes = getSpikes(obj)
            % GETSPIKES Get the spikes of the session.
            spikes = obj.loadData("spiky.ephys.SpikeInfo.mat");
        end

        function minos = getMinos(obj)
            % GETMINOS Get the minos of the session.
            minos = obj.loadData("spiky.minos.MinosInfo.mat");
        end
        
        function info = processRaw(obj, options)
            arguments
                obj spiky.ephys.Session
                options.fsLfp (1, 1) double = 1000
                options.period (1, 2) double = [0 Inf]
                options.brainRegions string = "brain"
                options.channelConfig = []
                options.probe = "NP1030"
                options.mainProbe (1, 1) double = 1
                options.resampleDat (1, 1) logical = false
                options.resampleLfp (1, 1) logical = true
            end
            
            %% Load configuration
            if ~isa(options.channelConfig, "spiky.ephys.ChannelConfig")
                configs = spiky.config.loadConfig("channelConfig");
                if isempty(options.channelConfig)
                    names = fieldnames(configs);
                    options.channelConfig = spiky.ephys.ChannelConfig.read(configs.(names{end}));
                elseif isnumeric(options.channelConfig)
                    options.channelConfig = spiky.ephys.ChannelConfig.read(configs.(sprintf("v%d", ...
                        options.channelConfig)));
                elseif isstring(options.channelConfig)
                    options.channelConfig = spiky.ephys.ChannelConfig.read(configs.(options.channelConfig));
                else
                    names = fieldnames(configs);
                    options.channelConfig = spiky.ephys.ChannelConfig.read(configs.(names{end}));
                end
            end
            if ~isa(options.probe, "spiky.ephys.Probe")
                options.probe = spiky.config.loadProbe(options.probe);
            end
            options.brainRegions = options.brainRegions(:);
            if isscalar(options.probe)&&~isscalar(options.brainRegions)
                options.probe = repmat(options.probe, length(options.brainRegions), 1);
            end

            %% Load raw
            % rawData = spiky.ephys.RawData(obj.getFdir("Raw"));
            % eventGroups = rawData.getEvents(options.channelConfig.Dig);
            % channelGroups = rawData.getChannels(options.brainRegions, options.probe, ...
            %     options.channelConfig.Adc);
            % [nSample, nSampleLfp] = rawData.resampleRaw(obj.getFpth("dat"), obj.getFpth("lfp"), ...
            %     options.probe, options.fsLfp);
            % info = spiky.ephys.SessionInfo(obj, sum([channelGroups.NChannels]), 30000, options.fsLfp, ...
            %     nSample, nSampleLfp, nSample/30000, "int16", obj.getFpth("dat"), ...
            %     obj.getFpth("lfp"), channelGroups, eventGroups, options);
            % obj.saveMetaData(info);

            %% Detect type
            fi = spiky.core.FileInfo(obj.getFdir("Raw", "**/*.continuous"));
            if ~isempty(fi)
                % OpenEphys format
                error("spiky:NotImplemented", "OpenEphys format not implemented yet!")
            end
            fi = spiky.core.FileInfo(obj.getFdir("Raw", "**/settings.xml"));
            if ~isempty(fi)
                % OpenEphys binary format
                fdirOe = fi.Folder;
                fdirRaw = fullfile(fdirOe, "experiment1", "recording1");
                copyfile(fi.Path, obj.getFpth("oe.xml"));
                fdirRawCont = fullfile(fdirRaw, "continuous");
                fdirRawEvents = fullfile(fdirRaw, "events");
                fiCont = spiky.core.FileInfo(fdirRawCont);
                oeStruct = readstruct(fullfile(fdirRaw, "structure.oebin"), "FileType", "json");
                if any(startsWith([fiCont.Name], "Neuropix")) % Neuropixels
                    %% Info
                    nProbes = sum(startsWith([fiCont.Name], "Neuropix"))/2;
                    idxMainProbe = 1;
                    if options.mainProbe>1
                        idc = 1:nProbes*2;
                        idxMainProbe = (options.mainProbe-1)*2+1;
                        idc = [(0:1)+idxMainProbe idc(ceil(idc/2)~=options.mainProbe)];
                        fiCont = fiCont([idc end]);
                        idc1 = 1:nProbes;
                        idc1 = [options.mainProbe idc1(idc1~=options.mainProbe)];
                        options.brainRegions = options.brainRegions(idc1);
                    end
                    if isscalar(options.probe)&&nProbes>1
                        options.probe = repmat(options.probe, nProbes, 1);
                    end
                    fdirsAp = [fiCont(1:2:end-1).Path]';
                    fdirsLfp = [fiCont(2:2:end-1).Path]';
                    fdirDaq = fiCont(end).Path;
                    fpthsAp = fdirsAp+filesep+"continuous.dat";
                    fpthsLfp = fdirsLfp+filesep+"continuous.dat";
                    fpthDaq = fdirDaq+filesep+"continuous.dat";
                    fdirsEvents = fullfile(fdirRawEvents, [fiCont(1:2:end-1).Name]', "TTL");
                    nCh1 = oeStruct.continuous(idxMainProbe).num_channels;
                    fs = oeStruct.continuous(idxMainProbe).sample_rate;
                    fsLfp1 = oeStruct.continuous(idxMainProbe+1).sample_rate;
                    fsDaq1 = oeStruct.continuous(end).sample_rate;
                    tsRanges = zeros(nProbes, 2, "int64");
                    tsRangesLfp = zeros(nProbes, 2, "int64");
                    for ii = 1:nProbes
                        tsRanges(ii, :) = spiky.utils.npy.memmapNPY( ...
                            fullfile(fdirsAp{ii}, "sample_numbers.npy")).Data.m([1 end]);
                        tsRangesLfp(ii, :) = spiky.utils.npy.memmapNPY( ...
                            fullfile(fdirsLfp{ii}, "sample_numbers.npy")).Data.m([1 end]);
                    end
                    tsRangeDaq = spiky.utils.npy.memmapNPY(fullfile(fdirDaq, ...
                        "sample_numbers.npy")).Data.m([1 end])';
                    fsLfp = options.fsLfp;
                    fsDaq = fsDaq1;
                    nSamples1 = double(diff(tsRanges, 1, 2)+1);
                    nSamplesLfp1 = double(diff(tsRangesLfp, 1, 2)+1);
                    nSample = nSamples1(1);
                    nSampleLfp1 = double(tsRangesLfp(1, 2)-tsRangesLfp(1, 1)+1);
                    nCh = 384*nProbes;
                    duration = double(nSample-1)./fs;
                    nSampleDaq1 = double(tsRangeDaq(2)-tsRangeDaq(1)+1);
                    nChDaq = 8;
                    nChAll = nCh+nChDaq;
                    channelGroupsAdc = spiky.ephys.ChannelGroup.createExtGroup(spiky.ephys.ChannelType.Adc, ...
                        options.channelConfig.Adc, oeStruct.continuous(end).channels(1).bit_volts, 1000);
                    for ii = nProbes:-1:1
                        channelGroups(ii, 1) = spiky.ephys.ChannelGroup(options.brainRegions(ii), nCh1, ...
                            spiky.ephys.ChannelType.Neural, options.brainRegions(ii), options.probe(ii), ...
                            oeStruct.continuous(ii*2-1).channels(1).bit_volts, 0.001);
                    end
                    channelGroups(nProbes+1, 1) = channelGroupsAdc;
                    %% Sync
                    events = spiky.ephys.RecEvent.load(fullfile(fdirRawEvents, fiCont(end).Name, "TTL"), ...
                        options.channelConfig.Dig, tsRangeDaq(1), fsDaq);
                    eventsNet = spiky.ephys.RecEvent.load(fullfile(fdirRawEvents, "MessageCenter"), [], ...
                        tsRangeDaq(1), fsDaq);
                    eventsSync = events([events.ChannelName]=="Sync");
                    eventsProbe = cell(nProbes, 1);
                    for ii = 1:nProbes
                        eventsProbe{ii} = spiky.ephys.RecEvent.load(fdirsEvents(ii), ...
                            options.channelConfig.Dig, tsRanges(ii, 1), fs);
                    end
                    if nProbes>1
                        for ii = nProbes:-1:2
                            [sync2, eventsProbe2] = eventsProbe{1}.syncWith(eventsProbe{ii}, ...
                                sprintf("probe1 to probe%d", ii));
                            eventGroups(ii, 1) = spiky.ephys.EventGroup(sprintf("Probe%d", ii), ...
                                spiky.ephys.ChannelType.Neural, eventsProbe2, tsRanges(ii, :), sync2);
                        end
                    end
                    eventGroups(1, 1) = spiky.ephys.EventGroup("Probe1", ...
                        spiky.ephys.ChannelType.Neural, eventsProbe{1}, tsRanges(1, :));
                    sync2 = eventsProbe{1}.syncWith(eventsSync, "probe1 to adc");
                    eventGroups(nProbes+1, 1) = spiky.ephys.EventGroup("Adc", ...
                        spiky.ephys.ChannelType.Adc, events.syncTime(sync2.Inv), tsRangeDaq, sync2);
                    eventsSyncNet = eventsNet(contains([eventsNet.Message], ["Sync" "sync"]));
                    if eventsSyncNet(1).Message==eventsSyncNet(2).Message
                        eventsSyncNet = eventsSyncNet(1:2:end);
                    end
                    tokens = regexp([eventsSyncNet.Message]', "(\w+) (\d+) (\d+)", "tokens");
                    tokens = cat(1, tokens{:});
                    tokens = cat(1, tokens{:});
                    idcNet = double(tokens(:, 2));
                    eventsProbeSync = eventsProbe{1}(1:2:end);
                    eventsProbeSync = eventsProbeSync(idcNet+1);
                    sync2 = eventsProbeSync.syncWith(eventsSyncNet, "probe1 to net");
                    eventGroups(nProbes+2) = spiky.ephys.EventGroup("Net", ...
                        spiky.ephys.ChannelType.Net, eventsNet.syncTime(sync2.Inv), ...
                        tsRangeDaq, sync2);
                    %% Resample raw
                    if false%options.resampleDat
                        fpthDat = obj.getFpth("dat");
                        mem = memory;
                        chunkSize = floor(mem.MaxPossibleArrayBytes*0.2./nCh/8);
                        nChunks = ceil(nSample/chunkSize);
                        data = zeros(nCh, chunkSize);
                        fid = fopen(fpthDat, "w");
                        %%
                        spiky.plot.timedWaitbar(0, "Resampling raw data");
                        for ii = 1:nChunks
                            idc = (1:chunkSize)+(ii-1)*chunkSize;
                            idc(idc>nSample) = [];
                            nIdc = length(idc);
                            mf = memmapfile(fpthsAp(1), Format={"int16", ...
                                [nCh1 nSamples1(1)], "m"});
                            data(1:length(channelGroups(1).Probe.ChanMap), 1:nIdc) = ...
                                mf.Data.m(channelGroups(1).Probe.ChanMap, idc);
                            for jj = 2:nProbes
                                idcK = eventGroups(jj).Sync.Fit((idc-1)./fs).*fs+1;
                                idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                                idcK2(idcK2<=0) = [];
                                idcK2(idcK2>nSamples1(jj)) = [];
                                idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                                mf = memmapfile(fpthsAp(jj), Format={"int16", ...
                                    [nCh1 nSamples1(jj)], "m"});
                                dataK = interp1(double(mf.Data.m(channelGroups(jj).Probe.ChanMap, ...
                                    idcK2)'), idcKOff, "linear", 0)';
                                data((1:length(channelGroups(jj).Probe.ChanMap))+384*(jj-1), ...
                                    1:nIdc) = dataK;
                            end
                            if ii~=nChunks
                                fwrite(fid, data, "int16");
                            else
                                fwrite(fid, data(:, 1:nIdc), "int16");
                            end
                            spiky.plot.timedWaitbar(ii/nChunks);
                        end
                        fclose(fid);
                    else
                        fpthDat = fpthsAp;
                    end
                    %% Resample LFP
                    fpthLfp = obj.getFpth("lfp");
                    if false%options.resampleLfp
                        ratio = fsLfp1/fsLfp;
                        [p, q] = rat(1/ratio);
                        mf1 = memmapfile(fpthsLfp(1), Format={"int16", [nCh1 nSampleLfp1], "m"});
                        tmp1 = resample(double(mf1.Data.m(1, :)), p, q);
                        nSampleLfp = length(tmp1);
                        data = zeros(nChAll, nSampleLfp, "int16");
                        mem = memory;
                        groupSize = floor(mem.MaxPossibleArrayBytes*0.2./nSampleLfp1/8);
                        [nGroupPerProbe, groupSize] = spiky.utils.equalDiv(384, groupSize);
                        %%
                        for ii = 1:nProbes
                            spiky.plot.timedWaitbar(0, "Resampling LFP");
                            mf = memmapfile(fpthsLfp(ii), Format={"int16", [nCh1 nSamplesLfp1(ii)], "m"});
                            if ii>1
                                idcK = eventGroups(ii).Sync.Fit((0:nSamplesLfp1(1)-1)./fsLfp1).*fsLfp1+1;
                                idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                                idcK2(idcK2<=0) = [];
                                idcK2(idcK2>nSamplesLfp1(ii)) = [];
                                idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                            end
                            for jj = 1:nGroupPerProbe
                                idcCh = (1:groupSize)+(jj-1)*groupSize;
                                idcInGroup = channelGroups(ii).Probe.ChanMap(idcCh);
                                idcInOut = idcCh+(ii-1)*384;
                                if ii==1
                                    tmp = double(mf.Data.m(idcInGroup, :))';
                                else
                                    tmp = interp1(double(mf.Data.m(idcInGroup, idcK2)'), idcKOff, "linear", 0);
                                end
                                data(idcInOut, :) = int16(resample(tmp, p, q))';
                                spiky.plot.timedWaitbar(((ii-1)*nGroupPerProbe+jj)/(nGroupPerProbe*nProbes));
                            end
                        end
                        %%
                        mf = memmapfile(fpthDaq, Format={"int16", [nChDaq nSampleDaq1], "m"});
                        tmp = double(mf.Data.m)';
                        tmp = medfilt1(tmp, ceil(fsDaq/fsLfp));
                        idcK = eventGroups("Adc").Sync.Fit((0:nSampleLfp-1)./fsLfp).*fsDaq+1;
                        idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                        idcK2(idcK2<=0) = [];
                        idcK2(idcK2>nSampleDaq1) = [];
                        idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                        tmp = interp1(tmp, idcKOff, "linear", 0);
                        data(end-nChDaq+1:end, :) = int16(tmp)';
                        %%
                        fid = fopen(fpthLfp, "w");
                        fwrite(fid, data, "int16");
                        fclose(fid);
                    else
                        nSampleLfp = nSampleLfp1;
                    end
                    %% Save
                    info = spiky.ephys.SessionInfo(obj, nChAll, fs, fsLfp, nSample, ...
                        nSampleLfp, duration, "int16", fpthDat, fpthLfp, channelGroups, ...
                        eventGroups, options);
                    obj.saveMetaData(info);
                else % Not neuropixels
                    error("Not implemented")
                end
            end
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