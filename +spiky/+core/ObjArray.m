classdef ObjArray < spiky.core.ArrayBase
    %OBJARRAY An homogeneous array of objects
    %   MATLAB doesn't internally support arrays of non-scalar objects. This class
    %   provides a workaround by storing the objects in cell array and accessing
    %   them like a struct array.

    properties
        Array cell
    end

    properties (Dependent)
        ElementClass string
    end

    methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = "Array";
        end
    end
    
    methods
        function obj = ObjArray(array, options)
            %OBJARRAY Create a new instance of ObjArray
            arguments
                array cell = {}
                options.Class string = string.empty
            end
            if isempty(array)
                return
            end
            if ~isempty(options.Class)
                cls = options.Class;
            else
                cls = class(array{1});
            end
            assert(all(cellfun(@(x) isa(x, cls), array), "all"), ...
                "All elements in the array must be of class '%s'.", cls);
            obj = obj.setData(array);
        end

        function cls = get.ElementClass(obj)
            %GET.ELEMENTCLASS Get the class name of the elements in the ObjArray
            %
            %   cls: class name of the elements
            arguments (Output)
                cls (1, 1) string
            end
            data = obj.getData();
            if isempty(data)
                cls = "";
            else
                cls = class(data{1});
            end
        end
    end

    methods (Access = protected)
        function checkField(obj, name)
            cls = obj.ElementClass;
            assert(~isempty(cls), "The ObjArray is empty.");
            % assert(ismember(name, properties(cls)), ...
            %     "Field '%s' does not exist in class '%s'.", name, cls);
        end

        function varargout = dotReference(obj, indexOp)
            obj.checkField(indexOp(1).Name);
            data = cellfun(@(x) x.(indexOp(1).Name), obj.getData(), UniformOutput=false);
            [varargout{1:nargout}] = data{:};
            if isscalar(indexOp)
                return
            end
            [varargout{1:nargout}] = varargout{1}.(indexOp(2:end));
        end

        function obj = dotAssign(obj, indexOp, varargin)
            obj.checkField(indexOp(1).Name);
            data = obj.getData();
            if isscalar(varargin) && ~isscalar(data)
                varargin = repmat(varargin, size(data));
            end
            % data1 = cellfun(@(x) x.(indexOp(1).Name), data, UniformOutput=false);
            for ii = 1:numel(data)
                data{ii}.(indexOp) = varargin{1};
            end
            obj = obj.setData(data);
            obj.verifyDimLabels();
        end

        function n = dotListLength(obj, indexOp, indexContext)
            obj.checkField(indexOp(1).Name);
            n = numel(obj.getData());
        end
    end
end