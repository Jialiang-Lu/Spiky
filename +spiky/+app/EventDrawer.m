classdef (Abstract) EventDrawer < spiky.app.Drawer
    %EVENTDRAWER Abstract class for drawing events in the SessionViewer app
    % 
    %   This class serves as a base for specific event drawers, providing
    %   common functionality and properties.

    properties
        PlotArgs cell
    end

    methods
        function obj = EventDrawer(app, hCheckbox)
            %EVENTDRAWER Constructor for the EventDrawer class
            %
            %   obj = Drawer(app, hCheckbox)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
            end
            obj@spiky.app.Drawer(app, hCheckbox, "show");
        end

        function h = onCreate(obj)
            h = gobjects(0);
        end

        function onTimeUpdate(obj, time)
            % onTimeUpdate Update the plot with the current time
            %   obj.onTimeUpdate(time)
            %   time: current time in seconds

            [events, names] = obj.getEvents(time);
            if width(events)==1
                isRange = false;
            elseif width(events)==2
                isRange = true;
            else
                error("Events must be either Nx1 or Nx2 array.");
            end
            nNew = height(events);
            nOld = height(obj.HPlot);
            for ii = 1:nNew
                if ii > nOld
                    if isRange
                        obj.HPlot(ii, 1) = xline(obj.HAxes, events(ii, 1), ...
                            Alpha=0, FontSize=8, Interpreter="none", LabelOrientation="horizontal");
                        obj.HPlot(ii, 2) = xregion(obj.HAxes, events(ii, :), obj.PlotArgs{:});
                    else
                        obj.HPlot(ii, 1) = xline(obj.HAxes, events(ii, :), obj.PlotArgs{:}, ...
                            FontSize=8, Interpreter="none", LabelOrientation="horizontal");
                    end
                else
                    obj.HPlot(ii, 1).Value = events(ii, 1);
                    if isRange
                        obj.HPlot(ii, 2).Value = events(ii, :);
                    end
                end
                if ~isempty(names)
                    obj.HPlot(ii, 1).Label = names(ii);
                end
            end
            obj.HPlot(nNew+1:end, :).delete();
            obj.HPlot = obj.HPlot(1:nNew, :);
        end
    end

    methods (Static)
        function target = getTarget()
            target = "Events";
        end
    end

    methods (Abstract)
        [evts, names] = getEvents(obj, time)
        %GETEVENTS Get events at a specific time
        %   events = obj.getEvents(time)
        %   time: time in seconds
        %   evts: array of events at the specified time, either Nx1 or Nx2
        %   names: string array of event names, same size as events
    end
end