classdef (Abstract) Drawer < handle & matlab.mixin.Heterogeneous
    %DRAWER Abstract class for creating a drawer in the SessionViewer app

    properties
        App spiky.app.SessionViewer
        Timer timer
        CurrentTime double = 0
        HPlot matlab.graphics.Graphics
        HAxes matlab.graphics.axis.Axes
        Target string {mustBeMember(Target, ["Stim", "Resp"])}
    end

    properties (Hidden)
        StartTimestamp_ datetime = datetime("now")
        StartTime_ double = 0
        Visible_ logical = true
    end

    properties (Dependent)
        Visible logical
    end

    methods
        function obj = Drawer(app, period)
            % Drawer Constructor for the Drawer class
            %
            %   obj = Drawer(app, period)
            %
            %   app: SessionViewer app instance
            %   target: target type ("Stim" or "Resp")
            %   period: time period for the timer (default: 0.1 seconds)
            arguments
                app spiky.app.SessionViewer
                period (1, 1) double = 0.1
            end
            
            obj.App = app;
            obj.Timer = timer(Period=period, ExecutionMode="fixedRate", ...
                BusyMode="drop", TimerFcn=@(~, evt) obj.updateTime(evt.Data.time));
            obj.Target = obj.getTarget();
            switch obj.Target
                case "Stim"
                    obj.HAxes = app.StimUIAxes;
                case "Resp"
                    obj.HAxes = app.RespUIAxes;
            end
            obj.HPlot = obj.onCreate();
        end

        function v = get.Visible(obj)
            %GET.VISIBLE Get the visibility of the drawer
            %   v = obj.Visible returns the visibility of the drawer
            v = obj.Visible_;
        end

        function set.Visible(obj, v)
            %SET.VISIBLE Set the visibility of the drawer
            %   obj.Visible = v sets the visibility of the drawer
            arguments
                obj spiky.app.Drawer
                v logical
            end
            obj.Visible_ = v;
            if v
                set(obj.HPlot, "Visible", "on");
            else
                set(obj.HPlot, "Visible", "off");
            end
        end

        function start(obj, time)
            %START Start the timer and update the time
            arguments
                obj spiky.app.Drawer
                time double
            end
            obj.CurrentTime = time;
            obj.StartTimestamp_ = datetime("now");
            obj.StartTime_ = time;
            obj.Timer.start();
        end
        
        function pause(obj, time)
            %PAUSE Pause the timer and update the time
            arguments
                obj spiky.app.Drawer
                time double
            end
            obj.CurrentTime = time;
            obj.Timer.stop();
            obj.onTimeUpdate(time);
        end

        function jump(obj, time)
            %JUMP Jump to a specific time and update the plot
            arguments
                obj spiky.app.Drawer
                time double
            end
            running = obj.Timer.Running;
            obj.pause(time);
            if running=="on"
                obj.start(time);
            end
        end
        
        function delete(obj)
            obj.Timer.stop();
            obj.Timer.delete();
            obj.HPlot.delete();
        end
    end

    methods (Access=protected)
        function updateTime(obj, timestamp)
            arguments
                obj spiky.app.Drawer
                timestamp datetime
            end
            dur = timestamp - obj.StartTimestamp_;
            obj.CurrentTime = obj.StartTime_ + seconds(dur);
            if obj.getName()=="Spike Raster"
                fprintf("Start time: %.2f\tCurrent time: %.2f\tDuration: %.2f\n", ...
                    obj.StartTime_, obj.CurrentTime, seconds(dur));
            end
            obj.onTimeUpdate(obj.CurrentTime);
        end
    end
    
    methods (Abstract, Static)
        target = getTarget()
        % getTarget Get the target type of the drawer
        %   target: target type ("Stim" or "Resp")
    end
    
    methods (Abstract)
        name = getName(obj)
        % getName Get the name of the drawer
        %   name: name of the drawer
        h = onCreate(obj)
        % onCreate Create the plot for the drawer
        %   h = obj.onCreate()
        %   h: handle to the plot object
        onTimeUpdate(obj, time)
        % onTimeUpdate Update the drawer with the new time
        %   obj.onTimeUpdate(time)
        %   time: new time point
    end
end