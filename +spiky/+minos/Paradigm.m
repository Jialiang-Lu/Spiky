classdef Paradigm < spiky.core.MappableArray & spiky.core.Metadata
    % PARADIGM represents paradigm data

    properties
        Name string
        Periods spiky.core.Periods
        Trials spiky.core.TimeTable
        Vars spiky.core.Parameter
    end

    methods (Static)
        function obj = load(fdir, periods, func, photodiode)
            % LOAD Load a paradigm from a directory
            %
            %   fdir: directory containing the paradigm data
            %   func: function to convert the time
            %
            %   obj: paradigm object
            arguments
                fdir (1, 1) string {mustBeFolder}
                periods spiky.core.Periods
                func = @(x) x
                photodiode double = []
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
            numbers = unique(trials.Values.Number, "stable");
            [~, idcInfo] = ismember(numbers, trialInfo.Values.Number(end:-1:1));
            idcInfo = length(trialInfo.Values.Number)-idcInfo+1;
            n = length(numbers);
            varNames = reshape([eventNames'; eventNames'+"_Type"], [], 1);
            data = [trialInfo.Values(idcInfo, :) array2table(NaN(n, ...
                length(varNames)), "VariableNames", varNames)];
            t = func(double(trials.Values.Timestamp)/1e7);
            nEvents = length(eventNames);
            if ~isempty(photodiode)
                for ii = 1:nEvents
                    isEvent1 = trials.Values.Event==eventNames(ii);
                    t1 = t(isEvent1);
                    p1 = spiky.core.Periods([t1 t1+0.1]);
                    e1 = p1.haveEvents(photodiode, true);
                    l1 = cellfun(@length, e1)';
                    if sum(l1>0)/length(l1)>0.9
                        isValid = l1>0;
                        tValid = cellfun(@(x) x(1), e1(isValid));
                        tdMean = mean(tValid-t1(isValid));
                        fprintf("Average latency for %s in %s is %.1f(+/-%.1f) ms\n", ...
                            eventNames(ii), name, tdMean*1000, std(tValid-t1(isValid))*1000)
                        t2 = t1;
                        t2(isValid) = tValid;
                        t2(~isValid) = t1(~isValid)+tdMean;
                        t(isEvent1) = t2;
                    end
                end
            end
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
                trials spiky.core.TimeTable = spiky.core.TimeTable.empty
                vars spiky.core.Parameter = spiky.core.Parameter.empty
            end
            obj.Name = name;
            obj.Periods = periods;
            obj.Trials = trials;
            obj.Vars = vars;
        end

        function trials = getTrials(obj, var, value)
            % GETTRIALS Get the trials satisfying certain conditions
            %   trials = getTrials(obj, var1, value1, var2, value2, ...)
            %
            %   obj: paradigm object
            %   var: variable name
            %   value: value(s) or function handle
            %
            %   trials: trials
            arguments
                obj spiky.minos.Paradigm
            end
            arguments (Repeating)
                var string
                value % value(s) or function handle
            end
            n = height(obj.Trials);
            if n==0 || isempty(var)
                trials = spiky.core.TimeTable.empty;
                return
            end
            prds = cell(length(var), 1);
            for ii = length(var):-1:1
                prds{ii} = obj.Vars(var{ii}).getPeriods(value{ii});
            end
            periods = spiky.core.Periods.intersect(prds{:});
            [~, idc1] = periods.haveEvents(obj.Trials.Time);
            trials = obj.Trials(idc1, :);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end