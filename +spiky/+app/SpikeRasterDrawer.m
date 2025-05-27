classdef SpikeRasterDrawer < spiky.app.Drawer
    %SPIKERASTERDRAWER Class for drawing spike rasters in the SessionViewer app

    properties
        Trig spiky.trig.TrigSpikes
    end

    methods (Static, Sealed)
        function target = getTarget()
            target = "Resp";
        end
    end

    methods (Sealed)
        function obj = SpikeRasterDrawer(app, period)
            %SPIKERASTERDRAWER Constructor for the SpikeRasterDrawer class
            %
            %   obj = SPIKERASTERDRAWER(app, period)
            %
            %   app: SessionViewer app instance
            %   period: time period for the timer (default: 0.1 seconds)
            arguments
                app spiky.app.SessionViewer
                period (1, 1) double = 0.1
            end
            obj@spiky.app.Drawer(app, period); % Call the superclass constructor
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
            h1 = obj.Trig.plotRaster(1, "w", [], "neuron", Parent=obj.HAxes);
            xlim(obj.HAxes, [-1 2]);
            h2 = xline(obj.HAxes, 0, "g", LineWidth=1);
            h = [h1; h2];
        end

        function onTimeUpdate(obj, time)
            % onTimeUpdate Update the plot with the current time
            %
            %   obj.onTimeUpdate(time)
            %
            %   time: current time in seconds
            xlim(obj.HAxes, [time-1 time+2]);
            obj.HPlot(2).Value = time;
            fprintf("Time: %.2f\n", time);
        end
    end
end