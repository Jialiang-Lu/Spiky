classdef RawData

    properties
        Fdir string
        Type string {mustBeMember(Type, ["Binary", "OpenEphys"])}
        Source string {mustBeMember(Source, ["Intan", "Npx"])}
        DatFiles spiky.core.FileInfo
        LfpFiles spiky.core.FileInfo
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
                    obj.DatFiles = fi(1:2:end);
                    obj.LfpFiles = fi(2:2:end);
                else
                    obj.Source = "Intan";
                    obj.DatFiles = fi;
                end
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
                    s = string(fileread(fi(2).Path));
                    tokens = regexp(s, "^(\d+), (.+?)$", "tokens", "lineanchors");
                    tokens = vertcat(tokens{:});
                    tsStart = spiky.utils.str2int(tokens(2, 1));
                    tokens = tokens(4:end, :);
                    ts = spiky.utils.str2int(tokens(:, 1))-tsStart;
                    t = double(ts)./30000;
                    n = length(ts);
                    for ii = n:-1:1
                        events1(ii, 1) = spiky.ephys.RecEvent(t(ii), ts(ii), spiky.ephys.ChannelType.Net, ...
                            0, "", true, tokens(ii, 2));
                    end
                    %% TTL
                    n = (fi(1).Bytes-1024)/16;
                    if n~=round(n)
                        error("Invalid number of events in %s", fi(1).Path);
                    end
                    fid = fopen(fi(1).Path, "r");
                    fseek(fid, 1024, "bof");
                    ts = fread(fid, n, "int64=>int64", 8, "l")-tsStart;
                    % fseek(fid, 1024+8, "bof");
                    % sn = fread(fid, n, "int16=>int16", 14, "n");
                    % fseek(fid, 1024+8+2, "bof");
                    % eventType = fread(fid, n, "uint8=>uint8", 15, "n");
                    % fseek(fid, 1024+8+2+1, "bof");
                    % nodeId = fread(fid, n, "uint8=>uint8", 15, "n");
                    fseek(fid, 1024+8+2+1+1, "bof");
                    state = fread(fid, n, "uint8=>uint8", 15, "n");
                    fseek(fid, 1024+8+2+1+1+1, "bof");
                    ch = fread(fid, n, "uint8=>uint8", 15, "n")+1;
                    if isempty(channelNames)
                        channelNames = repmat("", max(ch), 1);
                    end
                    t = double(ts)./30000;
                    for ii = n:-1:1
                        events2(ii, 1) = spiky.ephys.RecEvent(t(ii), ts(ii), spiky.ephys.ChannelType.Dig, ...
                            ch(ii), channelNames(ch(ii)), state(ii)>0, "");
                    end
                    fclose(fid);
                    %% Combine
                    nSample = (obj.DatFiles(1).Bytes-1024)/2070;
                    tsRange = [tsStart, tsStart+nSample-1];
                    eventGroups(2, 1) = spiky.ephys.EventGroup("Net", ...
                        spiky.ephys.ChannelType.Net, events1, tsRange);
                    eventGroups(1, 1) = spiky.ephys.EventGroup("Adc", ...
                        spiky.ephys.ChannelType.Adc, events2, tsRange);
                case "Binary"
                    error("Not implemented yet")
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
                    oeStruct = readstruct(fullfile(obj.Fdir, "structure.openephys"), "FileType", "xml");
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
                    error("Not implemented yet")
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

        function [nSample, nSampleLfp] = resampleRaw(obj, fpthDat, fpthLfp, probes, fsLfp, resampleDat)
            arguments
                obj spiky.ephys.RawData
                fpthDat string
                fpthLfp string
                probes spiky.ephys.Probe
                fsLfp double = 1000
                resampleDat logical = false
            end

            switch obj.Type
                case "OpenEphys"
                    nSample = (obj.DatFiles(1).Bytes-1024)/2070*1024;
                    if nSample~=round(nSample)
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
                    nChunks = ceil(nSample/nSamplePerChunk);
                    delete(fpthDat);
                    rafile = java.io.RandomAccessFile(fpthDat, "rw");
                    rafile.setLength(nSample*2*nCh);
                    rafile.close();
                    %%
                    spiky.plot.timedWaitbar(0, "Resampling raw");
                    for ii = 1:nChunks
                        idxStart = (ii-1)*nSamplePerChunk+1;
                        idxEnd = min(ii*nSamplePerChunk, nSample);
                        raw = zeros(nCh, idxEnd-idxStart+1, "int16");
                        parfor jj = 1:nCh
                            chRaw = map.oeMap(jj);
                            raw(jj, :) = obj.getContinuous(chRaw, [idxStart, idxEnd])';
                            % fprintf("=");
                        end
                        % fprintf(newline);
                        clear mDat
                        mDat = memmapfile(fpthDat, Writable=true, Format={"int16", [nCh, nSample], "m"});
                        mDat.Data.m(:, idxStart:idxEnd) = raw;
                        spiky.plot.timedWaitbar(ii/nChunks);
                    end
                    %%
                    spiky.plot.timedWaitbar(0, "Resampling lfp");
                    nSampleLfp = ceil(nSample/30000*fsLfp);
                    nChPerGroup = 8;
                    nGroups = ceil(nChNeural/nChPerGroup);
                    lfp = zeros(nCh, nSampleLfp, "int16");
                    raw = zeros(nChPerGroup, nSample, "int16");
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
                    idcK2(idcK2>nSamplesLfp1(ii)) = [];
                    idcKOff = idcK-idcK2(1)+1; % make loaded data start from 1 for interpolation
                    data = interp1(double(data(idcK2, :)), idcKOff, "linear", 0);
                end
                lfp = int16(resample(data, p, q))';
            else
                data = medfilt1(double(data), ceil(fs/fsLfp));
                nSampleLfp = ceil(length(data)/fs*fsLfp);
                if isempty(sync)
                    idcK = (0:nSampleLfp-1)./fsLfp.*fs+1;
                else
                    idcK = sync((0:nSampleLfp-1)./fsLfp).*fs+1;
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