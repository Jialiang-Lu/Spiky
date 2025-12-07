classdef Swr < spiky.core.TimeTable
    %SWR Class representing Sharp Wave Ripple events

    properties
        Options = struct
    end
    
    properties (Dependent)
        Onset double
        Offset double
        Duration double
        NCycles double
        Freq double
        Amplitude double
        AmplitudeNorm double
        Troughs cell
    end

    methods 
        function obj = Swr(time, onsets, offsets, cycles, freqs, amplitudes, amplitudesNorm, troughs, ...
            options)
            %SWR Create a new instance of Swr
            %
            %   Swr(time, onsets, offsets, cycles, freqs, amplitudes, amplitudesNorm, troughs)
            %   time: time vector
            %   onsets: onset times
            %   offsets: offset times
            %   cycles: number of cycles
            %   freqs: frequency
            %   amplitudes: amplitude
            %   amplitudesNorm: normalized amplitude
            %   troughs: troughs
            
            arguments
                time double = []
                onsets double = []
                offsets double = []
                cycles double = []
                freqs double = []
                amplitudes double = []
                amplitudesNorm double = []
                troughs cell = {}
                options struct = struct
            end
            obj@spiky.core.TimeTable(time, table(onsets, offsets, cycles, freqs, amplitudes, ...
                amplitudesNorm, troughs, VariableNames=["Onset" "Offset" "NCycles" "Freq" "Amplitude"...
                    "AmplitudeNorm" "Troughs"]));
            obj.Options = options;
        end

    end
end