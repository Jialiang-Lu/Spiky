classdef SpikeInfo < spiky.core.Metadata

    properties
        Spikes spiky.core.Spikes
        Options struct
    end

    methods
        function obj = SpikeInfo(spikes, options)
            arguments
                spikes (:, 1) spiky.core.Spikes = spiky.core.Spikes.empty
                options struct = struct
            end
            obj.Spikes = spikes;
            obj.Options = options;
        end
    end
end