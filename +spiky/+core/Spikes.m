classdef Spikes < spiky.core.Events & ...
    spiky.core.MappableArray
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

        function trigSpikes = trig(obj, periods, duration)
            % TRIG Trigger spikes by periods
            %
            %   periods: periods as spiky.core.Periods or (n, 2) double
            %
            %   trigSpikes: triggered spikes
            arguments
                obj spiky.core.Spikes
                periods % spiky.core.Periods or (n, 2) double
                duration double = 0
            end
            if ~isa(periods, "spiky.core.Periods")
                if isvector(periods)
                    periods = periods(:);
                    periods = [periods periods+duration];
                end
                periods = spiky.core.Periods(periods);
            end
            spiky.plot.timedWaitbar(0, "Triggering spikes");
            for ii = numel(obj):-1:1
                spikes = periods.haveEvents(obj(ii).Time, true, 0);
                trigSpikes(ii, 1) = spiky.trig.TrigSpikes(obj(ii).Neuron, ...
                    periods, spikes);
                spiky.plot.timedWaitbar((numel(obj)-ii+1)/numel(obj));
            end
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