classdef TrigSpikes
    % TRIGSPIKES Spikes triggered by events

    properties
        Neuron spiky.core.Neuron
        Data spiky.core.TimeTable
        Window (:, 2) double
    end

    properties (Dependent)
        Fr
    end
    
    methods
        function obj = TrigSpikes(neuron, events, spikes, window)
            arguments
                neuron spiky.core.Neuron = spiky.core.Neuron.empty
                events double = []
                spikes cell = []
                window (:, 2) double = []
            end
            obj.Neuron = neuron;
            obj.Data = spiky.core.TimeTable(events, table(spikes, VariableNames="Spikes"));
            obj.Window = window;
        end

        function fr = getFr(obj, window)
            % GETFR Get firing rate in a window
            %
            %   fr = getFr(obj, window)
            %
            %   obj: triggered spikes object
            %   window: window for the analysis
            %
            %   fr: [nNeurons, nEvents] firing rate
            arguments
                obj spiky.trig.TrigSpikes
                window double = []
            end
            if isempty(obj(1).Data)
                fr = [];
                return
            end
            if isempty(window)
                window = obj(1).Window;
            end
            w = diff(window);
            fr = zeros(numel(obj), height(obj(1).Data));
            for ii = 1:numel(obj)
                fr(ii, :) = cellfun(@(x) sum(x>=window(1) & x<=window(2))/w, obj(ii).Data.Spikes);
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

        function h = plotRaster(obj, sz, c, plotOps, saveOps)
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
                h1 = obj(1).plotRaster(sz, c, plotOps{:});
                for ii = 1:length(obj)
                    [t, r] = obj(ii).getRaster;
                    h1.XData = t;
                    h1.YData = r;
                    title(sprintf("Neuron %d, %s ch %d", obj(ii).Neuron.Id, ...
                        obj(ii).Neuron.Region, obj(ii).Neuron.ChInGroup));
                    exportgraphics(gcf, saveOps.savePath, ContentType="image", Resolution=300, ...
                        Append=true);
                end
                return
            end
            n = obj.Data.Length;
            if n==0
                h = [];
                return
            end
            [t, r] = obj.getRaster;
            h1 = scatter(t, r, sz, c, "filled", plotOps{:});
            xlim(obj.Window);
            ylim([0.5 n+0.5]);
            set(gca, "YDir", "reverse");
            xline(0, "g", LineWidth=2);
            xlabel("Time (s)");
            if nargout>0
                h = h1;
            end
        end
    end

    methods (Access = protected)
        function [t, r] = getRaster(obj)
            n = obj.Data.Length;
            if n==0
                t = [];
                r = [];
                return
            end
            t = cell2mat(obj.Data.Spikes);
            r = zeros(length(t), 1);
            nSpikes = cellfun(@length, obj.Data.Spikes);
            count = 0;
            for ii = 1:n
                if nSpikes(ii)==0
                    continue
                end
                r(count+(1:nSpikes(ii))) = ii;
                count = count+nSpikes(ii);
            end
        end
    end
end