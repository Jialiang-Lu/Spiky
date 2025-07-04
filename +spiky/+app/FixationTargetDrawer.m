classdef FixationTargetDrawer < spiky.app.Drawer
    %FIXATIONTARGETDRAWER Class for drawing fixation targets in the SessionViewer app

    properties
        LastIdx double = 0
    end
    
    methods (Static, Sealed)
        function target = getTarget()
            target = "Stim";
        end
    end

    methods (Sealed)
        function obj = FixationTargetDrawer(app, hCheckbox, toggleType)
            % FixationTargetDrawer Constructor for the FixationTargetDrawer class
            %
            %   obj = FixationTargetDrawer(app, hCheckbox, toggleType)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            %   toggleType: type of toggle, either "create" or "show"
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
                toggleType (1, 1) string {mustBeMember(toggleType, ["create", "show"])} = "show"
            end
            obj@spiky.app.Drawer(app, hCheckbox, toggleType);
        end

        function name = getName(obj)
            % getName Get the name of the drawer
            %
            %   name = obj.getName()
            %
            %   name: name of the drawer
            name = "Fixation Target";
        end

        function h = onCreate(obj)
            % onCreate Create the plot for the FixationTargetDrawer
            %
            %   h = obj.onCreate()
            %
            %   h: handle to the plot object
            h = [scatter(obj.HAxes, [], [], 30, "r")
                scatter(obj.HAxes, [], [], 60, "b")
                plot(obj.HAxes, NaN, NaN, "r-", LineWidth=1)
                text(obj.HAxes, 0, 0, "")];
        end

        function onTimeUpdate(obj, time)
            % onTimeUpdate Update the plot with the current time
            %
            %   obj.onTimeUpdate(time)
            %
            %   time: current time in seconds

            [~, ~, idx] = obj.App.Minos.Eye.Fixations.haveEvents(time);
            if isempty(idx)
                obj.clear();
                return
            end
            if idx==obj.LastIdx
                return
            end
            target = obj.App.Minos.Eye.FixationTargets{idx, :};
            if ismissing(target.Name) || target.MinAngle>8
                obj.clear();
                return
            end
            obj.LastIdx = idx;
            proj = target.Proj;
            targetProj = target.TargetProj;
            obj.HPlot(1).XData = proj(1);
            obj.HPlot(1).YData = proj(2);
            obj.HPlot(2).XData = targetProj(1);
            obj.HPlot(2).YData = targetProj(2);
            obj.HPlot(3).XData = [proj(1), targetProj(1)];
            obj.HPlot(3).YData = [proj(2), targetProj(2)];
            obj.HPlot(4).Position = [targetProj(1), targetProj(2), 0];
            obj.HPlot(4).String = "\leftarrow "+string(target.Name)+" "+string(target.Part);
        end

        function clear(obj)
            %CLEAR Clear the plot
            %
            %   obj.clear()
            %
            %   obj: FixationTargetDrawer object

            obj.HPlot(1).XData = [];
            obj.HPlot(1).YData = [];
            obj.HPlot(2).XData = [];
            obj.HPlot(2).YData = [];
            obj.HPlot(3).XData = NaN;
            obj.HPlot(3).YData = NaN;
            obj.HPlot(4).Position = [0, 0, 0];
            obj.HPlot(4).String = "";
            obj.LastIdx = 0;
        end
    end            
end