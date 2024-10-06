classdef TrigSpikes < spiky.trig.Trig & spiky.core.Spikes
    % TRIGSPIKES Spikes triggered by events

    properties (Dependent)
        Fr double
    end
    
    methods
        function obj = TrigSpikes(spikes, events, window)
            %TRIGSPIKES Create a new instance of TrigSpikes
            %
            %   TrigSpikes(spikes, events, window) creates a new instance of TrigSpikes
            %   spikes: spiky.core.Spikes object
            %   events: event times
            %   window: window around events, e.g. [-before after], if scalar, it is interpreted as
            %       [0 window]
            arguments
                spikes spiky.core.Spikes = spiky.core.Spikes.empty
                events = [] % (n, 1) double or spiky.core.Events
                window double = [0, 1]
            end
            if nargin==0
                return
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            if isscalar(window)
                window = [0 window];
            end
            s = spikes.inPeriods([events+window(1), events+window(end)], true, window(1));
            obj.T_ = events;
            obj.Window = window;
            obj.Data = s;
            obj.Neuron = spikes.Neuron;
        end

        function fr = get.Fr(obj)
            fr = obj.getFr();
        end

        function fr = getFr(obj, window, cats)
            %GETFR Get firing rate in a window
            %
            %   fr = getFr(obj, window)
            %
            %   obj: triggered spikes object
            %   window: window for the analysis
            %   cats: categories for the events
            %
            %   fr: [nNeurons, nCats] firing rate
            arguments
                obj spiky.trig.TrigSpikes
                window double = []
                cats (:, 1) categorical = categorical.empty
            end
            if isempty(obj(1).Data)
                fr = [];
                return
            end
            if isempty(window)
                window = obj(1).Window;
            end
            if isempty(cats)
                cats = 1:height(obj(1).Data);
                nCats = numel(cats);
            elseif isscalar(cats)
                cats = zeros(height(obj(1).Data), 1);
                nCats = 1;
            else
                nCats = numel(categories(cats));
            end
            if numel(cats)~=height(obj(1).Data)
                error("Number of categories must match the number of events");
            end
            w = diff(window);
            fr = zeros(numel(obj), nCats);
            parfor ii = 1:numel(obj)
                fr1 = cellfun(@(x) sum(x>=window(1) & x<=window(2))/w, obj(ii).Data);
                fr(ii, :) = groupsummary(fr1, cats, @mean, IncludeEmptyGroups=true);
            end
        end

        function mdl = fitcecoc(obj, labels, window, idcEvents, options)
            % FITCECOC Fit a multiclass error-correcting output codes model
            %
            %   mdl = fitcecoc(obj, window, labels)
            %
            %   obj: triggered firing rate object
            %   labels: labels for the classes
            %   window: window for the analysis
            %   options: additional arguments passed to fitcecoc
            %
            %   mdl: trained model
            arguments
                obj spiky.trig.TrigSpikes
                labels
                window double = []
                idcEvents = []
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} = "onevsall"
                options.KFold double = []
                options.ClassNames = []
            end

            if isempty(window)
                window = obj(1).Window;
            end
            labels = labels(:);
            n = height(obj(1).Data);
            if isempty(idcEvents)
                idcEvents = true(n, 1);
            end
            labels = labels(idcEvents);
            %n = numel(labels);
            fr = obj.getFr(window);
            fr = fr(:, idcEvents);
            if isempty(options.KFold)
                mdl = fitcecoc(fr, labels, Coding=options.Coding, ObservationsIn="columns", ...
                    ClassNames=options.ClassNames);
            else
                mdl = fitcecoc(fr, labels, Coding=options.Coding, ObservationsIn="columns", ...
                    ClassNames=options.ClassNames, KFold=options.KFold);
            end
        end

        function h = plotRaster(obj, sz, c, cats, plotOps, saveOps)
            % PLOTRASTER Plot raster of triggered spikes
            %
            %   h = plotRaster(obj, ...)
            %
            %   obj: triggered spikes object
            %   sz: size of the markers
            %   c: color of the markers
            %   plotOps: additional arguments passed to scatter
            %
            %   h: handle to the plot
            arguments
                obj spiky.trig.TrigSpikes
                sz double {mustBePositive} = 5
                c = "k"
                cats categorical = categorical.empty
                plotOps.?matlab.graphics.chart.primitive.Scatter
                saveOps.savePath string = ""
            end
            if length(obj)>1 && saveOps.savePath==""
                error("savePath is required for multiple objects");
            end
            if exist(saveOps.savePath, "file")
                delete(saveOps.savePath);
            end
            fg = findall(0, "Type", "Figure");
            if isempty(fg)
                spiky.plot.fig
            end
            plotOps = namedargs2cell(plotOps);
            if length(obj)>1
                h1 = obj(1).plotRaster(sz, c, cats, plotOps{:});
                for ii = 1:length(obj)
                    [t, r] = obj(ii).getRaster(cats);
                    h1.XData = t;
                    h1.YData = r;
                    title(sprintf("Neuron %d, %s ch %d", obj(ii).Neuron.Id, ...
                        obj(ii).Neuron.Region, obj(ii).Neuron.ChInGroup));
                    exportgraphics(gcf, saveOps.savePath, ContentType="image", Resolution=300, ...
                        Append=true);
                end
                return
            end
            n = obj.Length;
            if n==0
                h = [];
                return
            end
            if ~isempty(cats)
                cats = cats(:);
                counts = groupcounts(cats);
                edges = [0; cumsum(counts)]+0.5;
                centers = (edges(1:end-1)+edges(2:end))./2;
            end
            [t, r] = obj.getRaster(cats);
            h1 = scatter(t, r, sz, c, "filled", plotOps{:});
            xlim(obj.Window);
            ylim([0.5 n+0.5]);
            set(gca, "YDir", "reverse");
            xline(0, "g", LineWidth=2);
            xlabel("Time (s)");
            if ~isempty(cats)
                yticks(centers);
                yticklabels(categories(cats));
                ax = gca;
                ax.YAxis.FontSize = 8;
                yline(edges, "k", LineWidth=0.5);
            end
            if nargout>0
                h = h1;
            end
        end
    end

    methods (Access = protected)
        function [t, r] = getRaster(obj, cats)
            arguments
                obj spiky.trig.TrigSpikes
                cats categorical = categorical.empty
            end
            n = obj.Length;
            if n==0
                t = [];
                r = [];
                return
            end
            t = cell2mat(obj.Data);
            r = zeros(length(t), 1);
            nSpikes = cellfun(@length, obj.Data);
            count = 0;
            if isempty(cats)
                idc = 1:n;
            else
                cats = cats(:);
                [~, idc] = sort(cats);
                [~, idc] = sort(idc);
            end
            for ii = 1:n
                if nSpikes(ii)==0
                    continue
                end
                r(count+(1:nSpikes(ii))) = idc(ii);
                count = count+nSpikes(ii);
            end
        end
    end
end