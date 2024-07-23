classdef Spikes < spiky.core.MappableArray

    properties
        Neuron spiky.core.Neuron
        Time (:, 1) double
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
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Neuron.Str;
        end
    end
end