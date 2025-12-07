classdef (Abstract) Drawer < handle & matlab.mixin.Heterogeneous
    %DRAWER Abstract class for creating a drawer in the SessionViewer app

    properties
        App spiky.app.SessionViewer
        HPlot matlab.graphics.Graphics
        HAxes matlab.graphics.axis.Axes
        Target string {mustBeMember(Target, ["Stim", "Event", "Resp"])}
        CurrentTime double = 0
        Filter spiky.app.Filter = spiky.app.Filter.empty
        Active logical = false
    end

    properties (Hidden)
        Visible_ logical = true
    end

    properties (Dependent)
        Visible logical
    end

    methods
        function obj = Drawer(app, hCheckbox, toggleType)
            % Drawer Constructor for the Drawer class
            %
            %   obj = Drawer(app, period)
            %
            %   app: SessionViewer app instance
            %   hCheckbox: handle to the checkbox for visibility control
            arguments
                app spiky.app.SessionViewer
                hCheckbox = []
                toggleType (1, 1) string {mustBeMember(toggleType, ["create", "show"])} = "show"
            end
            
            obj.App = app;
            obj.Target = obj.getTarget();
            switch obj.Target
                case "Stim"
                    obj.HAxes = app.StimUIAxes;
                case "Event"
                    obj.HAxes = app.EventUIAxes;
                case "Resp"
                    obj.HAxes = app.RespUIAxes;
            end
            if toggleType=="show"
                obj.create();
                if ~isempty(hCheckbox)
                    hCheckbox.ValueChangedFcn = @(src, event) obj.toggleVisibility(event.Value);
                end
            elseif toggleType=="create"
                obj.toggleCreation(hCheckbox.Value);
                if ~isempty(hCheckbox)
                    hCheckbox.ValueChangedFcn = @(src, event) obj.toggleCreation(event.Value);
                end
            end
            obj.Active = hCheckbox.Value;
        end

        function toggleCreation(obj, value)
            %TOGGLECREATION Toggle the creation of the drawer
            %   obj.toggleCreation(value) creates or clears the drawer based on value
            %   value: true to create, false to clear
            if value
                obj.create();
            else
                obj.clear();
            end
            obj.Active = value;
        end

        function toggleVisibility(obj, value)
            %TOGGLEVISIBILITY Toggle the visibility of the drawer
            %   obj.toggleVisibility(value) sets the visibility of the drawer
            %   value: true to show, false to hide
            obj.Visible = value;
            obj.Active = value;
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

        function create(obj)
            %CREATE Create the drawer and its plot
            obj.HPlot = obj.onCreate();
            set(obj.HPlot, "Visible", obj.Visible_);
            obj.update(obj.App.CurrentTime);
            if ~isempty(obj.Filter)
                obj.filter();
            end
        end

        function update(obj, time)
            %UPDATE Update the drawer with the new time
            %   obj.update(time) updates the drawer with the new time
            %   time: new time point
            if ~obj.Active
                return
            end
            obj.CurrentTime = time;
            obj.onTimeUpdate(time);
        end

        function clear(obj)
            %CLEAR Clear the drawer and its plot
            if isempty(obj.HPlot)
                return
            end
            obj.HPlot.delete();
            obj.HPlot = [];
        end
        
        function delete(obj)
            % obj.Timer.stop();
            % obj.Timer.delete();
            obj.HPlot.delete();
        end

        function filter(obj)
        end
    end

    methods (Abstract, Static)
        target = getTarget()
        %GETTARGET Get the target type of the drawer
        %   target: target type ("Stim" or "Event" or "Resp")
    end
    
    methods (Abstract)
        name = getName(obj)
        %GETNAME Get the name of the drawer
        %   name: name of the drawer
        h = onCreate(obj)
        %ONCREATE Create the plot for the drawer
        %   h = obj.onCreate()
        %   h: handle to the plot object
        onTimeUpdate(obj, time)
        %ONTIMEUPDATE Update the drawer with the new time
        %   obj.onTimeUpdate(time)
        %   time: new time point
    end
end