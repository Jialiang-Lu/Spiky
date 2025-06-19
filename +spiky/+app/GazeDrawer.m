classdef GazeDrawer < spiky.app.Drawer
    %GazeDrawer Class for drawing gaze data in the SessionViewer app

    methods (Static, Sealed)
        function target = getTarget()
            target = "Stim";
        end
    end

    methods (Sealed)
        function obj = GazeDrawer(app, hCheckbox)
            % GazeDrawer Constructor for the FixationTargetDrawer class
            %
            %   obj = FixationTargetDrawer(app, hCheckbox, toggleType)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
            end
            obj@spiky.app.Drawer(app, hCheckbox, "show");
        end

        function name = getName(obj)
            % getName Get the name of the drawer
            %
            %   name = obj.getName()
            %
            %   name: name of the drawer
            name = "Gaze";
        end

        function h = onCreate(obj)
            % onCreate Create the plot for the GazeDrawer
            %
            %   h = obj.onCreate()
            %
            %   h: handle to the plot object
            h = scatter(obj.HAxes, [], [], 20, "m", "filled");
        end

        function onTimeUpdate(obj, time)
            % onTimeUpdate Update the plot with the current time
            %
            %   obj.onTimeUpdate(time)
            %
            %   time: current time in seconds

            idx = spiky.mex.binarySearch(obj.App.Minos.Eye.Data.Time, time);
            if idx<=0 || idx>obj.App.Minos.Eye.Data.Length
                return
            end
            proj = obj.App.Minos.Eye.Data.Proj(idx, :);
            obj.HPlot.XData = proj(1, 1);
            obj.HPlot.YData = proj(1, 2);
        end
    end
end