classdef MinosInfo < spiky.core.Metadata

    properties
        Vars (:, 1) spiky.core.Parameter
        Pars (:, 1) spiky.minos.Paradigm
        Sync spiky.ephys.EventsGroup
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
                fdir (1, 1) string {mustBeDir}
                info spiky.minos.SessionInfo = []
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
            for ii = length(parNames):-1:1
                periods = spiky.core.Periods(parPeriods(...
                    parPeriodsNames==parNames(ii), :));
                pars(ii, 1) = spiky.minos.Paradigm.load(...
                    fdir+filesep+parNamesSpace(ii), ...
                    periods, sync.Inv);
            end
            player = spiky.minos.Data(fullfile(fdir, "Player.bin"));
            display = spiky.minos.Data(fullfile(fdir, "Display.bin"));
            input = spiky.minos.Data(fullfile(fdir, "Input.bin"));
            experimenterInput = spiky.minos.Data(fullfile(fdir, "ExperimenterInput.bin"));
            reward = spiky.minos.Data(fullfile(fdir, "Reward.bin"));

            obj = spiky.minos.MinosInfo();
            obj.Vars = log.getParameters(sync.Inv);
            obj.Pars = pars;
            obj.Sync = spiky.ephys.EventsGroup("Stim", ...
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
end