classdef RegionFilter < spiky.app.Filter
    %REGIONFILTER Class for filtering regions in the SessionViewer app

    properties
        Regions (:, 1) categorical
        RegionNames (:, 1) string
    end

    methods
        function obj = RegionFilter(app, hDrawer, hControl)
            % RegionFilter Constructor for the RegionFilter class
            %
            %   obj = RegionFilter(app, hControl, hDrawer)
            %
            %   app: SessionViewer app instance
            %   hDrawer: handle to the drawer associated with the filter
            %   hControl: handle to the control for the filter
            arguments
                app spiky.app.SessionViewer
                hDrawer spiky.app.Drawer = spiky.app.Drawer.empty
                hControl = []
            end
            obj@spiky.app.Filter(app, "Neuron", hDrawer, hControl);
            neurons = [app.Spikes.Neuron]';
            regions = [neurons.Region]';
            regionNames = unique(regions, "stable");
            obj.Regions = categorical(regions, regionNames);
            obj.RegionNames = regionNames;
            hControl.Items = ["All"; regionNames];
            hControl.Value = "All";  % Default to "All" selection
            obj.Indices = true(size(obj.Regions));
        end

        function indices = onUpdate(obj, event)
            % ONUPDATE Update the filter indices based on the selected region
            %
            %   indices = obj.onUpdate(event)
            %
            %   event: event data containing the selected region
            %   indices: logical array indicating which neurons match the filter
            if event.Value=="All"
                indices = true(size(obj.Regions));
            else
                indices = obj.Regions==event.Value;
            end
        end
    end
end