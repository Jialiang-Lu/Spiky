classdef TrigCounts < spiky.trig.TrigFr
    % TRIGCOUNTS Class for counting spikes triggered by events

    methods
        function obj = TrigCounts(spikes, events, window, options)
            arguments
                spikes spiky.core.Spikes = spiky.core.Spikes.empty
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
            prds = spiky.core.Periods([prds-res/2 prds+res/2]);
            [prds, idcSort] = prds.sort();
            idcSort2(idcSort) = 1:numel(idcSort);
            parfor ii = 1:nNeurons
                [~, c] = spiky.mex.findInPeriods(spikes(ii).Time, prds.Time);
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
            obj.Neuron = vertcat(spikes.Neuron);
            obj.Options = options;
        end
    end
end