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

        function spikeSort(obj, options)
            % SPIKESORT Sort spikes from raw data

            arguments
                obj
                options.method string {mustBeMember(options.method, ["kilosort3", "kilosort4"])} = ...
                    "kilosort3"
            end
            switch options.method
                case "kilosort3"
                    %% Add paths
                    fdirKilosort3 = spiky.config.loadConfig("fdirKilosort3");
                    addpath(genpath(fdirKilosort3));
                    %% Options
                    ops.fshigh = 300; % frequency for high pass filtering (150)
                    ops.fslow = 6000;  % frequency for low pass filtering (optional)
                    ops.minfr_goodchannels = 0; % minimum firing rate on a "good" channel (0 to skip)
                    ops.Th = [10 4]; % threshold on projections (like in Kilosort1, can be different for last pass like [10 4]) 
                    ops.lam = 20; % how important is the amplitude penalty (like in Kilosort1, 0 means not used, 10 is average, 50 is a lot) 
                    ops.AUCsplit = 0.9; % splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
                    ops.minFR = 1/50; % minimum spike rate (Hz), if a cluster falls below this for too long it gets removed
                    ops.momentum = [20 400]; % number of samples to average over (annealed from first to second value) 
                    ops.sigmaMask = 30; % spatial constant in um for computing residual variance of spike
                    ops.ThPre = 8; % threshold crossings for pre-clustering (in PCA projection space)
                    % options for determining PCs
                    ops.spkTh           = -6;      % spike threshold in standard deviations (-6)
                    ops.reorder         = 1;       % whether to reorder batches for drift correction. 
                    ops.nskip           = 25;  % how many batches to skip for determining spike PCs
                    ops.GPU                 = 1; % has to be 1, no CPU version yet, sorry
                    % ops.Nfilt               = 1024; % max number of clusters
                    ops.nfilt_factor        = 4; % max number of clusters per good channel (even temporary ones)
                    ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
                    ops.NT                  = 64*1024*2+ops.ntbuff; % must be multiple of 32 + ntbuff. This is the batch size (try decreasing if out of memory). 
                    ops.whiteningRange      = 32; % number of channels to use for whitening each channel
                    ops.nSkipCov            = 25; % compute whitening matrix from every N-th batch
                    ops.scaleproc           = 200;   % int16 scaling of whitened data
                    ops.nPCs                = 3; % how many PCs to project the spikes into
                    ops.useRAM              = 0; % not yet available
                    ops.trange = [0 Inf]; % time range to sort
                    ops.fproc = fullfile(tempdir, 'temp_wh.dat'); % proc file on a fast SSD
                    
                    % main parameter changes from Kilosort2 to v2.5
                    ops.sig        = 20;  % spatial smoothness constant for registration
                    ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 
                    ops.fs = obj.Fs; % sample rate
                    %% Run Kilosort3
                    nProbes = length(obj.FpthDat);
                    idcNeural = find([obj.ChannelGroups.ChannelType]==spiky.ephys.ChannelType.Neural);
                    resampled = obj.Options.resampleDat;
                    for ii = 1:nProbes
                        fprintf("Running Kilosort3 on probe %d\n", ii);
                        fdir = fileparts(obj.FpthDat(ii));
                        fdirSort = fullfile(fdir, "kilosort3");
                        mkdir(fdirSort);
                        ops.fbinary = obj.FpthDat(ii);
                        if resampled
                            probe = [obj.ChannelGroups(idcNeural).Probe]';
                            probe = probe.toStruct(obj.NChannels);
                            ops.NchanTOT = obj.NChannels;
                        else
                            probe = obj.ChannelGroups(ii).Probe.toStruct();
                            ops.NchanTOT = obj.ChannelGroups(ii).NChannels;
                        end
                        ops.Nchan = sum(probe.connected);
                        ops.chanMap = probe;
                        %% Main computation
                        % preprocess data to create temp_wh.dat
                        rez = preprocessDataSub(ops);
                        % NEW STEP TO DO DATA REGISTRATION
                        rez = datashift2(rez, 1); % last input is for shifting data
                        save(fullfile(fdirSort, "rez.mat"), "rez", "-v7.3");
                        % main tracking and template matching algorithm
                        [rez, st3, tF]     = extract_spikes(rez);
                        rez                = template_learning(rez, tF, st3);
                        [rez, st3, tF]     = trackAndSort(rez);
                        rez                = final_clustering(rez, tF, st3);
                        rez                = find_merges(rez, 1);
                        % write to Phy
                        fprintf("Saving results to Phy  \n")
                        rezToPhy2(rez, fdirSort);
                        % discard features in final rez file (too slow to save)
                        rez.cProj = [];
                        rez.cProjPC = [];
                        % final time sorting of spikes, for apps that use st3 directly
                        [~, isort]   = sortrows(rez.st3);
                        rez.st3      = rez.st3(isort, :);
                        % Ensure all GPU arrays are transferred to CPU side before saving to .mat
                        rez_fields = fieldnames(rez);
                        for i = 1:numel(rez_fields)
                            field_name = rez_fields{i};
                            if(isa(rez.(field_name), "gpuArray"))
                                rez.(field_name) = gather(rez.(field_name));
                            end
                        end
                        % save final results as rez2
                        fprintf("Saving final results in rez2  \n")
                        save(fullfile(fdirSort, "rez2.mat"), "rez", "-v7.3");
                        % Change the param.py to correct the path
                        fpthParams = fullfile(fdirSort, "params.py");
                        t = fileread(fpthParams);
                        t = regexprep(t, "dat_path = ''.+?''", ...
                            "dat_path = ''../continuous.dat''");
                        t = regexprep(t, "n_channels_dat = \d+", ...
                            sprintf("n_channels_dat = %d", obj.ChannelGroups(ii).NChannels));
                        t = regexprep(t, "hp_filtered = True", ...
                            "hp_filtered = False");
                        fid = fopen(fpthParams, "w");
                        fwrite(fid, t, "char");
                        fclose(fid);
                        delete(ops.fproc);
                    end
                    rmpath(genpath(fdirKilosort3));
                case "kilosort4"
                    fdirConda = spiky.config.loadConfig("fdirConda");
                    fpth = mfilename("fullpath");
                    fdir = fileparts(fpth);
                    fpthKilosort4 = fullfile(fdir, "kilosort4.py");
                    envKilosort4 = spiky.config.loadConfig("envKilosort4");
                    nProbes = length(obj.FpthDat);
                    for ii = 1:nProbes
                        fdir = fileparts(obj.FpthDat(ii));
                        fpthProbe = fullfile(fdir, "probe.mat");
                        obj.ChannelGroups(ii).Probe.save(fpthProbe);
                        status = system(fdirConda+"\Scripts\activate.bat "+fdirConda+...
                            cmdsep+"conda activate "+envKilosort4+cmdsep+"python "+fpthKilosort4+" "+...
                            fdir+" "+fpthProbe, "-echo");
                        if status==0
                            fprintf("Kilosort4 completed on probe %d successfully.\n", ii)
                        else
                            error("Kilosort4 failed on probe %d.", ii)
                        end
                    end
                otherwise
                    error("Method %s not recognized", options.method)
            end
        end

        function extractSpikes(obj, options)
            % EXTRACTSPIKES Extract spikes from sorted data

            arguments
                obj
                options.method string {mustBeMember(options.method, ["kilosort3", "kilosort4"])} = ...
                    "kilosort3"
                options.labels string {mustBeMember(options.labels, ["good", "mua"])} = "good"
            end

            switch options.method
                case {"kilosort3", "kilosort4"}
                    if obj.Options.resampleDat
                        error("Not implemented")
                    else % multiple files
                        nProbes = length(obj.FpthDat);
                        nChs = [obj.ChannelGroups.NChannels]';
                        spikes = cell(nProbes, 1);
                        for ii = 1:nProbes
                            fpth = obj.FpthDat(ii);
                            fdir = fullfile(fileparts(fpth), options.method);
                            ts = spiky.utils.npy.readNPY(fullfile(fdir, "spike_times.npy"));
                            ts = double(ts)./obj.Fs;
                            if ii>1
                                ts = obj.EventGroups(ii).Sync.Inv(ts);
                            end
                            clu = spiky.utils.npy.readNPY(fullfile(fdir, "spike_clusters.npy"));
                            tmpl = spiky.utils.npy.readNPY(fullfile(fdir, "templates.npy"));
                            fid = fopen(fullfile(fdir, "cluster_group.tsv"));
                            C = textscan(fid, "%d%s%[^\n\r]", "Delimiter", "\t", "HeaderLines", 1);
                            fclose(fid);
                            label = table(C{1}, string(C{2}), VariableNames=["id", "label"]);
                            n = height(label);
                            nT = size(tmpl, 2);
                            tmpl2 = reshape(tmpl, n, []);
                            [~, ch] = max(abs(tmpl2), [], 2);
                            ch = floor((ch-1)/nT)+1;
                            [~, ch] = ismember(ch, obj.ChannelGroups(ii).Probe.ChanMap);
                            if ii>1
                                chInAll = ch+sum(nChs(1:ii-1));
                            else
                                chInAll = ch;
                            end
                            isGood = ismember(label.label, options.labels);
                            idcGood = find(isGood);
                            clear s;
                            for jj = length(idcGood):-1:1
                                idx = idcGood(jj);
                                neuron = spiky.core.Neuron(obj.Session, ii, label.id(idx), ...
                                    obj.ChannelGroups(ii).Name, chInAll(idx), ch(idx));
                                s(jj, 1) = spiky.core.Spikes(neuron, uniquetol(ts(clu==label.id(idx)), ...
                                    8e-4, DataScale=1));
                            end
                            s = s([s.Length]./obj.Duration>0.2);
                            spikes{ii} = s;
                        end
                        spikes = vertcat(spikes{:});
                        si = spiky.ephys.SpikeInfo(spikes, options);
                    end
                otherwise
                    error("Method %s not recognized", options.method)
            end
            obj.Session.saveMetaData(si);
        end

        function extractMinos(obj)
            fdir = obj.Session.getFdir("Minos");
            data = spiky.minos.MinosInfo.load(fdir, obj);
            obj.Session.saveMetaData(data);
        end
    end
end
