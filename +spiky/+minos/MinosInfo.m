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
        function obj = load(info, options)
            % LOAD Load Minos info from a directory
            %
            %   info: SessionInfo object
            %   options: 
            %       minPhotodiodeGap: minimum photodiode gap in seconds
            %
            %   obj: Minos info object

            arguments
                info spiky.ephys.SessionInfo = spiky.ephys.SessionInfo.empty
                options.MinPhotodiodeGap double = 0.05
                options.Plot = true
            end
            if isempty(info)
                error("Not implemented")
            end
            fdir = info.Session.getFdir("Minos");
            log = spiky.minos.Data(fullfile(fdir, "Log.txt"));
            sync1 = spiky.minos.Data(fullfile(fdir, "Sync.bin"));
            % n = height(sync1.Data);
            syncEvents = spiky.ephys.RecEvents(double(sync1.Data.timestamp)./1e7, ...
                sync1.Data.timestamp, spiky.ephys.ChannelType.Stim, ...
                int16(1), "Sync", true, "");
            events = info.EventGroups(1).Events.Sync;
            if isempty(events)
                events = info.EventGroups(1).Events;
            end
            events = events(events.Rising, :);
            [sync, eventsSync] = events.syncWith(syncEvents, "probe1 to minos", ...
                allowStep=false, Plot=options.Plot);
            idcStart = find(startsWith(log.Data.Value, "Start Paradigm"));
            idcStop = find(startsWith(log.Data.Value, "Pause Paradigm"));
            if length(idcStart)~=length(idcStop)
                error("Start and stop paradigm events do not match")
            end
            parPeriods = sync.Inv(double([log.Data.Timestamp(idcStart) ...
                log.Data.Timestamp(idcStop)])/1e7);
            parPeriodsNames = strrep(extractAfter(log.Data.Value(idcStart), ...
                "Paradigm "), " ", "");
            fiPars = spiky.core.FileInfo(fdir+filesep);
            fiPars = fiPars([fiPars.IsDir] & [fiPars.Name]~="Assets");
            parNamesSpace = [fiPars.Name]';
            parNames = strrep(parNamesSpace, " ", "");
            photodiode = info.EventGroups.Adc.Events.Photodiode;
            [~, idc] = photodiode.findContinuous(options.MinPhotodiodeGap);
            idc = unique(cell2mat(cellfun(@(x) x([1 end])', idc, UniformOutput=false)));
            tPhotodiode = photodiode(idc, :).Time;

            for ii = length(parNames):-1:1
                periods = spiky.core.Periods(parPeriods(...
                    parPeriodsNames==parNames(ii), :));
                pars(ii, 1) = spiky.minos.Paradigm.load(...
                    fdir+filesep+parNamesSpace(ii), ...
                    periods, sync.Inv, tPhotodiode);
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
                double(log.Data{[1 end], 1})', sync);
            tr = obj.getTransform();
            obj.Eye = spiky.minos.EyeData.load(fdir, sync.Inv, [], tr, ...
                obj.Vars.DisplayFov.Data.Data(1));
            obj.Player = spiky.core.TimeTable(...
                sync.Inv(double(player.Data.Timestamp)/1e7), ...
                player.Data);
            obj.Display = spiky.core.TimeTable(...
                sync.Inv(double(display.Data.Timestamp)/1e7), ...
                display.Data);
            obj.Input = spiky.core.TimeTable(...
                sync.Inv(double(input.Data.Timestamp)/1e7), ...
                input.Data);
            obj.ExperimenterInput = spiky.core.TimeTable(...
                sync.Inv(double(experimenterInput.Data.Timestamp)/1e7), ...
                experimenterInput.Data);
            obj.Reward = spiky.core.TimeTable(...
                sync.Inv(double(reward.Data.Timestamp)/1e7), ...
                reward.Data);
        end
    end

    methods
        function data = loadData(obj, name1, name2)
            % LOADDATA Load data from Minos info
            %
            %   data = loadData(obj, filename)
            %   data = loadData(obj, folder, filename)
            arguments
                obj spiky.minos.MinosInfo
                name1 string
                name2 string = ""
            end
            if nargin==2 || isempty(name2) || name2==""
                fpth = obj.Session.getFdir("Minos", name1);
            else
                fpth = obj.Session.getFdir("Minos", name1, name2);
            end
            if ~exist(fpth, "file")
                error("File %s not found", fpth);
            end
            data = spiky.minos.Data(fpth);
        end

        function tr = getTransform(obj)
            % GETTRANSFORM Get the object transform
            fpthTransform = obj.Session.getFpth("spiky.minos.Transform.mat");
            if exist(fpthTransform, "file")
                tr = obj.Session.loadData("spiky.minos.Transform.mat");
                return
            end
            if ~exist(obj.Session.getFdir("Minos", "TransformRecord.bin"), "file")
                tr = spiky.minos.Transform.empty;
                return
            end
            nr = obj.loadData("NameRecord.bin");
            data = obj.loadData("TransformRecord.bin");
            t = obj.Sync.Sync.Inv(double(data.Timestamp)/1e7);
            [objs, ~, idcObj] = unique(data.Data(:, ["Id" "NameIndex"]), "rows", "stable");
            nObjs = height(objs);
            pb = spiky.plot.ProgressBar(nObjs, "Calculating transforms", Parallel=true);
            parfor ii = 1:nObjs
                idc = idcObj==ii;
                t1 = t(idc);
                data1 = spiky.core.TimeTable(t1, table(Size=[sum(idc) 5], ...
                    VariableTypes=["int64" "logical" "single" "single" "single"], ...
                    VariableNames=["Trial" "Active" "Pos" "Rot" "Proj"]));
                data1.Trial = data.Trial(idc);
                data1.Active = data.Active(idc);
                if isnan(data.HeadPos(find(idc, 1), 1))
                    % non-human
                    data1.Pos = data.RootPos(idc, :);
                    data1.Rot = data.RootRot(idc, :);
                    data1.Proj = data.RootProj(idc, :);
                else
                    % human
                    data1.Pos = reshape(data.Data{idc, 6:3:end}, [], 3, 12);
                    data1.Rot = reshape(data.Data{idc, 7:3:end}, [], 3, 12);
                    data1.Proj = reshape(data.Data{idc, 8:3:end}, [], 3, 12);
                end
                tr(ii, 1) = spiky.minos.Transform(nr.Name(objs.NameIndex(ii)+1), ...
                    objs.Id(ii), data1);
                pb.step;
            end
            obj.Session.saveMetaData(tr);
        end

        function fix = getFixation(obj)
            % GETFIXATION Get the fixation data
            fpthFixation = obj.Session.getFpth("spiky.minos.Fixation.mat");
            if exist(fpthFixation, "file")
                fix = obj.Session.loadData("spiky.minos.Fixation.mat");
                return
            end
            fix = spiky.minos.Fixation.load(...
                obj.Session.getFdir("Minos", "Fixation.bin"));
            obj.Session.saveMetaData(fix);
        end

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
            assets = obj.getAssets;
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
                switch asset.x_type
                    case "Image"
                        ims = cell2mat(asset.x_images.value);
                    case "Video"
                        ims = cell2mat(asset.x_videos.value);
                    case "GameObject"
                        ims = cell2mat(asset.x_gameObjects.value);
                end
                guids = [ims.guid]';
                [~, idc] = ismember(guids, [assets.Guid]);
                for ii = length(idc):-1:1
                    stimuli(ii, 1) = spiky.minos.Stimulus(...
                        assets(idc(ii)).Name, categorical(asset.x_type, ["Image" "Video" "GameObject"]), ...
                        assets(idc(ii)).Path, 1);
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
                        names(ii), categorical(asset.x_type, ["Image" "Video" "GameObject"]), paths(ii), 1);
                end
            end
        end
    end
end