classdef MappableObjArray < spiky.core.ObjArray & spiky.core.MappableArray
    %MAPABLEOBJARRAY Class for ObjArrays that can be referenced by key

    methods
        function obj = MappableObjArray(array, options)
            %MAPABLEOBJARRAY Constructor for MappableObjArray class.
            arguments
                array cell = {}
                options.Class string = string.empty
            end
            optionsCell = namedargs2cell(options);
            obj@spiky.core.ObjArray(array, optionsCell{:});
        end
    end

    methods (Access=protected)
        function varargout = dotReference(obj, indexOp)
            [~, use] = obj.useKey(indexOp(1));
            if use
                [varargout{1:nargout}] = dotReference@spiky.core.MappableArray(obj, indexOp);
            else
                [varargout{1:nargout}] = dotReference@spiky.core.ObjArray(obj, indexOp);
            end
        end

        function obj = dotAssign(obj, indexOp, varargin)
            [~, use] = obj.useKey(indexOp(1));
            if use
                obj = dotAssign@spiky.core.MappableArray(obj, indexOp, varargin{:});
            else
                obj = dotAssign@spiky.core.ObjArray(obj, indexOp, varargin{:});
            end
        end

        function n = dotListLength(obj, indexOp, indexContext)
            [~, use] = obj.useKey(indexOp(1));
            if use
                n = dotListLength@spiky.core.MappableArray(obj, indexOp, indexContext);
            else
                n = dotListLength@spiky.core.ObjArray(obj, indexOp, indexContext);
            end
        end
    end
end