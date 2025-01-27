classdef Spikes < spiky.core.Events
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

        function [spikes, idc] = filter(obj, propArgs)
            % FILTER Filter spikes by metadata
            %
            %   propArgs: property filters from spiky.core.Spikes
            arguments
                obj spiky.core.Spikes
                propArgs.Group
                propArgs.Id
                propArgs.Region
                propArgs.Ch
                propArgs.ChInGroup
                propArgs.Label
                propArgs.Waveform
                propArgs.Amplitude
            end
            isValid = true(numel(obj), 1);
            names = string(fieldnames(propArgs));
            neurons = [obj.Neuron]';
            for ii = 1:numel(names)
                if isempty(propArgs.(names(ii)))
                    continue;
                end
                if isstring(propArgs.(names(ii)))
                    isValid = isValid & ismember([neurons.(names(ii))]', ...
                        propArgs.(names(ii)));
                elseif isnumeric(propArgs.(names(ii)))
                    isValid = isValid & ismember([neurons.(names(ii))]', ...
                        propArgs.(names(ii)));
                elseif isa(propArgs.(names(ii)), "function_handle")
                    isValid = isValid & propArgs.(names(ii))([neurons.(names(ii))]');
                end
            end
            spikes = obj(isValid);
            if nargout>1
                idc = find(isValid);
            end
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
                window double = [0 1]
            end
            trigSpikes = spiky.trig.TrigSpikes(obj, events, window);
        end

        function fr = trigFr(obj, events, window, options)
            % TRIGFR Trigger firing rate by events
            %
            %   events: event times
            %   window: time vector around events, e.g. -before:1/fs:after
            %   options: options for spiky.trig.TrigFr
            %
            %   fr: triggered firing rate
            arguments
                obj spiky.core.Spikes
                events % (n, 1) double or spiky.core.Events
                window double {mustBeVector}
                options.halfWidth double {mustBePositive} = 0.1
                options.kernel string {mustBeMember(options.kernel, ["gaussian", "box"])} = "gaussian"
            end
            optionsCell = namedargs2cell(options);
            fr = spiky.trig.TrigFr(obj, events, window, optionsCell{:});
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