classdef Trig < spiky.core.EventsTable
    %TRIG Base class representing a general event-triggered data structure

    properties (Hidden)
        Events_ (:, 1)
    end
    
    properties
        EventDim (1, 1) double = 1
        Window (:, :) double
        Groups (:, 1)
    end

    properties (Dependent)
        Events (:, 1)
        NEvents (1, 1) double
        NGroups double
    end

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {"Time"; "Events"; "Groups"};
        end
    end

    methods
        function obj = Trig(time, data, events, groups, options)
            arguments
                time double = []
                data = []
                events (:, 1) = NaN(width(data), 1)
                groups (:, 1) = NaN(size(data, 3), 1)
                options.EventDim (1, 1) double = 2
            end
            if isempty(time) && isempty(data)
                return
            end
            obj.Time = time;
            obj.Data = data;
            obj.EventDim = options.EventDim;
            obj.Events_ = events;
            obj.Groups = groups;
        end

        function t = get.Events(obj)
            if obj.EventDim == 1
                t = obj.Time;
            else
                t = obj.Events_;
            end
        end

        function obj = set.Events(obj, t)
            if obj.EventDim == 1
                obj.Time = t;
            else
                obj.Events_ = t;
            end
        end

        function n = get.NEvents(obj)
            if obj.EventDim == 1
                n = height(obj.Data);
            else
                n = numel(obj.Events_);
            end
        end

        function n = get.NGroups(obj)
            n = size(obj.Data, 3);
        end
    end
end