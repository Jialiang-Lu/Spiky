classdef Spikes < spiky.core.Events & ...
    spiky.core.MappableArray & spiky.core.ArrayDisplay
    % SPIKES Spikes of a neuron

    properties
        Neuron spiky.core.Neuron
    end

    methods
        function obj = Spikes(neuron, time)
            arguments
                neuron spiky.core.Neuron = spiky.core.Neuron.empty
                time = []
            end
            obj.Neuron = neuron;
            obj.Time = time(:);
        end

        function spikes = filter(obj, propArgs)
            % FILTER Filter spikes by metadata
            %
            %   var: metadata variable
            %   propArgs: property filters from spiky.core.Spikes
            arguments
                obj spiky.core.Spikes
                propArgs.?spiky.core.Neuron
            end
            isValid = true(numel(obj), 1);
            names = string(fieldnames(propArgs));
            neurons = [obj.Neuron]';
            for ii = 1:numel(names)
                isValid = isValid & ismember([neurons.(names(ii))]', ...
                    propArgs.(names(ii)));
            end
            spikes = obj(isValid);
        end

        function trigSpikes = trig(obj, events, window)
            % TRIG Trigger spikes by events
            %
            %   events: event times
            %   window: 1x2 window around events, e.g. [-before after]
            %
            %   trigSpikes: triggered spikes
            arguments
                obj spiky.core.Spikes
                events % (n, 1) double or spiky.core.Events
                window (1, 2) double = [0 1]
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            spiky.plot.timedWaitbar(0, "Analyzing spikes");
            for ii = numel(obj):-1:1
                spikes = obj(ii).inPeriods([events+window(1), events+window(2)], true, window(1));
                trigSpikes(ii, 1) = spiky.trig.TrigSpikes(obj(ii).Neuron, ...
                    events, spikes, window);
                spiky.plot.timedWaitbar((numel(obj)-ii+1)/numel(obj));
            end
            spiky.plot.timedWaitbar([]);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            if ~isempty(obj.Neuron)
                key = obj.Neuron.Str;
            else
                key = "";
            end
        end
    end
end