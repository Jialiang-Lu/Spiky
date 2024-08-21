classdef TrigSpikes
    % TRIGSPIKES Spikes triggered by events

    properties
        Neuron spiky.core.Neuron
        Data spiky.core.TimeTable
        Window (:, 2) double
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

        function h = plotRaster(obj, sz, c, options, saveOps)
            % PLOTRASTER Plot raster of triggered spikes
            %
            %   h = plotRaster(obj, ...)
            %
            %   obj: triggered spikes object
            %   sz: size of the markers
            %   c: color of the markers
            %   options: additional arguments passed to scatter
            %
            %   h: handle to the plot
            arguments
                obj spiky.trig.TrigSpikes
                sz double {mustBePositive} = 5
                c = "k"
                options.?matlab.graphics.chart.primitive.Scatter
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
            options = namedargs2cell(options);
            if length(obj)>1
                h = obj(1).plotRaster(sz, c, options{:});
                for ii = 1:length(obj)
                    [t, r] = obj(ii).getRaster;
                    h.XData = t;
                    h.YData = r;
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
            h = scatter(t, r, sz, c, "filled", options{:});
            xlim(obj.Window);
            ylim([0.5 n+0.5]);
            set(gca, "YDir", "reverse");
            xline(0, "g", LineWidth=2);
            xlabel("Time (s)");
            title(sprintf("Neuron %d, %s ch %d", obj.Neuron.Id, obj.Neuron.Region, ...
                obj.Neuron.ChInGroup));
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