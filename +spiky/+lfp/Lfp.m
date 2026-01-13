classdef Lfp < spiky.core.EventsTable
    %LFP Class representing a Local Field Potential signal in microvolts

    properties (Dependent)
        NChannels double
        NSamples double
    end
    
    methods
        function obj = Lfp(varargin)
            %LFP Create a new instance of Lfp
            %
            %   Lfp(data) creates a LFP signal starting at 0 with a sampling frequency of 1 kHz
            %   Lfp(time, data) creates a LFP signal with the time vector
            %   Lfp(start, fs, data) creates a LFP signal with the given start time and sampling frequency

            if nargin==1
                varargin = {0, 1e-3, varargin{1}};
            elseif nargin==3
                varargin{2} = 1/varargin{2};
            elseif nargin>3
                error("Invalid number of arguments")
            end
            obj@spiky.core.EventsTable(varargin{:});
            assert(isa(obj.Data, "double"), "Data must be a double array")
        end

        function n = get.NChannels(obj)
            n = size(obj.Data, 2);
        end

        function n = get.NSamples(obj)
            n = size(obj.Data, 1);
        end

        function v = get(obj, time, ch)
            %GET Get the value of the LFP signal at a given time and channel
            %
            %   v = get(obj, time, ch)
            %   time: time in seconds
            %   ch: channel number

            arguments
                obj spiky.lfp.Lfp
                time double
                ch double = []
            end
            if isempty(ch)
                ch = 1:obj.NChannels;
            end
            if obj.IsUniform
                idc = round((time-obj.Start)*obj.Fs)+1;
                v = obj.Data(idc, ch);
            else
                v = interp1(obj.Time, obj.Data(:, ch), time);
            end
        end

        function trigLfp = trig(obj, events, window)
            %TRIG Trigger the LFP signal on events
            %
            %   trigLfp = trig(obj, events, window)
            %   events: event times
            %   window: window around events, e.g. [-before after]. If scalar, it is interpreted 
            %       as [-window window]
            arguments
                obj spiky.lfp.Lfp
                events % (n, 1) double or spiky.core.Events
                window double = [0 1]
            end

            trigLfp = spiky.trig.TrigLfp(obj, events, window);
        end

        function obj = filter(obj, freqBand, filterClass, order, ripple)
            %FILTER Apply a filter to the LFP signal
            %
            %   obj = filter(obj, freqBand, filterClass, order, ripple)
            %
            %   freqBand: frequency band of the filter. 
            %       for band pass, use [low high]
            %       for low pass, use [0 high]
            %       for high pass, use [low Inf]
            %       for band stop, use [high low]
            %   filterClass: class of IIR filter, for now either cheby2 or butter
            %   order: filter order
            %   ripple: stopband attenuation
            %
            %   obj: Lfp object with the filtered data
            arguments
                obj spiky.lfp.Lfp
                freqBand (1, 2) double
                filterClass (1, 1) string {mustBeMember(filterClass, ["butter" "cheby2"])} = "butter"
                order (1, 1) double = 6
                ripple (1, 1) double = 20
            end

            nyquist = obj.Fs/2;
            if freqBand(2)>nyquist % highpass
                cutoff = freqBand(1)/nyquist;
                filterType = "high";
            elseif freqBand(1)==0 % lowpass
                cutoff = freqBand(2)/nyquist;
                filterType = "low";
            elseif freqBand(1)>freqBand(2) % bandstop
                cutoff = freqBand([2 1])/nyquist;
                filterType = "stop";
            elseif freqBand(2)>freqBand(1) % bandpass
                cutoff = freqBand/nyquist;
                filterType = "bandpass";
            else
                warning("Frequency band given has zero width!")
                return
            end
            switch filterClass
                case "butter"
                    [z, p, k] = butter(order, cutoff, filterType);
                case "cheby2"
                    [z, p, k] = cheby2(order, ripple, cutoff, filterType);
                otherwise
                    error("Unknown filter class %s", filterClass)
            end
            [sos, g] = zp2sos(z, p, k);
            obj.Data = filtfilt(sos, g, obj.Data);
        end

        function swr = findRipples(obj, options)
            %FINDRIPPLES Find sharp wave ripples in the LFP signal
            %
            %   swr = findRipples(obj, options)
            %
            %   obj: Lfp object
            %   options.FreqBand: frequency band of the ripple
            %   options.Threshold: threshold for ripple detection
            %   options.MinThreshold: minimum threshold for ripple detection
            %   options.MinCycles: minimum number of cycles for a ripple
            %   options.FilterClass: class of IIR filter, for now either cheby2 or butter
            %   options.FilterOrder: filter order
            %   options.Intervals: intervals to analyze

            arguments
                obj spiky.lfp.Lfp
                options.FreqBand (1, 2) double = [70 180]
                options.Threshold (1, 1) double = 5
                options.MinThreshold (1, 1) double = 3
                options.MinCycles (1, 1) double = 3
                options.FilterClass (1, 1) string {mustBeMember(options.FilterClass, ["butter" "cheby2"])} = "butter"
                options.FilterOrder (1, 1) double = 3
                options.Intervals = [] % (:, 2) double or spiky.core.Interval
            end

            if ~obj.IsUniform
                error("Data must be uniform")
            end
            if ~isvector(obj.Data)
                obj.Data = obj.Data(:, 1);
            end
            if isa(options.Intervals, "spiky.core.Interval")
                options.Intervals = options.Intervals.Time;
            end
            filt = obj.filter(options.FreqBand, options.FilterClass, options.FilterOrder);
            swrEnv = abs(hilbert(filt.Data));
            sigma = 0.1;
            kernelsize = 0.1*obj.Fs; % 100ms
            gaussFilter = gausswin(kernelsize, 1/(2.5*sigma));
            gaussFilter = gaussFilter./sum(gaussFilter); % Normalize.    
            swrEnv = conv(swrEnv, gaussFilter, "same");
            meanVol = mean(obj.Data);
            stdVol = std(obj.Data);
            if ~isempty(options.Intervals)
                [~, idc] = obj.inIntervals(options.Intervals);
            else
                idc = 1:obj.Length;
            end
            meanPower = mean(swrEnv(idc));
            stdPower = std(swrEnv(idc));
            thr = meanPower + options.Threshold*stdPower;
            % maxThr = meanPower + 30*stdPower;
            minThr = meanPower + options.MinThreshold*stdPower;
            %%
            [amp, t] = findpeaks(swrEnv, obj.Fs, MinPeakDistance=0.05, MinPeakHeight=thr, ...
                MinPeakProminence=thr-meanPower);
            if ~isempty(options.Intervals)
                [~, idc] = spiky.core.Events(t).inIntervals(options.Intervals);
                amp = amp(idc);
                t = t(idc);
            end
            ampNorm = (amp-meanPower)/stdPower;
            %%
            n = length(t);
            t1 = zeros(n, 1);
            onset = zeros(n, 1);
            offset = zeros(n, 1);
            cycles = zeros(n, 1);
            f = zeros(n, 1);
            troughs = cell(n, 1);
            lfp = obj.trig(t, 0.25);
            env = spiky.lfp.Lfp(obj.Start, obj.Fs, swrEnv).trig(t, 0.25);
            for ii = 1:n
                if ii>1 && t(ii)<=offset(ii-1)
                    continue
                end
                idx = find(diff(sign(env.Data(:, 1, ii)-minThr))~=0);
                idx1 = idx(find(idx<0.25*obj.Fs, 1, "last"))+1;
                idx2 = idx(find(idx>0.25*obj.Fs, 1, "first"));
                if isempty(idx1) || isempty(idx2)
                    continue
                end
                onset(ii) = t(ii)-(251-idx1)/obj.Fs;
                offset(ii) = t(ii)+(idx2-251)/obj.Fs;
                [~, ts] = findpeaks(-lfp.Data(:, 1, ii), obj.Fs, ...
                    MinPeakDistance=1/options.FreqBand(2), MinPeakHeight=0);
                ts = spiky.core.Events(t(ii)-0.25+ts).inIntervals([onset(ii) offset(ii)]);
                % [~, idx] = min(lfp.Data(round(ts*obj.Fs), 1, ii)); % Find the deepest trough
                [~, idx] = min(abs(ts-t(ii))); % Find the closest trough
                if isempty(idx) || isscalar(ts) || abs(obj.get(ts(idx))-meanVol)/stdVol>10
                    continue
                end
                troughs{ii} = ts;
                cycles(ii) = numel(ts);
                t1(ii) = ts(idx);
                f(ii) = 1/mean(diff(ts));
            end
            isValid = cycles>=options.MinCycles;
            swr = spiky.lfp.Swr(t1(isValid), onset(isValid), offset(isValid), cycles(isValid), ...
                f(isValid), amp(isValid), ampNorm(isValid), troughs(isValid), options);
        end

        function h = plot(obj, varargin)
            %PLOT Plot the LFP signal
            %
            %   plot(obj, varargin)
            %
            %   obj: Lfp object
            %   varargin: additional arguments passed to plot

            fg = findall(0, "Type", "Figure");
            if isempty(fg)
                spiky.plot.fig
            end
            if obj.NChannels==1
                h1 = plot(obj.Time, mean(obj.Data, 3), varargin{:});
                xlabel("Time (s)")
                ylabel("LFP (\muV)")
            else
                error("Not implemented")
            end
            box off
            if nargout>0
                h = h1;
            end
        end
    end
end