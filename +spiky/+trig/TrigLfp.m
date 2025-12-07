classdef TrigLfp < spiky.trig.Trig & spiky.lfp.Lfp
    %TRIGLFP Class representing a Local Field Potential signal triggered by events

    methods
        function obj = TrigLfp(lfp, events, window)
            %TRIGLFP Create a new instance of TrigLfp
            %
            %   TrigLfp(lfp, events, window) creates a new instance of TrigLfp
            %   lfp: spiky.lfp.Lfp object
            %   events: event times
            %   window: window around events, e.g. [-before after]. If scalar, it is interpreted 
            %       as [-window window]
            arguments
                lfp spiky.lfp.Lfp
                events % (n, 1) double or spiky.core.Events
                window double = [0 1]
            end

            if ~lfp.IsUniform
                error("LFP must be uniform")
            end
            if isscalar(window)
                window = [-window window];
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            tWindow = (round(window(1)*lfp.Fs):round(window(end)*lfp.Fs))';
            idc = round((events-lfp.Start)*lfp.Fs)'+tWindow;
            isValid = all(idc>0&idc<=lfp.Length, 1);
            events = events(isValid);
            nEvents = numel(events);
            nT = numel(tWindow);
            idc = idc(:, isValid);
            data = permute(reshape(lfp.Data(idc(:), :), nT, nEvents, lfp.NChannels), [1 3 2]);
            obj@spiky.lfp.Lfp(tWindow(1)/lfp.Fs, lfp.Fs, data);
            obj.EventDim = 3;
            obj.Events_ = events;
            obj.Window = window;
        end
    end
end