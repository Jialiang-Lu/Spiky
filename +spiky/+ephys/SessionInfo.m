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
        FpthDat (:, 1) string
        FpthLfp (:, 1) string
        ChannelGroups (:, 1) spiky.ephys.ChannelGroup
        EventsGroups (:, 1) spiky.ephys.EventsGroup
        Options struct
    end

    methods
        function obj = SessionInfo(session, nChannels, fs, fsLfp, nSamples, nSamplesLfp, ...
            duration, precision, fpthDat, fpthLfp, channelGroups, eventsGroups, options)
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
                channelGroups spiky.ephys.ChannelGroup = spiky.ephys.ChannelGroup.empty
                eventsGroups spiky.ephys.EventsGroup = spiky.ephys.EventsGroup.empty
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
            obj.EventsGroups = eventsGroups;
            obj.Options = options;
        end

        function extractSpikes(obj, options)
            arguments
                obj
                options.method string = "kilosort4"
            end

            switch options.method
                case "kilosort4"
                    if isscalar(obj.FpthDat) % single file
                        error("Not implemented")
                    else % multiple files
                        nProbes = length(obj.FpthDat);
                        nChs = [obj.ChannelGroups.NChannels]';
                        spikes = cell(nProbes, 1);
                        for ii = 1:nProbes
                            fpth = obj.FpthDat(ii);
                            fdir = fullfile(fileparts(fpth), "kilosort4");
                            ts = spiky.utils.npy.readNPY(fullfile(fdir, "spike_times.npy"));
                            ts = double(ts)./obj.Fs;
                            if ii>1
                                ts = obj.EventsGroups(ii).Sync.Inv(ts);
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
                            [~, ch] = ismember(ch, obj.ChannelGroups(ii).Probe.OeMap);
                            if ii>1
                                chInAll = ch+sum(nChs(1:ii-1));
                            else
                                chInAll = ch;
                            end
                            isGood = label.label=="good";
                            idcGood = find(isGood);
                            clear s;
                            for jj = length(idcGood):-1:1
                                idx = idcGood(jj);
                                neuron = spiky.core.Neuron(obj.Session, ii, label.id(idx), ...
                                    obj.ChannelGroups(ii).Name, chInAll(idx), ch(idx));
                                s(jj) = spiky.core.Spikes(neuron, uniquetol(ts(clu==label.id(idx)), 8e-4, DataScale=1));
                            end
                            spikes{ii} = s;
                        end
                        spikes = horzcat(spikes{:})';
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
