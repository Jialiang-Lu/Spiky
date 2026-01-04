classdef (Abstract) MappableArray < spiky.core.ArrayBase
    %MAPABLEARRAY Class for arrays that can be referenced by key

    properties (Access=protected, Dependent)
        Key string
    end

    methods
        function key = get.Key(obj)
            key = obj.getKey();
        end
    end

    methods (Access=protected)
        function [idc, use] = useKey(obj, op)
            arguments (Input)
                obj
                op matlab.indexing.IndexingOperation
            end
            arguments (Output)
                idc cell
                use logical
            end
            idc = {};
            use = false;
            switch op.Type
                case {"Paren", "ParenDelete", "Brace"}
                    isKey = cellfun(@isstring, op.Indices);
                    if any(isKey)
                        keys = [op.Indices{isKey}];
                        idc = {ismember([obj.Key], keys), ':', ':', ':', ':'};
                        use = true;
                    end
                case "Dot"
                    if isprop(obj, op.Name) || ...
                        (obj.IsTable && ismember(op.Name, obj.Data.Properties.VariableNames))
                        return
                    end
                    isKey = [obj.Key]==op.Name;
                    if any(isKey)
                        idc = {isKey, ':', ':', ':', ':'};
                        use = true;
                    end
            end
        end
        
        function varargout = parenReference(obj, indexOp)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                obj = obj(idc{:});
                if isscalar(indexOp)
                    varargout{1} = obj;
                    return
                end
                [varargout{1:nargout}] = obj.(indexOp(2:end));
            else
                [varargout{1:nargout}] = parenReference@spiky.core.ArrayBase(obj, indexOp);
            end
        end

        function obj = parenAssign(obj, indexOp, varargin)
            if isequal(obj, [])
                obj = feval(class(varargin{1}));
            end
            [idc, use] = obj.useKey(indexOp(1));
            if use
                if isscalar(indexOp)
                    obj1 = varargin{1};
                    if isequal(obj1, [])
                        obj1 = feval(class(obj));
                    end
                    obj = obj.subIndex(idc, obj1);
                    obj.verifyDimLabels();
                    return
                end
                objNew = obj.subIndex(idc, obj1);
                [objNew.(indexOp(2:end))] = varargin{:};
                obj = obj.subIndex(idc, objNew);
                obj.verifyDimLabels();
            else
                obj = parenAssign@spiky.core.ArrayBase(obj, indexOp, varargin{:});
            end
        end

        function n = parenListLength(obj, indexOp, indexContext)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                obj = obj(idc{:});
                if isscalar(indexOp)
                    n = 1;
                    return
                end
                n = listLength(obj, indexOp(2:end), indexContext);
            else
                n = parenListLength@spiky.core.ArrayBase(obj, indexOp, indexContext);
            end
        end

        function varargout = braceReference(obj, indexOp)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                [varargout{1:nargout}] = obj.Data(idc{:});
            else
                [varargout{1:nargout}] = braceReference@spiky.core.ArrayBase(obj, indexOp);
            end
        end

        function obj = braceAssign(obj, indexOp, varargin)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                if isscalar(indexOp)
                    [obj.Data(idc)] = varargin{:};
                    return
                end
                data = obj.Data(idc{:});
                [data.(indexOp(2:end))] = varargin{:};
                obj.Data(idc{:}) = data;
                obj.verifyDimLabels();
            else
                obj = braceAssign@spiky.core.ArrayBase(obj, indexOp, varargin{:});
            end
        end

        function n = braceListLength(obj, indexOp, indexContext)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                if isscalar(indexOp)
                    n = 1;
                    return
                end
                n = listLength(obj.Data(idc{:}), indexOp(2:end), indexContext);
            else
                n = braceListLength@spiky.core.ArrayBase(obj, indexOp, indexContext);
            end
        end

        function varargout = dotReference(obj, indexOp)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                obj = obj(idc{:});
                if isscalar(indexOp)
                    varargout{1} = obj;
                    return
                end
                [varargout{1:nargout}] = obj.(indexOp(2:end));
            else
                [varargout{1:nargout}] = dotReference@spiky.core.ArrayBase(obj, indexOp);
            end
        end

        function obj = dotAssign(obj, indexOp, varargin)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                if isscalar(indexOp)
                    [obj(idc)] = varargin{:};
                    return
                end
                objNew = obj(idc{:});
                [objNew.(indexOp(2:end))] = varargin{:};
                obj = obj.subIndex(idc, objNew);
                obj.verifyDimLabels();
            else
                obj = dotAssign@spiky.core.ArrayBase(obj, indexOp, varargin{:});
            end
        end

        function n = dotListLength(obj, indexOp, indexContext)
            [idc, use] = obj.useKey(indexOp(1));
            if use
                obj = obj(idc{:});
                if isscalar(indexOp)
                    n = 1;
                    return
                end
                n = listLength(obj, indexOp(2:end), indexContext);
            else
                n = dotListLength@spiky.core.ArrayBase(obj, indexOp, indexContext);
            end
        end
    end

    methods (Abstract, Access=protected)
        key = getKey(obj)
    end
end