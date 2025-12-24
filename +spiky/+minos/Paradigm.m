classdef Paradigm < spiky.core.MappableArray & spiky.core.Metadata
    %PARADIGM represents paradigm data

    properties
        Name string
        Intervals spiky.core.Intervals
        Trials spiky.core.EventsTable
        TrialInfo spiky.core.EventsTable
        Vars spiky.core.Parameter
        Latency double
    end

    methods (Static)
        function obj = load(fdir, intervals, func, photodiode)
            %LOAD Load a paradigm from a directory
            %
            %   fdir: directory containing the paradigm data
            %   func: function to convert the time
            %
            %   obj: paradigm object
            arguments
                fdir (1, 1) string {mustBeFolder}
                intervals spiky.core.Intervals
                func = @(x) x
                photodiode double = []
            end
            [~, name] = fileparts(fdir);
            name = strrep(name, " ", "");
            log = spiky.minos.Data(fullfile(fdir, "Log.txt"));
            trials = spiky.minos.Data(fullfile(fdir, "Trials.bin"));
            trialInfo = spiky.minos.Data(fullfile(fdir, "TrialInfo.bin"));
            eventNames = unique(trials.Data.Event, "stable");
            eventNames = eventNames(~ismember(eventNames, ...
                ["ParadigmStart", "ParadigmStop"]));
            eventNames = string(eventNames);
            eventsCount = groupsummary(trials.Data, "Event", ...
                @(x) sum(x==mode(x)), "Number");
            eventsCount = eventsCount(~ismember(eventsCount.Event, ...
                ["ParadigmStart", "ParadigmStop", "Loading"]), :);
            eventsCount = eventsCount.fun1_Number;
            if any(eventsCount>1)
                error("Not implemented")
            end
            trials.Data = groupfilter(trials.Data, "Number", ...
                @(s) all(~ismember(s, ...
                ["ParadigmStart", "ParadigmStop"])), "Event");
            numbers = unique(trials.Data.Number, "stable");
            isValidInfo = ismember(trialInfo.Data.Number, numbers);
            trialInfo = trialInfo(isValidInfo, :);
            singleInfo = numel(trialInfo.Data.Number)==numel(unique(trialInfo.Data.Number));
            [~, idcInfo] = ismember(numbers, trialInfo.Data.Number(end:-1:1));
            idcInfo = length(trialInfo.Data.Number)-idcInfo+1;
            n = length(numbers);
            varNames = reshape([eventNames'; eventNames'+"_Type"], [], 1);
            if singleInfo
                data = [trialInfo.Data(idcInfo, :) array2table(NaN(n, ...
                    length(varNames)), "VariableNames", varNames)];
            else
                data = [trialInfo.Data(idcInfo, ["Timestamp" "Number"]) array2table(NaN(n, ...
                    length(varNames)), "VariableNames", varNames)];
            end
            info = spiky.core.EventsTable(func(double(trialInfo.Timestamp)/1e7), trialInfo.Data);
            t = func(double(trials.Data.Timestamp)/1e7);
            nEvents = length(eventNames);
            if ~isempty(photodiode)
                eventLatencies = NaN(nEvents, 1);
                eventCounts = NaN(nEvents, 1);
                for ii = 1:nEvents
                    isEvent1 = trials.Data.Event==eventNames(ii);
                    t1 = t(isEvent1);
                    p1 = spiky.core.Intervals([t1 t1+0.15]);
                    e1 = p1.haveEvents(photodiode, CellModetrue);
                    l1 = cellfun(@length, e1)';
                    if sum(l1>0)/length(l1)>0.8
                        isValid = l1>0;
                        tValid = cellfun(@(x) x(1), e1(isValid));
                        tdMean = mean(tValid-t1(isValid));
                        fprintf("Average latency for %s in %s is %.1f(+/-%.1f) ms\n", ...
                            eventNames(ii), name, tdMean*1000, std(tValid-t1(isValid))*1000)
                        t2 = t1;
                        t2(isValid) = tValid;
                        t2(~isValid) = t1(~isValid)+tdMean;
                        t(isEvent1) = t2;
                        eventLatencies(ii) = tdMean;
                        eventCounts(ii) = sum(isValid);
                    else
                        fprintf("No photodiode signal for %s in %s\n", eventNames(ii), name)
                    end
                end
                latency = mean(eventLatencies, "omitnan", Weights=eventCounts);
            else
                latency = 0;
            end
            for ii = 1:n
                id = numbers(ii);
                for jj = 1:length(eventNames)
                    idx = find(trials.Data.Number==id & ...
                        trials.Data.Event==eventNames(jj), 1);
                    if isempty(idx)
                        continue
                    end
                    data{ii, eventNames(jj)} = t(idx);
                    data{ii, eventNames(jj)+"_Type"} = ...
                        double(trials.Data.Type(idx));
                end
            end
            obj = spiky.minos.Paradigm(name, intervals, spiky.core.EventsTable(...
                func(double(data.Timestamp)/1e7), data), info, log.getParameters(func), latency);
        end
    end

    methods
        function obj = Paradigm(name, intervals, trials, trialInfo, vars, latency)
            arguments
                name string = ""
                intervals spiky.core.Intervals = spiky.core.Intervals
                trials spiky.core.EventsTable = spiky.core.EventsTable
                trialInfo spiky.core.EventsTable = spiky.core.EventsTable
                vars spiky.core.Parameter = spiky.core.Parameter
                latency double = NaN
            end
            obj.Name = name;
            obj.Intervals = intervals;
            obj.Trials = trials;
            obj.TrialInfo = trialInfo;
            obj.Vars = vars;
            obj.Latency = latency;
        end

        function trials = getTrials(obj, var, value)
            %GETTRIALS Get the trials satisfying certain conditions
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
                trials = spiky.core.EventsTable;
                return
            end
            prds = cell(length(var), 1);
            for ii = length(var):-1:1
                prds{ii} = obj.Vars(var{ii}).getIntervals(value{ii});
            end
            intervals = spiky.core.Intervals.intersect(prds{:});
            [~, idc1] = intervals.haveEvents(obj.Trials.Time);
            trials = obj.Trials(idc1, :);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end