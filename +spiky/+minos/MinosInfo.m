classdef MinosInfo < spiky.core.Metadata

    properties
        Session spiky.ephys.Session
        Vars spiky.core.Parameter
        Paradigms spiky.minos.Paradigm
        Sync spiky.ephys.EventGroup
        Eye spiky.minos.EyeData
        Player spiky.core.TimeTable
        Display spiky.core.TimeTable
        Input spiky.core.TimeTable
        ExperimenterInput spiky.core.TimeTable
        Reward spiky.core.TimeTable
    end

    methods (Static)
        function obj = load(fdir, info)
            % LOAD Load Minos info from a directory
            %
            %   fdir: directory containing the Minos info
            %   info: SessionInfo object
            %
            %   obj: Minos info object
            arguments
                fdir (1, 1) string {mustBeFolder}
                info spiky.ephys.SessionInfo = spiky.ephys.SessionInfo.empty
            end
            if isempty(info)
                error("Not implemented")
            end
            log = spiky.minos.Data(fullfile(fdir, "Log.txt"));
            sync = spiky.minos.Data(fullfile(fdir, "Sync.bin"));
            n = height(sync.Values);
            for ii = n:-1:1
                syncEvents(ii, 1) = spiky.ephys.RecEvent(...
                    double(sync.Values{ii, 1})./1e7, ...
                    sync.Values{ii, 1}, spiky.ephys.ChannelType.Stim, ...
                    int16(1), "", true, "");
            end
            events = info.EventsGroups(1).Events(1:2:end);
            [sync, eventsSync] = events.syncWith(syncEvents, "probe1 to minos");
            idcStart = find(startsWith(log.Values.Value, "Start Paradigm"));
            idcStop = find(startsWith(log.Values.Value, "Pause Paradigm"));
            if length(idcStart)~=length(idcStop)
                error("Start and stop paradigm events do not match")
            end
            parPeriods = sync.Inv(double([log.Values.Timestamp(idcStart) ...
                log.Values.Timestamp(idcStop)])/1e7);
            parPeriodsNames = strrep(extractAfter(log.Values.Value(idcStart), ...
            "Paradigm "), " ", "");
            fiPars = spiky.core.FileInfo(fdir+filesep);
            fiPars = fiPars([fiPars.IsDir] & [fiPars.Name]~="Assets");
            parNamesSpace = [fiPars.Name]';
            parNames = strrep(parNamesSpace, " ", "");
            photodiode = info.EventsGroups.Adc.Events.Photodiode;
            for ii = length(parNames):-1:1
                periods = spiky.core.Periods(parPeriods(...
                    parPeriodsNames==parNames(ii), :));
                pars(ii, 1) = spiky.minos.Paradigm.load(...
                    fdir+filesep+parNamesSpace(ii), ...
                    periods, sync.Inv, [photodiode.Time]');
            end
            player = spiky.minos.Data(fullfile(fdir, "Player.bin"));
            display = spiky.minos.Data(fullfile(fdir, "Display.bin"));
            input = spiky.minos.Data(fullfile(fdir, "Input.bin"));
            experimenterInput = spiky.minos.Data(fullfile(fdir, "ExperimenterInput.bin"));
            reward = spiky.minos.Data(fullfile(fdir, "Reward.bin"));

            obj = spiky.minos.MinosInfo();
            obj.Session = info.Session;
            obj.Vars = log.getParameters(sync.Inv);
            obj.Paradigms = pars;
            obj.Sync = spiky.ephys.EventGroup("Stim", ...
                spiky.ephys.ChannelType.Stim, eventsSync, ...
                double(log.Values{[1 end], 1})', sync);
            obj.Eye = spiky.minos.EyeData.load(fdir, sync.Inv);
            obj.Player = spiky.core.TimeTable(...
                sync.Inv(double(player.Values.Timestamp)/1e7), ...
                player.Values);
            obj.Display = spiky.core.TimeTable(...
                sync.Inv(double(display.Values.Timestamp)/1e7), ...
                display.Values);
            obj.Input = spiky.core.TimeTable(...
                sync.Inv(double(input.Values.Timestamp)/1e7), ...
                input.Values);
            obj.ExperimenterInput = spiky.core.TimeTable(...
                sync.Inv(double(experimenterInput.Values.Timestamp)/1e7), ...
                experimenterInput.Values);
            obj.Reward = spiky.core.TimeTable(...
                sync.Inv(double(reward.Values.Timestamp)/1e7), ...
                reward.Values);
        end
    end

    methods
        function assets = getAssets(obj)
            % GETASSETS Get the assets of the Minos info
            %
            %   assets: assets
            fpthAssets = obj.Session.getFpth("spiky.minos.Asset.mat");
            if exist(fpthAssets, "file")
                assets = obj.Session.loadData("spiky.minos.Asset.mat");
                return
            end
            fdir = obj.Session.getFdir("Minos", "Assets");
            fi = spiky.core.FileInfo(fdir+"\**\*.meta");
            n = height(fi);
            for ii = n:-1:1
                name = extractBefore(fi(ii).Name, strlength(fi(ii).Name)-4);
                [~, name, ~] = fileparts(name);
                path = extractBefore(fi(ii).Path, strlength(fi(ii).Path)-4);
                c = fileread(fi(ii).Path);
                idx1 = strfind(c, "guid")+6;
                idx1 = idx1(1);
                idx2 = strfind(c(idx1:end), newline)+idx1-2;
                idx2 = idx2(1);
                guid = string(c(idx1:idx2));
                isDir = contains(c, "folderAsset: yes");
                assets(ii, :) = spiky.minos.Asset(name, path, guid, isDir);
            end
            obj.Session.saveMetaData(assets);
        end

        function stimuli = loadStimuli(obj, name)
            % LOADSTIMULI Load stimuli from name
            %
            %   name: name of the stimulus set
            %
            %   stimuli: stimuli
            assets = obj.Session.loadData("spiky.minos.Asset.mat");
            stimulusType = ["Subset", "GameObject", "Image", "Video"];
            stimulusSource = ["Internal", "External"];
            stimulusSourceType = ["Folder", "List"];
            name = extractBefore(name, " ("|textBoundary("end"));
            fpth = fullfile(obj.Session.Fdir, ...
                "Minos\Assets\Resources\Stimuli\StimulusSets", name+".asset");
            if ~exist(fpth, 'file')
                error('File %s not found', fpth);
            end
            txt = readlines(fpth);
            txt = strjoin(txt(4:end), newline);
            asset = spiky.utils.yaml.load(txt);
            asset = asset.MonoBehaviour;
            asset.x_type = stimulusType(asset.x_type+1);
            asset.x_source = stimulusSource(asset.x_source+1);
            asset.x_setType = stimulusSourceType(asset.x_setType+1);
            if strcmp(asset.x_source, "Internal") % internal
                if strcmp(asset.x_type, "Image")
                    ims = cell2mat(asset.x_images.value);
                    guids = [ims.guid]';
                    [~, idc] = ismember(guids, [assets.Guid]);
                    for ii = length(idc):-1:1
                        stimuli(ii, 1) = spiky.minos.Stimulus(...
                            assets(idc(ii)).Name, "Image", ...
                            assets(idc(ii)).Path, 1);
                    end
                else
                    error('Not implemented');
                end
            else % external
                paths = strsplit(asset.x_text, newline)';
                if ~contains(paths(1), filesep)
                    paths = asset.x_externalFolder+filesep+paths;
                end
                names = strings(size(paths));
                for ii = length(paths):-1:1
                    [~, names(ii), ~] = fileparts(paths(ii));
                end
                for ii = length(paths):-1:1
                    stimuli(ii, 1) = spiky.minos.Stimulus(...
                        names(ii), "Video", paths(ii), 1);
                end
            end
        end
    end
end