classdef FixationDrawer < spiky.app.EventDrawer
    %FIXATIONDRAWER Class for drawing fixation events in the SessionViewer app

    methods (Static)
        function target = getTarget()
            target = "Event";
        end
    end

    methods
        function obj = FixationDrawer(app, hCheckbox)
            % FIXATIONDRAWER Constructor for the FixationDrawer class
            %
            %   obj = FixationDrawer(app, hCheckbox)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
            end
            obj@spiky.app.EventDrawer(app, hCheckbox);
            obj.PlotArgs = {"FaceColor", [0.2 0.8 0.2]};
        end

        function onTimeUpdate(obj, time)
            onTimeUpdate@spiky.app.EventDrawer(obj, time);
            set(obj.HPlot(:, 1), "Color", [0.2 0.8 0.2]);
        end

        function name = getName(obj)
            % GETNAME Get the name of the drawer
            %
            %   name = obj.getName()
            %
            %   name: name of the drawer
            name = "Fixation";
        end

        function [events, names] = getEvents(obj, time)
            % GETEVENTS Get fixation events at a specific time
            %
            %   [events, names] = obj.getEvents(time)
            %
            %   time: current time in seconds
            %   events: Nx2 array of fixation start and end times
            %   names: categorical array of fixation labels

            idx1 = spiky.mex.binarySearch(obj.App.Minos.Eye.Fixations.Time(:, 2), time-1)+1;
            idx2 = spiky.mex.binarySearch(obj.App.Minos.Eye.Fixations.Time(:, 1), time+2);
            if idx1>obj.App.Minos.Eye.Fixations.Length || idx2<1 || idx1>idx2
                events = double.empty(0, 2);
                names = [];
            else
                events = obj.App.Minos.Eye.Fixations.Time(idx1:idx2, :)-time;
                ids = string(obj.App.Minos.Eye.FixationTargets.Name(idx1:idx2));
                parts = string(obj.App.Minos.Eye.FixationTargets.Part(idx1:idx2));
                names = ids+newline+parts;
                idc = ismissing(ids) | obj.App.Minos.Eye.FixationTargets.MinAngle(idx1:idx2)>8;
                names(idc) = missing;
            end
        end
    end
end