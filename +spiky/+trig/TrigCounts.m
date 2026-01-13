classdef TrigCounts < spiky.trig.TrigFr
    %TRIGCOUNTS Class for counting spikes triggered by events

    properties
        Bernoulli logical = false % If true, counts are binary (0 or 1)
    end

    methods
        function obj = TrigCounts(spikes, events, window, options)
            arguments
                spikes spiky.core.Spikes = spiky.core.Spikes
                events = [] % (n, 1) double or spiky.core.Events
                window double {mustBeVector} = [0, 1]
                options.Bernoulli logical = false % If true, counts are binary (0 or 1)
            end
            if nargin==0 || isempty(spikes)
                return
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            t = window(:);
            nEvents = numel(events);
            nT = numel(t);
            res = t(2)-t(1);
            nNeurons = numel(spikes);
            counts = zeros(nT, nEvents, nNeurons);
            prds = reshape(events'+t, [], 1);
            prds = spiky.core.Intervals([prds-res/2 prds+res/2]);
            [prds, idcSort] = prds.sort();
            idcSort2(idcSort) = 1:numel(idcSort);
            parfor ii = 1:nNeurons
                [~, c] = spiky.mex.findInIntervals(spikes(ii).Time, prds.Time);
                counts(:, :, ii) = reshape(c, nT, nEvents);
            end
            if options.Bernoulli
                counts(counts>1) = 1;
            end
            obj.Start_ = t(1);
            obj.Step_ = res;
            obj.N_ = nT;
            obj.Data = counts;
            obj.EventDim = 2;
            obj.Events_ = events;
            obj.Window = window;
            obj.Neuron = spikes.Neuron;
            obj.Options = options;
            obj.Bernoulli = options.Bernoulli;
        end

        function mdl = fitGlm(obj, labels, options)
            %FITGLM Fit a GLM to the counts
            %
            %   mdl = fitGlm(obj, options)
            %
            %   obj: TrigCounts
            %   options: Name-Value pairs for additional options
            %
            %   mdl: fitted GLM model
            arguments
                obj spiky.trig.TrigCounts
                labels spiky.stat.Labels
                options.Intervals = [] % (n, 2) double or spiky.core.Intervals
            end
            names = compose("%s.%s.%d", labels.Name, labels.Class, labels.BaseIndex);
            if obj.Bernoulli
                distr = "binomial";
            else
                distr = "poisson";
            end
            if ~isempty(options.Intervals)
                if isnumeric(options.Intervals)
                    options.Intervals = spiky.core.Intervals(options.Intervals);
                end
                [~, idc] = options.Intervals.haveEvents(obj.Time);
            else
                idc = true(height(obj.Time), 1);
            end
            dataRaw = obj.Data(idc, 1, :);
            data = cell(1, size(obj.Data, 3));
            pb = spiky.plot.ProgressBar(size(obj.Data, 3), "Fitting GLM", Parallel=true, ...
                CloseOnFinish=false);
            parfor ii = 1:size(obj.Data, 3)
                data{ii} = fitglm(labels.Data(idc, :), dataRaw(:, :, ii), "linear", ...
                    Distribution=distr, VarNames=[names; "spikes"]);
                pb.step
            end
            mdl = spiky.stat.GLM(0, data, obj.Neuron);
        end
    end
end