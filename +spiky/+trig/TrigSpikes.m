classdef TrigSpikes
    % TRIGSPIKES Spikes triggered by events

    properties
        Neuron spiky.core.Neuron
        Periods spiky.core.Periods
        Spikes cell
    end

    properties (Dependent)
        Time
        Fr
    end
    
    methods
        function obj = TrigSpikes(neuron, periods, spikes)
            arguments
                neuron spiky.core.Neuron = spiky.core.Neuron.empty
                periods spiky.core.Periods = spiky.core.Periods.empty
                spikes cell = {}
            end
            obj.Neuron = neuron;
            obj.Periods = periods;
            obj.Spikes = spikes;
        end

        function time = get.Time(obj)
            time = obj.Periods.Time(:, 1);
        end

        function fr = get.Fr(obj)
            fr = cellfun(@length, obj.Spikes)./obj.Periods.Duration;
        end
    end
end