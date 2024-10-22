classdef SessionInfo < spiky.core.Metadata
    
    properties
        Session spiky.ephys.Session
        NChannels double
        Fs double
        FsLfp double
        NSamples double
        NSamplesLfp double
        Duration double
        Precision string
        FpthDat string
        FpthLfp string
        ChannelGroups spiky.ephys.ChannelGroup
        EventGroups spiky.ephys.EventGroup
        Options struct
    end

    methods
        function obj = SessionInfo(session, nChannels, fs, fsLfp, nSamples, nSamplesLfp, ...
            duration, precision, fpthDat, fpthLfp, channelGroups, eventGroups, options)
            % SESSIONINFO Create a new instance of SessionInfo
            
            arguments
                session spiky.ephys.Session = spiky.ephys.Session.empty
                nChannels double = 0
                fs double = []
                fsLfp double = []
                nSamples double = 0
                nSamplesLfp double = 0
                duration double = 0
                precision string = ""
                fpthDat (:, 1) string = ""
                fpthLfp (:, 1) string = ""
                channelGroups (:, 1) spiky.ephys.ChannelGroup = spiky.ephys.ChannelGroup.empty
                eventGroups (:, 1) spiky.ephys.EventGroup = spiky.ephys.EventGroup.empty
                options struct = struct
            end

            obj.Session = session;
            obj.NChannels = nChannels;
            obj.Fs = fs;
            obj.FsLfp = fsLfp;
            obj.NSamples = nSamples;
            obj.NSamplesLfp = nSamplesLfp;
            obj.Duration = duration;
            obj.Precision = precision;
            obj.FpthDat = fpthDat;
            obj.FpthLfp = fpthLfp;
            obj.ChannelGroups = channelGroups;
            obj.EventGroups = eventGroups;
            obj.Options = options;
        end

        function data = loadBinary(obj, ch, period, options)
            % LOADBINARY Load binary data
            %
            % data = LOADBINARY(obj, type, ch, period, options)
            %
            %   ch: channel numbers
            %   period: time period
            %   options:
            %       type: "dat" or "lfp"
            %       precision: e.g. "int16" or "double"

            arguments
                obj
                ch double = []
                period double = []
                options.type string {mustBeMember(options.type, ["dat", "lfp"])} = "lfp"
                options.precision string = "double"
                options.periodType string {mustBeMember(options.periodType, ["time", "index"])} = "time"
            end

            if isempty(ch)
                ch = 1:obj.NChannels;
            end
            fpth = obj.Session.getFpth(options.type);
            if options.type=="dat"
                nSample = obj.NSamples;
                fs = obj.Fs;
            else
                nSample = obj.NSamplesLfp;
                fs = obj.FsLfp;
            end
            if options.periodType=="time"
                if isempty(period)
                    period = [0 nSample/fs-1];
                elseif isscalar(period)
                    period = [0 min(nSample/fs-1, period)];
                else
                    period = [max(period(1), 0) min(period(2), nSample/fs-1)];
                end
                idc = round(period(1)*fs)+1:round(period(2)*fs)+1;
            else
                idc = period;
            end
            if options.type=="dat" && ~obj.Options.resampleDat
                [ch, chGroup] = obj.ChannelGroups.getChannel(ch, false);
                groups = unique(chGroup);
                nGroups = length(groups);
                data = zeros(length(ch), length(idc), options.precision);
                chIdx = 0;
                for ii = 1:nGroups
                    group = groups(ii);
                    idcGroup = ch(chGroup==group);
                    idcGroupOut = chIdx+(1:numel(idcGroup));
                    nSample1 = diff(obj.EventGroups(group).TsRange)+1;
                    fpth = obj.FpthDat(group);
                    m = memmapfile(fpth, Format={"int16", ...
                        [obj.ChannelGroups(group).NChannels, nSample1], "m"});
                    if options.periodType=="time"
                        if group==1
                            idc1 = idc;
                        else
                            idc1 = obj.EventGroups(group).Sync((idc-1)./fs).fs+1;
                            idc2 = round(idc1(1)-3):round(idc1(end)+3);
                            idc2(idc2<=0) = [];
                            idc2(idc2>nSample1) = [];
                            idcOff = idcK-idc2(1)+1; % make loaded lfp start from 1 for interpolation
                        end
                        if group==1
                            data(idcGroupOut, :) = cast(m.Data.m(idcGroup, idc1), options.precision)*...
                                obj.ChannelGroups(group).BitVolts*obj.ChannelGroups(group).ToMv*1000;
                        else
                            data(idcGroupOut, :) = cast(interp1(double(m.Data.m(idcGroup, idc2)), ...
                                idcOff, "linear", 0), options.precision)*...
                                obj.ChannelGroups(group).BitVolts*obj.ChannelGroups(group).ToMv*1000;
                        end
                    else
                        data(idcGroupOut, :) = cast(m.Data.m(idcGroup, idc), options.precision)*...
                            obj.ChannelGroups(group).BitVolts*obj.ChannelGroups(group).ToMv*1000;
                    end
                end
                data = spiky.lfp.Lfp(0, fs, data');
                return
            end
            m = memmapfile(fpth, Format={"int16", [obj.NChannels, nSample], "m"});
            data = m.Data.m(ch, idc);
            if options.precision~="int16"
                [~, idxGroup] = obj.ChannelGroups.getChannel(ch);
                data = cast(data, options.precision)*obj.ChannelGroups(idxGroup).BitVolts*...
                    obj.ChannelGroups(idxGroup).ToMv;
            end
            data = spiky.lfp.Lfp(0, fs, data');
        end

        function spikeSort(obj, options)
            % SPIKESORT Sort spikes from raw data

            arguments
                obj
                options.method string {mustBeMember(options.method, ["kilosort3", "kilosort4"])} = ...
                    "kilosort3"
            end

            nProbes = length(obj.FpthDat);
            idcNeural = find([obj.ChannelGroups.ChannelType]==spiky.ephys.ChannelType.Neural);
            resampled = obj.Options.resampleDat;
            if resampled
                fprintf("Running %s on resampled data\n", options.method);
                spiky.ephys.SpikeSorter(obj.FpthDat, ...
                    obj.ChannelGroups(idcNeural).Probe.toStruct(obj.NChannels, true), ...
                    options.method).run();
            else
                for ii = 1:nProbes
                    fprintf("Running %s on probe %d\n", options.method, ii);
                    spiky.ephys.SpikeSorter(obj.FpthDat(ii), ...
                        obj.ChannelGroups(ii).Probe.toStruct(obj.ChannelGroups(ii).NChannels), ...
                        options.method).run();
                end
            end
        end

        function si = extractSpikes(obj, options)
            % EXTRACTSPIKES Extract spikes from sorted data

            arguments
                obj
                options.method string {mustBeMember(options.method, ["kilosort3", "kilosort4"])} = ...
                    "kilosort3"
                options.labels string {mustBeMember(options.labels, ["", "good", "mua"])} = ""
                options.minAmplitude double = 10
                options.minFr double = 0.2
                options.maxCv double = 0.5
            end

            switch options.method
                case {"kilosort3", "kilosort4"}
                    if options.labels==""
                        if options.method=="kilosort3"
                            options.labels = ["good", "mua"];
                        else
                            options.labels = "good";
                        end
                    end
                    if obj.Options.resampleDat
                        spikes = obj.loadSpikesFolder(obj.Session.getFdir("Kilosort3"), options);
                    else % multiple files
                        nProbes = length(obj.FpthDat);
                        nChs = [obj.ChannelGroups.NChannels]';
                        spikes = cell(nProbes, 1);
                        for ii = 1:nProbes
                            if ii>1
                                sync = obj.EventGroups(ii).Sync.Inv;
                            else
                                sync = [];
                            end
                            fpth = obj.FpthDat(ii);
                            fdir = fullfile(fileparts(fpth), options.method);
                            spikes{ii} = obj.loadSpikesFolder(fdir, options, sum(nChs(1:ii-1)), sync, ii);
                        end
                        spikes = vertcat(spikes{:});
                    end
                    si = spiky.ephys.SpikeInfo(spikes, options);
                otherwise
                    error("Method %s not recognized", options.method)
            end
            obj.Session.saveMetaData(si);
        end

        function minos = extractMinos(obj, options)
            % EXTRACTMINOS Extract Minos data

            arguments
                obj
                options.minPhotodiodeGap double = 0.05
            end
            optionsCell = namedargs2cell(options);
            fdir = obj.Session.getFdir("Minos");
            minos = spiky.minos.MinosInfo.load(fdir, obj, optionsCell{:});
            obj.Session.saveMetaData(minos);
        end

        function createNsXml(obj)
            % CREATENSXML Create Neuroscope XML file
            
            defaultColors = ["#ffeb3b", "#aeea00", "#00e5ff", "#d1c4e9"];
            defaultAdcColor = "#ff0000";
            nGroups = length(obj.ChannelGroups);
            colors = strings(nGroups, 1);
            for ii = 1:nGroups
                chType = obj.ChannelGroups(ii).ChannelType;
                if chType==spiky.ephys.ChannelType.Adc
                    colors(ii) = defaultAdcColor;
                else
                    colors(ii) = defaultColors(ii);
                end
            end
            chGroup = zeros(obj.NChannels, 1);
            %%
            clear parameters s
            parameters.Attributes.version = "1.0";
            parameters.Attributes.creator = "neuroscope-2.0.0";
            parameters.acquisitionSystem.nBits = 16;
            parameters.acquisitionSystem.nChannels = obj.NChannels;
            parameters.acquisitionSystem.samplingRate = obj.Fs;
            parameters.acquisitionSystem.voltageRange = 12;
            parameters.acquisitionSystem.amplification = 1000;
            parameters.acquisitionSystem.offset = 0;
            parameters.fieldPotentials.lfpSamplingRate = obj.FsLfp;
            parameters.files.file.extension = "lfp";
            parameters.files.file.samplingRate = obj.FsLfp;
            ch = 1;
            for ii = 1:nGroups
                isNeural = obj.ChannelGroups(ii).ChannelType==spiky.ephys.ChannelType.Neural;
                for jj = 1:obj.ChannelGroups(ii).NChannels
                    parameters.anatomicalDescription.channelGroups.group{ii}.channel{jj}.Text = ch-1;
                    parameters.anatomicalDescription.channelGroups.group{ii}.channel{jj}.Attributes.skip = 0;
                    if isNeural
                        parameters.spikeDetection.channelGroups.group.channels.channel{ch}.Text = ch-1;
                    end
                    chGroup(ch) = ii;
                    ch = ch+1;
                end
            end
            if ~isfield(parameters, "spikeDetection")
                parameters.spikeDetection = "";
            end
            parameters.neuroscope.Attributes.version = "2.0.0";
            parameters.neuroscope.miscellaneous.screenGain = 0.2;
            parameters.neuroscope.miscellaneous.traceBackgroundImage = "";
            parameters.neuroscope.video.rotate = 0;
            parameters.neuroscope.video.flip = 0;
            parameters.neuroscope.video.videoImage = "";
            parameters.neuroscope.video.positionsBackground = 0;
            parameters.neuroscope.spikes.nSamples = 32;
            parameters.neuroscope.spikes.peakSampleIndex = 16;
            for ii = 1:obj.NChannels
                color = colors(chGroup(ii));
                parameters.neuroscope.channels.channelColors{ii}.channel = ii-1;
                parameters.neuroscope.channels.channelColors{ii}.color = color;
                parameters.neuroscope.channels.channelColors{ii}.anatomyColor = color;
                parameters.neuroscope.channels.channelColors{ii}.spikeColor = color;
                parameters.neuroscope.channels.channelOffset{ii}.channel = ii-1;
                parameters.neuroscope.channels.channelOffset{ii}.defaultOffset = 0;
            end
            s.parameters = parameters;
            spiky.utils.struct2xml(s, obj.Session.getFpth("xml"));
            %%
            clear neuroscope s
            neuroscope.Attributes.version = "2.0.0";
            neuroscope.files = "";
            neuroscope.displays.display.tabLabel = "Field Potentials Display";
            neuroscope.displays.display.showLabels = 0;
            neuroscope.displays.display.startTime = 0;
            neuroscope.displays.display.duration = 2000;
            neuroscope.displays.display.multipleColumns = 0;
            neuroscope.displays.display.greyScale = 0;
            neuroscope.displays.display.autocenterChannels = 0;
            neuroscope.displays.display.positionView = 0;
            neuroscope.displays.display.showEvents = 0;
            neuroscope.displays.display.spikePresentation = 0;
            neuroscope.displays.display.rasterHeight = 33;
            for ii = 1:obj.NChannels
                neuroscope.displays.display.channelPositions.channelPosition{ii}.channel = ii-1;
                neuroscope.displays.display.channelPositions.channelPosition{ii}.gain = 0;
                neuroscope.displays.display.channelPositions.channelPosition{ii}.offset = 0;
            end
            neuroscope.displays.display.channelsSelected = "";
            ch = 1;
            idx = 1;
            for ii = 1:nGroups
                nCh = obj.ChannelGroups(ii).NChannels;
                if nCh<128
                    for jj = 1:nCh
                        neuroscope.displays.display.channelsShown.channel{idx}.Text = ch-1;
                        idx = idx+1;
                        ch = ch+1;
                    end
                else
                    for jj = 1:nCh
                        if mod(jj, 4)==1
                            neuroscope.displays.display.channelsShown.channel{idx}.Text = ch-1;
                            idx = idx+1;
                        end
                        ch = ch+1;
                    end
                end
            end
            s.neuroscope = neuroscope;
            spiky.utils.struct2xml(s, obj.Session.getFpth("nrs"));
        end
    end

    methods (Access = protected)
        function s = loadSpikesFolder(obj, fdir, options, chOffset, sync, idxGroup)
            arguments
                obj spiky.ephys.SessionInfo
                fdir string
                options struct
                chOffset double = 0
                sync = []
                idxGroup double = []
            end
            %%
            if isempty(sync)
                sync = @(x) x;
            end
            ts = spiky.utils.npy.readNPY(fullfile(fdir, "spike_times.npy"));
            ts = double(ts)./obj.Fs;
            % ts = sync(ts);
            clu = spiky.utils.npy.readNPY(fullfile(fdir, "spike_clusters.npy"));
            scaling = spiky.utils.npy.readNPY(fullfile(fdir, "amplitudes.npy"));
            tmpl = spiky.utils.npy.readNPY(fullfile(fdir, "templates.npy"));
            tmpl = double(tmpl);
            fid = fopen(fullfile(fdir, "cluster_group.tsv"));
            C = textscan(fid, "%d%s%[^\n\r]", "Delimiter", "\t", "HeaderLines", 1);
            fclose(fid);
            %%
            data = table(C{1}, string(C{2}), VariableNames=["id", "label"]);
            n = height(data);
            % nT = size(tmpl, 2);
            idcT = (-45:45)';
            tStart = idcT(1)./obj.Fs;
            nT = length(idcT);
            data.ts = cell(n, 1);
            data.fr = zeros(n, 1);
            data.ch = zeros(n, 1);
            data.amplitude = zeros(n, 1);
            data.cv = zeros(n, 1);
            data.waveform = zeros(n, nT);
            [~, ch] = max(max(tmpl, [], 2)-min(tmpl, [], 2), [], 3);
            data.ch = ch;
            chInAll = ch+chOffset;
            edges = 0:100:obj.Duration;
            if isempty(idxGroup)
                spiky.plot.timedWaitbar(0, "Extracting");
            else
                spiky.plot.timedWaitbar(0, sprintf("Extracting probe %d", idxGroup));
            end
            for ii = 1:n
                idc = clu==data.id(ii);
                data.ts{ii} = uniquetol(ts(idc), 8e-4, DataScale=1);
                data.fr(ii) = sum(idc)./obj.Duration;
                frs = histcounts(data.ts{ii}, edges);
                data.cv(ii) = std(frs)./mean(frs);
                % sc = mean(scaling(idc));
                % data.waveform(ii, :) = sc.*tmpl(ii, :, ch(ii));
                % data.amplitude(ii) = sc.*amplitude(ii);
                spiky.plot.timedWaitbar(ii/n);
            end
            spiky.plot.timedWaitbar([]);
            %%
            period = obj.EventGroups(idxGroup).NSamples;
            period = period-200*obj.Fs:period;
            raw = obj.loadBinary(obj.ChannelGroups.getGroupIndices(idxGroup), period, type="dat", ...
                periodType="index").filter([1 3000]);
            %%
            if isempty(idxGroup)
                spiky.plot.timedWaitbar(0, "Reading waveforms");
            else
                spiky.plot.timedWaitbar(0, sprintf("Reading waveforms probe %d", idxGroup));
            end
            for ii = 1:n
                idc = round(data.ts{ii}*obj.Fs)+1;
                idc = idc(idc>=period(1)-idcT(1) & idc<=period(end)-idcT(end));
                idc = idc'-period(1)+1+idcT;
                idc = idc(:);
                wav = raw{idc, ch(ii)};
                wav = mean(reshape(wav, nT, []), 2);
                data.waveform(ii, :) = wav';
                data.amplitude(ii) = max(wav)-min(wav);
                spiky.plot.timedWaitbar(ii/n);
            end
            spiky.plot.timedWaitbar([]);
    
            %%
            isGood = ismember(data.label, options.labels) & data.cv<options.maxCv & ...
                data.fr>options.minFr & data.amplitude>options.minAmplitude;
            idcGood = find(isGood);
            %%
            if isempty(idxGroup)
                chs = [obj.ChannelGroups([obj.ChannelGroups.ChannelType]'=="Neural").NChannels]';
                chsRanges = spiky.core.Periods([cumsum([1; chs(1:end-1)]), cumsum(chs)]);
                [ch, ~, idcGroup] = chsRanges.haveEvents(chInAll, false, 1, true, false);
                singleFile = true;
            else
                singleFile = false;
            end
            %%
            clear s;
            for jj = length(idcGood):-1:1
                idx = idcGood(jj);
                if singleFile
                    idxGroup = idcGroup(idx);
                end
                neuron = spiky.core.Neuron(obj.Session, idxGroup, data.id(idx), ...
                    obj.ChannelGroups(idxGroup).Name, chInAll(idx), ch(idx), ...
                    data.label(idx), spiky.lfp.Lfp(tStart, obj.Fs, data.waveform(idx, :)));
                s(jj, 1) = spiky.core.Spikes(neuron, sync(data.ts{idx}));
            end
            if isempty(idcGood)
                s = spiky.core.Spikes.empty;
            end
        end
    end
end
