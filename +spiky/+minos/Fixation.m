classdef Fixation < spiky.core.EventsTable

    properties (Dependent)
        Duration (:, 1) double
        Gaze (:, 3) double
        Viewport (:, 2) double
        Trial (:, 1) double
        Object (:, 1) categorical
        Part (:, 1) categorical
        Dist (:, 1) double
    end

    methods
        function obj = Fixation(time, data)
            arguments
                time = []
                data spiky.core.EventsTable = spiky.core.EventsTable
            end
            if ~isempty(data) && ~isequal(data.Data.Properties.VariableNames, ...
                    ["Duration" "Gaze" "Viewport" "Trial" "Object" "Part" "Dist"])
                error("Invalid data properties.")
            end
            if isempty(data)
                data = spiky.core.EventsTable([], table(Size=[0 7], ...
                    VariableTypes=["double" "double" "double" "double" "categorical" "categorical" "double"], ...
                    VariableNames=["Duration" "Gaze" "Viewport" "Trial" "Object" "Part" "Dist"]));
            end
            obj@spiky.core.EventsTable(time, data);
        end

        function duration = get.Duration(obj)
            duration = obj.Data.Duration;
        end

        function gaze = get.Gaze(obj)
            gaze = obj.Data.Gaze;
        end

        function viewport = get.Viewport(obj)
            viewport = obj.Data.Viewport;
        end

        function trial = get.Trial(obj)
            trial = obj.Data.Trial;
        end

        function object = get.Object(obj)
            object = obj.Data.Object;
        end

        function part = get.Part(obj)
            part = obj.Data.Part;
        end

        function dist = get.Dist(obj)
            dist = obj.Data.Dist;
        end
    end
end