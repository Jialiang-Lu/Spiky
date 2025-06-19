classdef TrialEventDrawer < spiky.app.EventDrawer
    %TRIALEVENTDRAWER Class for drawing trial events in the SessionViewer app

    properties
        TrialStates spiky.core.TimeTable = spiky.core.TimeTable.empty
    end

    methods (Static)
        function target = getTarget()
            target = "Event";
        end
    end

    methods
        function obj = TrialEventDrawer(app, hCheckbox)
            % TRIALEVENTDRAWER Constructor for the TrialEventDrawer class
            %
            %   obj = TrialEventDrawer(app, hCheckbox)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
            end
            obj@spiky.app.EventDrawer(app, hCheckbox);
            trials = {app.Minos.Paradigms.Trials}';
            for ii = 1:length(trials)
                idc = find(endsWith(trials{ii}.Data.Properties.VariableNames, "_Type"));
                tbl = trials{ii}{:, idc-1};
                t = tbl{:, :}';
                v = repmat(categorical(string(tbl.Properties.VariableNames)), height(tbl), 1)';
                t = t(:);
                v = v(:);
                [t, idc] = uniquetol(t, 0.02, "highest", DataScale=1);
                v = v(idc);
                idc = ~isnan(t);
                t = t(idc);
                v = v(idc);
                t = spiky.core.TimeTable(t(:), v(:));
                trials{ii} = t;
            end
            ts = vertcat(trials{:});
            ts = ts.sort();
            obj.TrialStates = ts;
            obj.PlotArgs = {"LineWidth", 1.5};
        end

        function name = getName(obj)
            % GETNAME Get the name of the drawer
            %
            %   name = obj.getName()
            %
            %   name: name of the drawer
            name = "Trial State";
        end

        function [events, names] = getEvents(obj, time)
            % GETEVENTS Get trial states at a specific time
            %
            %   events = obj.getEvents(time)
            %
            %   time: time in seconds
            %   events: array of trial states at the specified time, either Nx1 or Nx2
            %   names: string array of trial state names, same size as events

            events = obj.TrialStates.inPeriods([time-1, time+2], false, -1, KeepType=true);
            names = events.Data;
            events = events.Time;
        end
    end
end