classdef Paradigm < spiky.core.MappableArray & spiky.core.Metadata
    % PARADIGM represents paradigm data

    properties
        Name string
        Periods spiky.core.Periods
        Trials spiky.core.TimeTable
        Vars (:, 1) spiky.core.Parameter
    end

    methods (Static)
        function obj = load(fdir, periods, func)
            % LOAD Load a paradigm from a directory
            %
            %   fdir: directory containing the paradigm data
            %   func: function to convert the time
            %
            %   obj: paradigm object
            arguments
                fdir (1, 1) string {mustBeFolder}
                periods spiky.core.Periods
                func = []
            end
            [~, name] = fileparts(fdir);
            name = strrep(name, " ", "");
            log = spiky.minos.Data(fullfile(fdir, "Log.txt"));
            trials = spiky.minos.Data(fullfile(fdir, "Trials.bin"));
            trialInfo = spiky.minos.Data(fullfile(fdir, "TrialInfo.bin"));
            eventNames = unique(trials.Values.Event, "stable");
            eventNames = eventNames(~ismember(eventNames, ...
                ["ParadigmStart", "ParadigmStop", "Loading"]));
            eventsCount = groupsummary(trials.Values, "Event", ...
                @(x) sum(x==mode(x)), "Number");
            eventsCount = eventsCount(~ismember(eventsCount.Event, ...
                ["ParadigmStart", "ParadigmStop", "Loading"]), :);
            eventsCount = eventsCount.fun1_Number;
            if any(eventsCount>1)
                error("Not implemented")
            end
            trials.Values = groupfilter(trials.Values, "Number", ...
                @(s) all(~ismember(s, ...
                ["ParadigmStart", "ParadigmStop"])), "Event");
            [numbers, ~, idcNumbers] = unique(trials.Values.Number, "stable");
            [~, idcInfo] = ismember(numbers, trialInfo.Values.Number(end:-1:1));
            idcInfo = length(trialInfo.Values.Number)-idcInfo+1;
            n = length(numbers);
            varNames = reshape([eventNames'; eventNames'+"_Type"], [], 1);
            data = [trialInfo.Values(idcInfo, :) array2table(NaN(n, ...
                length(varNames)), "VariableNames", varNames)];
            t = func(double(trials.Values.Timestamp)/1e7);
            for ii = 1:n
                id = numbers(ii);
                for jj = 1:length(eventNames)
                    idx = find(trials.Values.Number==id & ...
                        trials.Values.Event==eventNames(jj), 1);
                    if isempty(idx)
                        continue
                    end
                    data{ii, eventNames(jj)} = t(idx);
                    data{ii, eventNames(jj)+"_Type"} = ...
                        double(trials.Values.Type(idx));
                end
            end
            obj = spiky.minos.Paradigm(name, periods, spiky.core.TimeTable(...
                func(double(data.Timestamp)/1e7), data), log.getParameters(func));
        end
    end

    methods
        function obj = Paradigm(name, periods, trials, vars)
            arguments
                name string = ""
                periods spiky.core.Periods = spiky.core.Periods.empty
                trials = []
                vars = []
            end
            obj.Name = name;
            obj.Periods = periods;
            obj.Trials = trials;
            obj.Vars = vars;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end