classdef SpikeSorter
    properties
        Fpth string
        Probe struct
        Method string
    end

    methods
        function obj = SpikeSorter(fpth, probe, method)
            %SPIKESORTER Create a new instance of SpikeSorter

            arguments
                fpth string {mustBeFile}
                probe % probe file or spiky.ephys.Probe or struct
                method string {mustBeMember(method, ["kilosort3", "kilosort4"])} = "kilosort3"
            end

            obj.Fpth = fpth;
            if isstring(probe) && exist(probe, "file")
                probe = load(probe);
            elseif isa(probe, "spiky.ephys.Probe")
                probe = probe.toStruct();
            elseif ~isstruct(probe)
                error("Invalid probe.")
            end
            obj.Probe = probe;
            obj.Method = method;
        end

        function run(obj, nChannels, options)
            %RUN Run Kilosort4 on the specified data
            %
            %   run(obj, version) runs Kilosort on the specified data.
            %   obj: Kilosort object

            arguments
                obj
                nChannels double = []
                options.Fs double = 30000
            end
            fdir = fileparts(obj.Fpth);
            fdirSort = fullfile(fdir, "kilosort3");
            mkdir(fdirSort);
            if isempty(nChannels)
                nChannels = numel(obj.Probe.connected);
            elseif nChannels>numel(obj.Probe.connected)
                obj.Probe = spiky.ephys.Probe(obj.Probe).toStruct(nChannels);
            end
            if obj.Method=="kilosort3"
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
                ops.fs = options.Fs; % sample rate
                %% Run Kilosort3
                ops.fbinary = obj.Fpth;
                ops.NchanTOT = nChannels;
                ops.Nchan = sum(obj.Probe.connected);
                ops.chanMap = obj.Probe;
                %% Main computation
                % preprocess data to create temp_wh.dat
                rez = preprocessDataSub(ops);
                %NEW STEP TO DO DATA REGISTRATION
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
                t = regexprep(t, "dat_path = '.+?'", ...
                    "dat_path = '../continuous.dat'");
                t = regexprep(t, "n_channels_dat = \d+", ...
                    sprintf("n_channels_dat = %d", ops.NchanTOT));
                t = regexprep(t, "hp_filtered = True", ...
                    "hp_filtered = False");
                fid = fopen(fpthParams, "w");
                fwrite(fid, t, "char");
                fclose(fid);
                delete(ops.fproc);
                rmpath(genpath(fdirKilosort3));
            else
                [~, fn] = fileparts(obj.Fpth);
                fpthProbe = fullfile(fdir, fn+".probe.mat");
                probe = obj.Probe;
                save(fpthProbe, "-struct", "probe");
                fdirConda = spiky.config.loadConfig("fdirConda");
                fpthKilosort4 = fullfile(fileparts(mfilename("fullpath")), "kilosort4.py");
                envKilosort4 = spiky.config.loadConfig("envKilosort4");
                status = system(fdirConda+"\Scripts\activate.bat "+fdirConda+...
                    cmdsep+"conda activate "+envKilosort4+cmdsep+"python "+fpthKilosort4+" "+...
                    fdir+" "+fpthProbe, "-echo");
                if status==0
                    disp("Kilosort4 completed successfully.")
                else
                    error("Kilosort4 failed.")
                end
            end
        end
    end
end