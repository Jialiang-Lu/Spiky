classdef Spikes < spiky.core.Array
    %SPIKES Spikes of a neuron
    %
    %   Fields:
    %       Neuron: spiky.core.Neuron object representing the neuron
    %       Data: cell array of spike times in seconds

    properties
        Neuron (:, 1) spiky.core.Neuron
    end

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {"Neuron"};
        end
    end

    methods
        function obj = Spikes(neuron, data)
            arguments
                neuron spiky.core.Neuron = spiky.core.Neuron
                data cell = {}
            end
            assert(all(cellfun(@(x) isnumeric(x) && iscolumn(x), data)), ...
                "Data must be a cell array of numeric vectors representing spike times");
            obj.Neuron = neuron;
            obj.Data = data;
            obj.verifyDimLabels();
        end

        function [spikes, idc] = filter(obj, propArgs)
            %FILTER Filter spikes by metadata
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
                propArgs.Amplitude
            end
            isValid = true(numel(obj), 1);
            names = string(fieldnames(propArgs));
            for ii = 1:numel(names)
                if isempty(propArgs.(names(ii)))
                    continue;
                end
                if isstring(propArgs.(names(ii)))
                    isValid = isValid & ismember(obj.Neuron.(names(ii)), ...
                        propArgs.(names(ii)));
                elseif isnumeric(propArgs.(names(ii)))
                    isValid = isValid & ismember(obj.Neuron.(names(ii)), ...
                        propArgs.(names(ii)));
                elseif isa(propArgs.(names(ii)), "function_handle")
                    isValid = isValid & propArgs.(names(ii))(obj.Neuron.(names(ii)));
                end
            end
            spikes = subsref(obj, substruct('()', {isValid}));
            if nargout>1
                idc = find(isValid);
            end
        end

        function trigSpikes = trig(obj, events, window)
            %TRIG Trigger spikes by events
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
            if isscalar(window)
                window = [0 window];
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
                prds = [events+window(1), events+window(end)];
            elseif isa(events, "spiky.core.Intervals")
                prds = events.Time;
                events = events.Start;
                window = prds;
            elseif isnumeric(events)
                if width(events)==2
                    prds = events;
                    events = events(:, 1);
                    window = prds;
                elseif isvector(events)
                    events = events(:);
                    prds = [events+window(1), events+window(end)];
                else
                    error("Events must be a vector or a 2-column matrix");
                end
            end
            prds = spiky.core.Intervals(prds);
            nNeurons = numel(obj.Data);
            s = cell(height(events), nNeurons);
            parfor ii = 1:nNeurons
                s(:, ii) = prds.haveEvents(obj.Data{ii}, CellMode=true, Offset=window(1));
            end
            trigSpikes = spiky.trig.TrigSpikes(events, s, window, obj.Neuron);
        end

        function fr = fr(obj, events, window, options)
            %FR Firing rate by events
            %
            %   events: event times
            %   window: [start end] window around events
            %   options: options for spiky.trig.TrigFr
            %
            %   fr: firing rate
            arguments
                obj spiky.core.Spikes
                events % (n, 1) double or spiky.core.Events
                window (1, 2) double
                options.Normalize logical = false
            end
            fr = obj.trigFr(events, mean(window), HalfWidth=diff(window)/2, ...
                Kernel="box", Normalize=options.Normalize);
        end

        function counts = trigCounts(obj, events, window, options)
            %TRIGCOUNTS Trigger counts by events
            %
            %   events: event times
            %   window: time vector around events, e.g. -before:1/fs:after
            %   Name-value arguments:
            %       Bernoulli: if true, counts are binary (0 or 1)
            %
            %   counts: triggered counts
            arguments
                obj spiky.core.Spikes
                events % (n, 1) double or spiky.core.Events
                window double {mustBeVector}
                options.Bernoulli logical = false % If true, counts are binary (0 or 1)
            end
            counts = spiky.trig.TrigCounts(obj, events, window, Bernoulli=options.Bernoulli);
        end

        function fr = trigFr(obj, events, window, options)
            %TRIGFR Compute firing rate triggered by events
            %
            %   fr = trigFr(obj, events, window, options)
            %
            %   obj: Spikes object or array of Spikes objects
            %   events: (n, 1) double or Events object
            %   window: time window around the events
            %   Name-value arguments:
            %       HalfWidth: half-width of the kernel (default: 0.1)
            %       Kernel: smoothing kernel, "gaussian" or "box" (default: "gaussian")
            %       Normalize: if true, normalize the firing rate (default: false)
            %       Unit: "Hz" or "count" for the output unit (default: "Hz")
            %
            %   obj: TrigFr object

            arguments
                obj spiky.core.Spikes = spiky.core.Spikes
                events = [] % (n, 1) double or spiky.core.Events
                window double {mustBeVector} = [0, 1]
                options.HalfWidth double {mustBePositive} = 0.1
                options.Kernel string {mustBeMember(options.Kernel, ["gaussian", "box"])} = "gaussian"
                options.Normalize logical = false
                options.Unit string {mustBeMember(options.Unit, ["Hz", "count"])} = "Hz"
            end
            if nargin==0 || isempty(obj)
                fr = spiky.trig.TrigFr;
                return
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            t = window(:);
            nEvents = numel(events);
            nT = numel(t);
            if isscalar(t)
                res = options.HalfWidth*2;
            else
                res = t(2)-t(1);
            end
            nNeurons = height(obj);
            switch options.Kernel
                case "box"
                    fr = zeros(nT, nEvents, nNeurons);
                    prds = reshape(events'+t, [], 1);
                    prds = spiky.core.Intervals([prds-options.HalfWidth prds+options.HalfWidth]);
                    [prds, idcSort] = prds.sort();
                    idcSort2(idcSort) = 1:numel(idcSort);
                    parfor ii = 1:nNeurons
                        [~, c] = spiky.mex.findInIntervals(obj{ii}, prds.Time);
                        c = c(idcSort2)./options.HalfWidth/2;
                        if options.Normalize
                            c = (c-mean(c))./sqrt(mean(c)./options.HalfWidth/2);
                        end
                        fr(:, :, ii) = reshape(c, nT, nEvents);
                    end
                case "gaussian"
                    wAdd = round(options.HalfWidth*3/res);
                    idcAdd = wAdd+1:wAdd+nT;
                    tWide = (t(1)-wAdd*res:res:t(end)+wAdd*res)';
                    kernel = exp(-0.5.*(tWide-(tWide(1)+tWide(end))/2).^2./options.HalfWidth.^2)./...
                        (sqrt(2*pi)*options.HalfWidth)*res;
                    fr = obj.trigFr(events, tWide, HalfWidth=res/2, Kernel="box", Unit=options.Unit);
                    fr.Data = convn(fr.Data, kernel, "same");
                    if options.Normalize
                        m = mean(fr.Data, [1 2]);
                        fr.Data = (fr.Data-m)./sqrt(m./res);
                    end
                    fr.Data = fr.Data(idcAdd, :, :);
                    fr.Start_ = t(1);
                    fr.Step_ = res;
                    fr.N_ = nT;
                    fr.Window = window;
                    fr.Options = options;
                    return
                otherwise
                    error("Unknown kernel %s", options.Kernel);
            end
            if options.Unit=="Count"
                fr = fr*res;
            end
            fr = spiky.trig.TrigFr(t(1), res, fr, events, window, obj.Neuron);
            fr.Options = options;
        end

        function zeta = zeta(obj, events, window, options)
            %ZETA Zeta test for neuronal responsiveness
            %
            %   events: event times
            %   window: time window for the Zeta test
            %   options: options for the Zeta test
            %
            %   zeta: Zeta object with results of the Zeta test
            arguments
                obj spiky.core.Spikes
                events % (n, 1) double or spiky.core.Events
                window (1, 1) double = 1
                options.NumResample (1, 1) double = 100
            end
            zeta = spiky.stat.Zeta(obj, events, window, ...
                NumResample=options.NumResample);
        end
    end
end