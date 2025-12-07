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
        function obj = Zeta(spikes, events, window, options)
            %ZETA Constructor for the Zeta class
            %
            arguments
                spikes spiky.core.Spikes
                events
                window (1, 1) double = 1
                options.NumResample (1, 1) double = 100
            end

            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            n = height(spikes);
            nResample = options.NumResample;
            p = cell(1, n);
            z = cell(1, n);
            d = cell(1, n);
            onset = cell(1, n);
            halfPeak = cell(1, n);
            peak = cell(1, n);
            offset = cell(1, n);
            peakFr = cell(1, n);
            pb = spiky.plot.ProgressBar(n, "Performing Zeta test", Parallel=true);
            parfor ii = 1:n
                [p1, s1, s2, s3] = spiky.utils.zetatest.zetatest(spikes(ii).Time, events, window, ...
                    nResample);
                if ~isempty(s2)
                    p{ii} = p1;
                    z{ii} = s1.dblZETA;
                    d{ii} = s1.dblD;
                    onset{ii} = s2.vecPeakStartStop(1);
                    halfPeak{ii} = s3.Onset;
                    peak{ii} = s3.Peak;
                    offset{ii} = s2.vecPeakStartStop(2);
                    peakFr{ii} = s1.vecLatencyVals(3);
                else
                    p{ii} = 1;
                    z{ii} = 0;
                    d{ii} = 0;
                    onset{ii} = NaN;
                    halfPeak{ii} = NaN;
                    peak{ii} = NaN;
                    offset{ii} = NaN;
                    peakFr{ii} = NaN;
                end
                pb.step
            end
            data = struct("P", p, "Z", z, "D", d, ...
                "Onset", onset, "HalfPeak", halfPeak, "Peak", peak, ...
                "Offset", offset, "PeakFr", peakFr);
            groups = vertcat(spikes.Neuron);
            obj@spiky.stat.GroupedStat(0, data, groups);
            obj.Window = window;
            obj.Events = events;
            obj.Options = options;
        end
    end
end