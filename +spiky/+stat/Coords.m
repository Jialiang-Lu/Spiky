classdef Coords
    % Coords Class representing a coordinate system in a N-D space

    properties
        Origin (:, 1) double
        Bases (:, :) double
        Props (1, 1) struct
    end

    properties (Dependent)
        NDim double
        NBases double
    end

    methods
        function obj = Coords(origin, bases, varargin)
            %COORDS Create a new instance of Coords
            %
            %   Coords(origin, bases, ...) creates a new instance of Coords
            %
            %   origin: origin of the coordinate system
            %   bases: basis vectors
            %   Name-Value pairs: additional properties
            %
            %   obj: Coords object
            arguments
                origin double = []
                bases double = []
            end
            arguments (Repeating)
                varargin
            end
            obj.Origin = origin;
            obj.Bases = bases;
            obj.Props = struct();
            for ii = 1:2:length(varargin)
                obj.Props.(varargin{ii}) = varargin{ii + 1};
            end
        end

        function n = get.NDim(obj)
            n = size(obj.Bases, 1);
        end

        function n = get.NBases(obj)
            n = size(obj.Bases, 2);
        end

        function data = project(obj, data, idcDim)
            %PROJECT Project the data onto the coordinate system
            %
            %   data = PROJECT(obj, data)
            %
            %   obj: coordinate system
            %   data: data to project, nDim x nObs
            %   idcDim: indices of the dimensions to project
            %
            %   data: projected data, length(idcDim) x nObs
            arguments
                obj spiky.stat.Coords
                data double
                idcDim double = []
            end
            if size(data, 1) ~= obj.NDim
                error("The number of dimensions must be the same as the number of dimensions in the coordinate system")
            end
            if isempty(idcDim)
                idcDim = 1:obj.NBases;
            end
            B = obj.Bases(:, idcDim);
            data = (B'*B)\(B'*(data - obj.Origin));
        end

        function varargout = subsref(obj, s)
            if isempty(obj)
                [varargout{1:nargout}] = builtin("subsref", obj, s);
                return
            end
            switch s(1).type
                case '.'
                    if isfield(obj.Props, s(1).subs)
                        s1 = substruct(".", "Props");
                        s = [s1, s];
                    end
            end
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end
    end
end