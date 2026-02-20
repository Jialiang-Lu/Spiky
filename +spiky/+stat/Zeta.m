classdef Zeta < spiky.stat.GroupedStat
    %ZETA Class for Zeta tests results for neuronal responsiveness
    %   http://dx.doi.org/10.7554/eLife.71969
    %
    %   Fields:
    %       P: p-values of the Zeta test (depending on the resampling)
    %       Z: Zeta values, responsiveness z-score (depending on the resampling)
    %       D: temporal deviation value underlying ZETA (fixed)
    %       Onset: onset time of the response, latency of largest z-score with inverse sign to ZETA
    %       HalfPeak: half-peak time of the response
    %       Peak: peak time of the response
    %       Offset: offset time of the response, Latency of ZETA
    %       PeakFr: peak firing rate of the response
    %       Window: time window of the response
    %       Events: events used for the Zeta test
    %       Options: options for the Zeta test, including:
    %           NumResample: number of resamples for the Zeta test (default: 100)

    properties
        Window (1, 1) double % time window for the Zeta test
        Events % events used for the Zeta test
        Options struct % options for the Zeta test
    end
    
    methods
        function obj = Zeta(data, window, events, options, groups)
            %ZETA Constructor for the Zeta class
            %
            arguments
                data (1, :) struct = struct.empty % data for the Zeta test
                window (1, 1) double = NaN % time window for the Zeta test
                events (:, 1) double = []
                options struct = struct() % options for the Zeta test
                groups (:, 1) = categorical(strings(size(data, 2), 1))
            end
            obj@spiky.stat.GroupedStat(0, data, groups);
            obj.Window = window;
            obj.Events = events;
            obj.Options = options;
        end
    end
end