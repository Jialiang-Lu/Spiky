classdef Trig < spiky.core.TimeTable

    properties (Hidden)
        Events_ (:, 1) double
    end
    
    properties
        EventDim (1, 1) double = 1
        Window (:, :) double
    end

    properties (Dependent)
        Events (:, 1) double
        NEvents (1, 1) double
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Events"];
        end
    end

    methods
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

        % function varargout = subsref(obj, s)
        %     [varargout{1:nargout}] = builtin("subsref", obj, s);
        % end

        % function obj = subsasgn(obj, s, varargin)
        %     obj = builtin("subsasgn", obj, s, varargin{:});
        % end

        % function varargout = size(obj, varargin)
        %     [varargout{1:nargout}] = builtin("size", obj, varargin{:});
        % end
    end
end