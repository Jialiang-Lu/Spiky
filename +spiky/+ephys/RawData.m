classdef RawData

    properties
        Fdir string
        Type string {mustBeMember(Type, ["Binary", "OpenEphys"])}
        Source string {mustBeMember(Source, ["Intan", "Npx"])}
        DatFiles spiky.core.FileInfo
        LfpFiles spiky.core.FileInfo
    end

    methods (Static)
        function [events, tsStart] = loadEvents(fpth, channelNames, tsStart, fs)
            %LOADEVENTS Load recorded events from file
            %
            %   fpth: path to the file/folder containing the events
            %   channelNames: names of the channels
            %   tsStart: start timestamp
            %   fs: sampling frequency

            arguments
                fpth string
                channelNames string = string.empty
                tsStart int64 = 0
                fs double = 30000
            end
            fi = spiky.core.FileInfo(fpth);
            events = spiky.ephys.RecEvents.empty;
            if exist(fpth, "dir")
                if isequal([fi.Name], "TTL")
                    fpth = fullfile(fpth, "TTL");
                end
                sn = spiky.utils.npy.readNPY(fullfile(fpth, "sample_numbers.npy"))-tsStart;
                if ~isempty(fs)
                    t = double(sn)./fs;
                else
                    t = double(sn);
                end
                if ~exist(fullfile(fpth, "text.npy"), "file")
                    % TTL
                    st = spiky.utils.npy.readNPY(fullfile(fpth, "states.npy"));
                    if isempty(channelNames)
                        channelNames = repmat("", max(abs(st)), 1);
                    end
                    events = spiky.ephys.RecEvents(t, sn, spiky.ephys.ChannelType.Dig, ...
                        abs(st), channelNames(abs(st)), st>0, "");
                else
                    % Network
                    txt = spiky.utils.npy.readNPY(fullfile(fpth, "text.npy"));
                    events = spiky.ephys.RecEvents(t, sn, spiky.ephys.ChannelType.Net, ...
                        0, "", true, string(txt));
                end
            elseif exist(fpth, "file")
                if fi.Name=="messages.events"
                    s = string(fileread(fi.Path));
                    tokens = regexp(s, "^(\d+), (.+?)$", "tokens", "lineanchors");
                    tokens = vertcat(tokens{:});
                    tsStart = spiky.utils.str2int(tokens(2, 1));
                    tokens = tokens(4:end, :);
                    ts = spiky.utils.str2int(tokens(:, 1))-tsStart;
                    t = double(ts)./fs;
                    events = spiky.ephys.RecEvents(t, ts, spiky.ephys.ChannelType.Net, ...
                        0, "", true, tokens(:, 2));
                else
                    n = (fi.Bytes-1024)/16;
                    if n~=round(n)
                        error("Invalid number of events in %s", fi(1).Path);
                    end
                    fid = fopen(fi(1).Path, "r");
                    fseek(fid, 1024, "bof");
                    ts = fread(fid, n, "int64=>int64", 8, "l")-tsStart;
                    fseek(fid, 1024+8+2+1+1, "bof");
                    state = fread(fid, n, "uint8=>uint8", 15, "n");
                    fseek(fid, 1024+8+2+1+1+1, "bof");
                    ch = fread(fid, n, "uint8=>uint8", 15, "n")+1;
                    if isempty(channelNames)
                        channelNames = repmat("", max(ch), 1);
                    end
                    t = double(ts)./fs;
                    events = spiky.ephys.RecEvents(t, ts, spiky.ephys.ChannelType.Dig, ...
                        ch, channelNames(ch), state>0, "");
                    fclose(fid);
                end
            end
        end
    end

    methods
        function obj = RawData(fdir)
            arguments
                fdir string {mustBeFolder}
            end

            obj.Fdir = fdir;
            fi = spiky.core.FileInfo(fullfile(fdir, "**/*.continuous"));
            if ~isempty(fi)
                obj.Type = "OpenEphys";
                fi = [spiky.core.FileInfo(fullfile(fdir, "**/*CH*.continuous"));
                    spiky.core.FileInfo(fullfile(fdir, "**/*ADC*.continuous"))];
                obj.DatFiles = fi;
                if any(contains([fi.Name], "Probe"))
                    obj.Source = "Npx";
                else
                    obj.Source = "Intan";
                end
                return
            end
            fi = spiky.core.FileInfo(fullfile(fdir, "**/*.dat"));
            if ~isempty(fi)
                obj.Type = "Binary";
                if any(contains([fi.Folder], "Neuropix"))
                    obj.Source = "Npx";
                    obj.DatFiles = fi([2:2:end 1]);
                    obj.LfpFiles = fi(3:2:end);
                else
                    obj.Source = "Intan";
                    obj.DatFiles = fi;
                end
                return
            end
            error("No raw data files found in %s", fdir);
        end

        function eventGroups = getEvents(obj, channelNames)
            % GETEVENTS Get events from the raw data
            %
            %   eventGroups = GETEVENTS(obj, channelNames)
            %
            %   channelNames: Names of the channels
            %
            %   eventGroups: Event groups

            arguments
                obj spiky.ephys.RawData
                channelNames string = string.empty
            end

            switch obj.Type
                case "OpenEphys"
                    fi = spiky.core.FileInfo(fullfile(obj.Fdir, "*.events"));
                    %% Network
                    [eventNet, tsStart] = spiky.ephys.RawData.loadEvents(fi(2).Path);
                    eventsAdc = spiky.ephys.RawData.loadEvents(fi(1).Path, channelNames, tsStart);
                    %% Combine
                    nSamples = (obj.DatFiles(1).Bytes-1024)/2070;
                    tsRange = [tsStart, tsStart+nSamples-1];
                    eventGroups(2, 1) = spiky.ephys.EventGroup("Net", ...
                        spiky.ephys.ChannelType.Net, eventNet, tsRange);
                    eventGroups(1, 1) = spiky.ephys.EventGroup("Adc", ...
                        spiky.ephys.ChannelType.Adc, eventsAdc, tsRange);
                case "Binary"
                    fi = spiky.core.FileInfo(fullfile(obj.Fdir, "experiment1", "recording1", "events/*"));
                    fiNet = fi(contains([fi.Name], "MessageCenter"));
                    if obj.Source=="Npx"
                        fiData = fi(contains([fi.Name], "Neuropix"+wildcardPattern+"-AP"));
                        fiAdc = fi(contains([fi.Name], "DAQmx"));
                        nFiles = length(obj.DatFiles)-1;
                    else
                        fiData = fi(contains([fi.Name], "Acquisition_Board"));
                        fiAdc = fiData;
                        nFiles = 1;
                    end
                    tsRanges = zeros(nFiles, 2, "int64");
                    for ii = 1:nFiles
                        tsRanges(ii, :) = spiky.utils.npy.memmapNPY( ...
                            fullfile(obj.DatFiles(ii).Folder, "sample_numbers.npy")).Data.m([1 end]);
                    end
                    tsRangesAdc = spiky.utils.npy.memmapNPY( ...
                        fullfile(obj.DatFiles(end).Folder, "sample_numbers.npy")).Data.m([1 end]);
                    eventsAdc = spiky.ephys.RawData.loadEvents(fiAdc.Path, channelNames, tsRangesAdc(1));
                    eventsNet = spiky.ephys.RawData.loadEvents(fiNet.Path, [], tsRangesAdc(1));
                    eventsSyncNet = eventsNet(contains([eventsNet.Message], ["Sync" "sync"]), :);
                    if eventsSyncNet.Message(1)==eventsSyncNet.Message(2)
                        eventsSyncNet = eventsSyncNet(1:2:end, :);
                    end
                    tokens = regexp(eventsSyncNet.Message, "(\w+) (\d+) (\d+)", "tokens");
                    tokens = cat(1, tokens{:});
                    tokens = cat(1, tokens{:});
                    idcNet = double(tokens(:, 2));
                    if obj.Source=="Npx"
                        events = cell(nFiles, 1);
                        for ii = 1:nFiles
                            events{ii} = spiky.ephys.RawData.loadEvents(fiData(ii).Path, "Sync", tsRanges(ii, 1));
                        end
                        if nFiles>1
                            for ii = nFiles:-1:2
                                [sync, events2] = events{1}.syncWith(events{ii}, ...
                                    sprintf("probe1 to probe%d", ii));
                                eventGroups(ii, 1) = spiky.ephys.EventGroup(sprintf("Probe%d", ii), ...
                                    spiky.ephys.ChannelType.Neural, events2, tsRanges(ii, :), sync);
                            end
                        end
                        eventGroups(1, 1) = spiky.ephys.EventGroup("Probe1", ...
                            spiky.ephys.ChannelType.Neural, events{1}, tsRanges(1, :));
                        sync = events{1}.syncWith(eventsAdc.Sync, "probe1 to adc");
                        eventGroups(end+1, 1) = spiky.ephys.EventGroup("Adc", ...
                            spiky.ephys.ChannelType.Adc, eventsAdc, tsRangesAdc, sync);
                    else
                        eventGroups(1, 1) = spiky.ephys.EventGroup("Adc", ...
                            spiky.ephys.ChannelType.Adc, eventsAdc, tsRangesAdc);
                    end
                    events1 = eventGroups(1).Events.Sync;
                    events1 = events1(events1.Rising, :);
                    events1 = events1(idcNet+1, :);
                    sync = events1.syncWith(eventsSyncNet, "probe1 to net");
                    eventGroups(end+1, 1) = spiky.ephys.EventGroup("Net", ...
                        spiky.ephys.ChannelType.Net, eventsNet, tsRangesAdc, sync);
            end
        end

        function [data, tsRange] = getContinuous(obj, ch, idc)
            % GETCONTINUOUS Get continuous data from the raw data
            %
            %   [data, tsRange] = GETCONTINUOUS(obj, ch)
            %   ch: Channel number
            %   idc: Indices of the data
            %
            %   data: Continuous data
            %   tsRange: Timestamp range
            
            arguments
                obj spiky.ephys.RawData
                ch double
                idc double = []
            end

            switch obj.Type
                case "OpenEphys"
                    if ch>length(obj.DatFiles)
                        error("Invalid channel %d", ch);
                    end
                    fi = obj.DatFiles(ch);
                    n = (fi.Bytes-1024)/2070;
                    if ~isempty(idc)
                        blockStart = floor((idc(1)-1)/1024)+1;
                        blockEnd = ceil(idc(end)/1024);
                        idxStart = (blockStart-1)*1024+1;
                        idxEnd = blockEnd*1024;
                        offsetStart = idc(1)-idxStart+1;
                        offsetEnd = idxEnd-idc(end);
                    end
                    if n~=round(n)
                        error("Invalid number of samples in %s", fi.Path);
                    end
                    fid = fopen(fi.Path, "r");
                    fseek(fid, 1024, "bof");
                    tsStart = fread(fid, 1, "int64=>int64", "l");
                    fseek(fid, -2070, "eof");
                    tsEnd = fread(fid, 1, "int64=>int64", "l")+1023;
                    if tsEnd-tsStart+1~=n*1024
                        error("Invalid number of samples in %s", fi.Path);
                    end
                    tsRange = [tsStart, tsEnd];
                    if isempty(idc)
                        fseek(fid, 1024, "bof");
                        data = fread(fid, Inf, "1024*int16=>int16", 22, "b");
                    else
                        fseek(fid, 1036+(blockStart-1)*2070, "bof");
                        data = fread(fid, (blockEnd-blockStart+1)*1024, "1024*int16=>int16", 22, "b");
                        if offsetStart~=1&&offsetEnd~=0
                            data = data(offsetStart:end-offsetEnd);
                        end
                    end
                    fclose(fid);
                case "Binary"
                    error("Not implemented yet")
            end
        end

        function channelGroups = getChannels(obj, brainRegions, probes, channelNames)
            
            arguments
                obj spiky.ephys.RawData
                brainRegions string
                probes spiky.ephys.Probe
                channelNames string = string.empty
            end

            switch obj.Type
                case "OpenEphys"
                    oeStruct = readstruct(fullfile(obj.Fdir, "structure.openephys"), FileType="xml");
                    nCh = length(obj.DatFiles);
                    nChs = [probes.NChannels]';
                    if nCh~=sum(nChs)+length(channelNames)
                        error("Invalid number of channels in %s", obj.Fdir);
                    end
                    nChsCum = [0; cumsum(nChs)];
                    nProbes = numel(probes);
                    if ~isempty(channelNames)
                        channelGroups(nProbes+1, 1) = spiky.ephys.ChannelGroup.createExtGroup(...
                        spiky.ephys.ChannelType.Adc, channelNames, ...
                        oeStruct.RECORDING.STREAM.CHANNEL(end).bitVoltsAttribute, 1000);
                    end
                    for ii = nProbes:-1:1
                        probe = probes(ii);
                        nChProbe = probe.NChannels;
                        probeChannel = oeStruct.RECORDING.STREAM.CHANNEL(nChsCum(ii)+1);
                        channelGroups(ii, 1) = spiky.ephys.ChannelGroup(brainRegions(ii), nChProbe, ...
                            spiky.ephys.ChannelType.Neural, brainRegions(ii), probe, ...
                            probeChannel.bitVoltsAttribute, 0.001);
                    end
                case "Binary"
                    oeStruct = readstruct(fullfile(obj.Fdir, "experiment1", "recording1", ...
                        "structure.oebin"), FileType="json");
                    nProbes = length(probes);
                    if obj.Source=="Npx"
                        for ii = nProbes:-1:1
                            channelGroups(ii, 1) = spiky.ephys.ChannelGroup(brainRegions(ii), ...
                                oeStruct.continuous(ii*2-1).num_channels, ...
                                spiky.ephys.ChannelType.Neural, brainRegions(ii), probes(ii), ...
                                oeStruct.continuous(ii*2-1).channels(1).bit_volts, 0.001);
                        end
                        channelGroups(nProbes+1, 1) = spiky.ephys.ChannelGroup.createExtGroup(...
                            spiky.ephys.ChannelType.Adc, channelNames, ...
                            oeStruct.continuous(end).channels(1).bit_volts, 1000);
                    else
                        nCh = oeStruct.continuous.num_channels;
                        nChAdc = nCh-sum([probes.NChannels]);
                        if nChAdc>0
                            if isempty(channelNames)
                                channelNames = strings(nChAdc, 1);
                            end
                            channelGroups(nProbes+1, 1) = spiky.ephys.ChannelGroup.createExtGroup(...
                                spiky.ephys.ChannelType.Adc, channelNames, ...
                                oeStruct.continuous.channels(end).bit_volts, 1000);
                        end
                        for ii = nProbes:-1:1
                            channelGroups(ii, 1) = spiky.ephys.ChannelGroup(brainRegions(ii), ...
                                probes(ii).NChannels, ...
                                spiky.ephys.ChannelType.Neural, brainRegions(ii), probes(ii), ...
                                oeStruct.continuous.channels(1).bit_volts, 0.001);
                        end
                    end
            end
        end

        function tsRange = getTsRange(obj, ch)
            arguments
                obj spiky.ephys.RawData
                ch double
            end

            switch obj.Type
                case "OpenEphys"
                    if ch>length(obj.DatFiles)
                        error("Invalid channel %d", ch);
                    end
                    fi = obj.DatFiles(ch);
                    fid = fopen(fi.Path, "r");
                    fseek(fid, -2070, "eof");
                    tsEnd = fread(fid, 1, "int64=>int64", "l")+1023;
                    fseek(fid, 1024, "bof");
                    tsStart = fread(fid, 1, "int64=>int64", "l");
                    tsRange = [tsStart, tsEnd];
                    fclose(fid);
                case "Binary"
                    error("Not implemented yet")
            end
        end

        function [nSamples, nSamplesLfp, fpthDat] = resampleRaw(obj, fpthDat, fpthLfp, probes, fsLfp, ...
            resampleDat, syncs)
            arguments
                obj spiky.ephys.RawData
                fpthDat string
                fpthLfp string
                probes spiky.ephys.Probe
                fsLfp double = 1000
                resampleDat logical = false
                syncs spiky.core.Sync = spiky.core.Sync.empty
            end

            switch obj.Type
                case "OpenEphys"
                    nSamples = (obj.DatFiles(1).Bytes-1024)/2070*1024;
                    if nSamples~=round(nSamples)
                        error("Invalid number of samples in %s", obj.DatFiles(1).Path);
                    end
                    %%
                    nCh = length(obj.DatFiles);
                    nChs = [probes.NChannels];
                    nChNeural = sum(nChs);
                    map = probes.toStruct(nCh);
                    [fdir, fn] = fileparts(fpthDat);
                    fpthMap = fullfile(fdir, fn+".map.mat");
                    probes.save(fpthMap, nCh, true);
                    nSamplePerChunk = ceil(memory().MaxPossibleArrayBytes*0.3/2/nCh/1024)*1024;
                    nChunks = ceil(nSamples/nSamplePerChunk);
                    delete(fpthDat);
                    rafile = java.io.RandomAccessFile(fpthDat, "rw");
                    rafile.setLength(nSamples*2*nCh);
                    rafile.close();
                    %%
                    spiky.plot.timedWaitbar(0, "Resampling raw");
                    for ii = 1:nChunks
                        idxStart = (ii-1)*nSamplePerChunk+1;
                        idxEnd = min(ii*nSamplePerChunk, nSamples);
                        raw = zeros(nCh, idxEnd-idxStart+1, "int16");
                        parfor jj = 1:nCh
                            chRaw = map.oeMap(jj);
                            raw(jj, :) = obj.getContinuous(chRaw, [idxStart, idxEnd])';
                            % fprintf("=");
                        end
                        % fprintf(newline);
                        clear mDat
                        mDat = memmapfile(fpthDat, Writable=true, Format={"int16", [nCh, nSamples], "m"});
                        mDat.Data.m(:, idxStart:idxEnd) = raw;
                        spiky.plot.timedWaitbar(ii/nChunks);
                    end
                    %%
                    spiky.plot.timedWaitbar(0, "Resampling lfp");
                    nSamplesLfp = ceil(nSamples/30000*fsLfp);
                    nChPerGroup = 8;
                    nGroups = ceil(nChNeural/nChPerGroup);
                    lfp = zeros(nCh, nSamplesLfp, "int16");
                    raw = zeros(nChPerGroup, nSamples, "int16");
                    for ii = 1:nGroups
                        idxStart = (ii-1)*nChPerGroup+1;
                        idxEnd = min(ii*nChPerGroup, nChNeural);
                        chRaw = map.oeMap(idxStart:idxEnd);
                        parfor jj = 1:length(chRaw)
                            raw(jj, :) = obj.getContinuous(chRaw(jj))';
                            % fprintf("=");
                        end
                        % fprintf(newline);
                        lfp(idxStart:idxEnd, :) = obj.resampleLfp(raw, 30000, fsLfp);
                        spiky.plot.timedWaitbar(ii/nGroups);
                    end
                    if nCh>nChNeural
                        chRaw = map.oeMap(nChNeural+1:end);
                        parfor jj = 1:length(chRaw)
                            raw(jj, :) = obj.getContinuous(chRaw(jj))';
                            fprintf("=");
                        end
                        lfp(nChNeural+1:end, :) = obj.resampleLfp(raw, 30000, fsLfp, true);
                        fprintf(newline);
                    end
                    fidLfp = fopen(fpthLfp, "w");
                    fwrite(fidLfp, lfp, "int16");
                    fclose(fidLfp);
                case "Binary"
                    if obj.Source=="Npx"
                        if resampleDat
                            error("Not implemented")
                        end
                        nSamples = obj.DatFiles(1).Bytes/2/384;
                        %% LFP
                        ratio = 2500/fsLfp;
                        [p, q] = rat(1/ratio);
                        nProbes = length(probes);
                        nChRaw = 384;
                        nSamplesRaw = [obj.LfpFiles.Bytes]'/2/nChRaw;
                        if nSamplesRaw~=round(nSamplesRaw)
                            nChRaw = 385;
                            nSamplesRaw = [obj.LfpFiles.Bytes]'/2/nChRaw;
                        end
                        nSamplesLfp = ceil(nSamplesRaw(1)/ratio);
                        nSamplesAdc = obj.DatFiles(end).Bytes/2/8;
                        nChAll = nProbes*384+8;
                        lfp = zeros(nChAll, nSamplesLfp, "int16");
                        mem = memory();
                        groupSize = floor(mem.MaxPossibleArrayBytes*0.2/nSamplesRaw(1)/8);
                        [nGroupPerProbe, groupSize] = spiky.utils.equalDiv(384, groupSize);
                        for ii = 1:nProbes
                            spiky.plot.timedWaitbar(0, "Resampling LFP");
                            mf = memmapfile(obj.LfpFiles(ii).Path, ...
                                Format={"int16", [nChRaw nSamplesRaw(ii)], "m"});
                            if ii>1
                                idcK = syncs(ii-1).Fit((0:nSamplesRaw(1)-1)./2500).*2500+1;
                                idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                                idcK2(idcK2<=0) = [];
                                idcK2(idcK2>nSamplesRaw(ii)) = [];
                                idcKOff = idcK-idcK2(1)+1; % make loaded lfp start from 1 for interpolation
                            end
                            for jj = 1:nGroupPerProbe
                                idcCh = (1:groupSize)+(jj-1)*groupSize;
                                idcInGroup = probes(ii).ChanMap(idcCh);
                                idcInOut = idcCh+(ii-1)*384;
                                if ii==1
                                    tmp = double(mf.Data.m(idcInGroup, :))';
                                else
                                    tmp = interp1(double(mf.Data.m(idcInGroup, idcK2)'), idcKOff, "linear", 0);
                                end
                                lfp(idcInOut, :) = int16(resample(tmp, p, q))';
                                spiky.plot.timedWaitbar(((ii-1)*nGroupPerProbe+jj)/(nGroupPerProbe*nProbes));
                            end
                        end
                        mf = memmapfile(obj.DatFiles(end).Path, Format={"int16", [8 nSamplesAdc], "m"});
                        tmp = double(mf.Data.m)';
                        tmp = medfilt1(tmp, ceil(30000/fsLfp));
                        idcK = syncs(end).Fit((0:nSamplesLfp-1)./fsLfp).*30000+1;
                        idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                        idcK2(idcK2<=0) = [];
                        idcK2(idcK2>nSamplesAdc) = [];
                        idcKOff = idcK-idcK2(1)+1; % make loaded lfp start from 1 for interpolation
                        tmp = interp1(tmp, idcKOff, "linear", 0);
                        lfp(end-8+1:end, :) = int16(tmp)';
                        fidLfp = fopen(fpthLfp, "w");
                        fwrite(fidLfp, lfp, "int16");
                        fclose(fidLfp);
                        else
                        error("Not implemented")
                    end
                fpthDat = [obj.DatFiles(1:end-1).Path]';
            end
        end
    end

    methods (Static)
        function lfp = resampleLfp(data, fs, fsLfp, useMedFilt, sync)
            arguments
                data int16
                fs double
                fsLfp double
                useMedFilt logical = false
                sync = []
            end
            
            if size(data, 2)>size(data, 1)
                data = data';
            end
            if ~useMedFilt
                if ~isempty(sync)
                end
                [p, q] = rat(fsLfp/fs);
                if isempty(sync)
                    data = double(data);
                else
                    idcK = sync((0:length(data)-1)./fs).*fs+1;
                    idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                    idcK2(idcK2<=0) = [];
                    idcK2(idcK2>nSamples(ii)) = [];
                    idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                    data = interp1(double(data(idcK2, :)), idcKOff, "linear", 0);
                end
                lfp = int16(resample(data, p, q))';
            else
                data = medfilt1(double(data), ceil(fs/fsLfp));
                nSamplesLfp = ceil(length(data)/fs*fsLfp);
                if isempty(sync)
                    idcK = (0:nSamplesLfp-1)./fsLfp.*fs+1;
                else
                    idcK = sync((0:nSamplesLfp-1)./fsLfp).*fs+1;
                end
                idcK2 = round(idcK(1)-3):round(idcK(end)+3);
                idcK2(idcK2<=0) = [];
                idcK2(idcK2>length(data)) = [];
                idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                lfp = int16(interp1(data, idcKOff, "linear", 0))';
            end
        end
    end
end