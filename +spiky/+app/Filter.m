classdef (Abstract) Filter < handle & matlab.mixin.Heterogeneous
    %FILTER Abstract class for creating a filter in the SessionViewer app

    properties
        App spiky.app.SessionViewer
        Name string
        HControl
        HDrawer spiky.app.Drawer
        Indices (:, 1) logical = []
    end

    methods
        function obj = Filter(app, name, hDrawer, hControl, fcnName)
            % FILTER Constructor for the Filter class
            %
            %   obj = Filter(app, name, hControl, hDrawer)
            %
            %   app: SessionViewer app instance
            %   name: name of the filter
            %   hDrawer: handle to the drawer associated with the filter
            %   hControl: handle to the control for the filter
            %   fcnName: name of the callback function of hControl
            arguments
                app spiky.app.SessionViewer
                name (1, 1) string
                hDrawer spiky.app.Drawer = spiky.app.Drawer.empty
                hControl = []
                fcnName (1, 1) string = "ValueChangedFcn"
            end
            obj.App = app;
            obj.Name = name;
            obj.HDrawer = hDrawer;
            if ~isempty(hDrawer)
                hDrawer.Filter = [hDrawer.Filter; obj];
            end
            obj.HControl = hControl;
            if ~isempty(hControl)
                if isprop(hControl, fcnName)
                    hControl.(fcnName) = @(src, event) obj.onControlUpdate(src, event);
                else
                    error("Control does not have a property named %s", fcnName);
                end
            end
        end

        function onControlUpdate(obj, source, event)
            % ONCONTROLUPDATE Handle updates from the control
            %
            %   obj.onControlUpdate(source, event)
            %
            %   source: source of the event, typically the control
            %   event: event data, typically containing the new value
            obj.Indices = obj.onUpdate(event);
            if ~isempty(obj.HDrawer)
                obj.HDrawer.filter();
            end
        end
    end

    methods (Abstract)
        idc = onUpdate(obj, event);
        % ONUPDATE Update the filter based on the value
        %   idc = obj.onUpdate(event)
        %   event: event from the control
        %   idc: indices of the filtered data
    end
end