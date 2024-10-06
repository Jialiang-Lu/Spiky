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
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            trigSpikes(numel(obj), 1) = spiky.trig.TrigSpikes();
            parfor ii = 1:numel(obj)
                trigSpikes(ii, 1) = spiky.trig.TrigSpikes(obj(ii), events, window);
            end
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
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            t = window(:)';
            nRows = numel(events);
            nT = numel(t);
            res = t(2)-t(1);
            wAdd = round(options.halfWidth*3/res);
            idcAdd = wAdd+1:wAdd+nT;
            tWide = t(1)-wAdd*res:res:t(end)+wAdd*res+eps;
            windowWide = tWide([1 end]);
            edges = [tWide-res/2, tWide(end)+res/2];
            switch options.kernel
                case "gaussian"
                    kernel = exp(-0.5.*(tWide-(tWide(1)+tWide(end))/2).^2./options.halfWidth.^2)./...
                        (sqrt(2*pi)*options.halfWidth);
                case "box"
                    kernel = zeros(size(tWide));
                    idx = find(tWide-(tWide(1)+tWide(end))/2>=options.halfWidth, 1, "first");
                    idc = idx:idx+options.halfWidth*2/res-1;
                    kernel(idc) = 1/options.halfWidth/2;
                otherwise
                    error("Unknown kernel %s", options.kernel);
            end
            % if numel(obj)>1
            %     spiky.plot.timedWaitbar(0, "Analyzing spikes");
            % end
            fr(numel(obj), 1) = spiky.trig.TrigFr;
            parfor ii = 1:numel(obj)
                fr1 = zeros(nRows, nT);
                tr = obj(ii).trig(events, windowWide);
                for jj = nRows:-1:1
                    sp = tr.Data{jj};
                    spWide = histcounts(sp, edges);
                    spWide = conv(spWide, kernel, "same");
                    fr1(jj, :) = spWide(idcAdd);
                end
                fr(ii, 1) = spiky.trig.TrigFr(obj(ii).Neuron, ...
                    spiky.core.TimeTable(events, table(fr1, VariableNames="Fr")), ...
                    t, options);
                % if numel(obj)>1
                %     spiky.plot.timedWaitbar((numel(obj)-ii+1)/numel(obj));
                % end
            end
            % if numel(obj)>1
            %     spiky.plot.timedWaitbar([]);
            % end
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