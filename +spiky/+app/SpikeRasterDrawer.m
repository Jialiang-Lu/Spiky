classdef SpikeRasterDrawer < spiky.app.Drawer
    %SPIKERASTERDRAWER Class for drawing spike rasters in the SessionViewer app

    properties
        Trig spiky.trig.TrigSpikes
        Cats (:, 1) categorical
        T (:, 1) double
        R (:, 1) double
        Edges (:, 1) double
    end

    methods (Static, Sealed)
        function target = getTarget()
            target = "Resp";
        end
    end

    methods (Sealed)
        function obj = SpikeRasterDrawer(app, hCheckbox)
            % SpikeRasterDrawer Constructor for the SpikeRasterDrawer class
            %
            %   obj = SpikeRasterDrawer(app, hCheckbox, toggleType)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
            end
            obj@spiky.app.Drawer(app, hCheckbox, "create");
        end

        function name = getName(obj)
            % getName Get the name of the drawer
            %
            %   name = obj.getName()
            %
            %   name: name of the drawer
            name = "Spike Raster";
        end
        
        function h = onCreate(obj)
            % onCreate Create the plot for the SpikeRasterDrawer
            %
            %   h = obj.onCreate()
            %
            %   h: handle to the plot object
            obj.Trig = obj.App.Spikes.trig(0, [0 obj.App.Info.Duration]);
            cats = vertcat(obj.App.Spikes.Neuron);
            cats = cats.Region;
            obj.Cats = categorical(cats);
            [obj.T, obj.R, obj.Edges] = obj.Trig.getRaster(obj.Cats, "neuron");
            [obj.T, idc] = sort(obj.T);
            obj.R = obj.R(idc);
            [t, r] = obj.getRaster(0);
            h1 = scatter(obj.HAxes, t, r, 1, "w", "filled");
            xlim(obj.HAxes, [-1 2]);
            ylim(obj.HAxes, obj.Edges([1 end]));
            % xlabel(obj.HAxes, "Time (s)");
            set(obj.HAxes, YDir="reverse");
            h2 = yline(obj.HAxes, obj.Edges, "y", LineWidth=0.5);
            centers = (obj.Edges(1:end-1)+obj.Edges(2:end))/2;
            regions = unique(obj.Cats, "stable");
            h3 = text(obj.HAxes, -1*ones(length(regions), 1), centers, string(regions), ...
                HorizontalAlignment="left", VerticalAlignment="middle", ...
                FontSize=12, Color="w", BackgroundColor=obj.App.UIFigure.Color);
            h = [h1; h2; h3];
        end

        function filter(obj)
            % filter Apply the current filter to the plot
            %
            %   obj.filter()
            %
            %   This method is called when the filter is updated.
            if isempty(obj.Filter)
                return
            end
            cond = true(width(obj.Trig), 1);
            for ii = 1:length(obj.Filter)
                if ~isempty(obj.Filter(ii).Indices) && obj.Filter(ii).Name=="Neuron"
                    cond = cond & obj.Filter(ii).Indices;
                end
            end
            trig = obj.Trig(1, cond);
            cats = obj.Cats(cond);
            [obj.T, obj.R, obj.Edges] = trig.getRaster(cats, "neuron");
            [obj.T, idc] = sort(obj.T);
            obj.R = obj.R(idc);
            ylim(obj.HAxes, obj.Edges([1 end]));
            obj.HPlot(2:end).delete;
            h2 = yline(obj.HAxes, obj.Edges, "y", LineWidth=0.5);
            centers = (obj.Edges(1:end-1)+obj.Edges(2:end))/2;
            regions = unique(cats, "stable");
            h3 = text(obj.HAxes, -1*ones(length(regions), 1), centers, string(regions), ...
                HorizontalAlignment="left", VerticalAlignment="middle", ...
                FontSize=12, Color="w", BackgroundColor=obj.App.UIFigure.Color);
            obj.HPlot = [obj.HPlot(1); h2; h3];
            obj.onTimeUpdate(obj.App.CurrentTime);
        end

        function onTimeUpdate(obj, time)
            % onTimeUpdate Update the plot with the current time
            %
            %   obj.onTimeUpdate(time)
            %
            %   time: current time in seconds
            [t, r] = obj.getRaster(time);
            t = t - time;
            set(obj.HPlot(1), XData=t, YData=r);
            % xlim(obj.HAxes, time+[-1 2]);
            % obj.HPlot(2).Value = time;
        end

        function [t, r] = getRaster(obj, time)
            % GETRASTER Get the raster data for the specified time
            %
            %   [t, r] = obj.getRaster(time)
            %   time: time point in seconds
            %   
            %   t: spike times
            %   r: spike regions
            idx1 = spiky.mex.binarySearch(obj.T, time-1);
            idx2 = spiky.mex.binarySearch(obj.T, time+2);
            if idx1 < 1
                idx1 = 1;
            end
            if idx2 > length(obj.T)
                idx2 = length(obj.T);
            end
            if idx1 <= idx2
                t = obj.T(idx1:idx2);
                r = obj.R(idx1:idx2);
            else
                t = [];
                r = [];
            end
        end
    end
end