classdef Array < matlab.mixin.indexing.RedefinesParen & matlab.mixin.indexing.RedefinesBrace & ...
    matlab.mixin.indexing.RedefinesDot
    %ARRAY Base class for array-like data structures with dimension labels.

    properties (Dependent)
        Data
    end

    properties (Hidden)
        Data_
    end

    properties (Dependent)
        IsTable logical % Whether the Data property is a table
        IsCell logical % Whether the Data property is a cell array
    end

    methods (Static)
        function obj = empty(varargin)
            %EMPTY Create an empty array object.
            error("Empty array not supported. Use default constructor instead.");
        end

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
            dimLabelNames = {};
        end

        function dataNames = getExtraDataNames()
            %GETEXTRADATANAMES Get the names of extra data properties.
            %   These properties have the same size as Data, used to store additional data.
            %
            %   dataNames: extra data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = string.empty;
        end
    end

    methods
        function obj = Array(data)
            %ARRAY Constructor for Array class.
            arguments
                data = []
            end
            obj.Data = data;
            obj.verifyDimLabels();
        end

        function obj = apply(obj, fun, varargin)
            %APPLY Apply a function to the data
            %
            %   obj = apply(obj, fun, varargin)
            %   fun: function handle
            %   varargin: additional arguments passed to fun

            obj.Data = fun(obj.Data, varargin{:});
        end

        function obj = sum(obj, varargin)
            %SUM Compute the sum of the signal
            %
            %   obj = sum(obj, varargin)
            %   varargin: additional arguments passed to sum

            data = sum(obj.Data, varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = max(obj, varargin)
            %MAX Compute the maximum of the signal
            %
            %   obj = max(obj, varargin)
            %   varargin: additional arguments passed to max

            if isempty(varargin)
                varargin = {"all"};
            end
            data = max(obj.Data, [], varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = min(obj, varargin)
            %MIN Compute the minimum of the signal
            %
            %   obj = min(obj, varargin)
            %   varargin: additional arguments passed to min

            if isempty(varargin)
                varargin = {"all"};
            end
            data = min(obj.Data, [], varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = mean(obj, varargin)
            %MEAN Compute the mean of the signal
            %
            %   obj = mean(obj, varargin)
            %   varargin: additional arguments passed to mean

            data = mean(obj.Data, varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = median(obj, varargin)
            %MEDIAN Compute the median of the signal
            %
            %   obj = median(obj, varargin)
            %   varargin: additional arguments passed to median

            data = median(obj.Data, varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = uminus(obj)
            %UMINUS Negate the signal
            %
            %   obj = uminus(obj)

            obj.Data = -obj.Data;
        end

        function obj = plus(obj, obj2)
            %PLUS Add two signals
            %
            %   obj = plus(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data+obj2;
        end

        function obj = minus(obj, obj2)
            %MINUS Subtract two signals
            %
            %   obj = minus(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data-obj2;
        end

        function obj = times(obj, obj2)
            %TIMES Multiply two signals
            %
            %   obj = times(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data.*obj2;
        end

        function obj = rdivide(obj, obj2)
            %RDIVIDE Divide two signals
            %
            %   obj = rdivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data./obj2;
        end

        function obj = ldivide(obj, obj2)
            %LDIVIDE Divide two signals
            %
            %   obj = ldivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj2./obj.Data;
        end

        function obj = gt(obj, obj2)
            %GT Greater than comparison
            %
            %   obj = gt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data>obj2;
        end

        function obj = ge(obj, obj2)
            %GE Greater than or equal comparison
            %
            %   obj = ge(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data>=obj2;
        end

        function obj = lt(obj, obj2)
            %LT Less than comparison
            %
            %   obj = lt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data<obj2;
        end

        function obj = le(obj, obj2)
            %LE Less than or equal comparison
            %
            %   obj = le(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data<=obj2;
        end

        function obj = eq(obj, obj2)
            %EQ Equal comparison
            %
            %   obj = eq(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data==obj2;
        end

        function obj = ne(obj, obj2)
            %NE Not equal comparison
            %
            %   obj = ne(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data~=obj2;
        end

        function obj = and(obj, obj2)
            %AND Logical AND
            %
            %   obj = and(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data & obj2;
        end

        function obj = or(obj, obj2)
            %OR Logical OR
            %
            %   obj = or(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data | obj2;
        end

        function verifyDimLabels(obj)
            %VERIFYDIMLABELS Verify that dimension label properties are consistent with Data.
            labelNames = feval(class(obj)+".getDimLabelNames");
            for ii = 1:numel(labelNames)
                names = labelNames{ii};
                for jj = 1:numel(names)
                    name = names(jj);
                    assert(isprop(obj, name), "Property '%s' not found.", name);
                    assert(height(obj.(name))==size(obj, ii), ...
                        "Property '%s' height does not match dimension %d of Data.", ...
                        name, ii);
                end
            end
        end

        function obj = reshape(obj, varargin)
            assert(isempty(obj), "Reshape is only supported for empty Array objects.");
        end

        function varargout = size(obj, varargin)
            if obj.IsTable
                % Treat table as a column vector for size purposes
                sz = size(obj.Data, varargin{:});
                if isempty(varargin)
                    idx = 2;
                elseif isscalar(varargin)
                    idx = varargin{1}==2;
                else
                    dims = cell2mat(varargin);
                    idx = dims==2;
                end
                sz(idx) = 1;
                if nargout<=1
                    varargout{1} = sz;
                else
                    varargout(1:nargout) = num2cell(sz(1:nargout));
                end
            else
                [varargout{1:nargout}] = size(obj.Data, varargin{:});
            end
        end

        function obj = cat(dim, varargin)
            n = numel(varargin);
            obj = varargin{1};
            c = class(obj);
            labelNames = feval(c+".getDimLabelNames");
            nDims = numel(labelNames);
            for ii = 2:n
                objNew = varargin{ii};
                assert(isequal(class(objNew), c), ...
                    "All inputs to cat must be of the same class '%s'. Found '%s'.", ...
                    c, class(objNew));
                obj.Data = cat(dim, obj.Data, objNew.Data);
                if dim <= nDims
                    names = labelNames{dim};
                    for jj = 1:numel(names)
                        name = names(jj);
                        p = obj.(name);
                        pNew = objNew.(name);
                        obj.(name) = cat(1, p, pNew);
                    end
                end
            end
        end

        function n = numel(obj)
            st = dbstack("-completenames");
            if numel(st)>1 && startsWith(st(2).file, matlabroot)
                n = 1; % For internal use, report numel as 1 to display as a single object
                return
            end
            n = numel(obj.Data);
        end

        function data = get.Data(obj)
            data = obj.getData();
        end

        function obj = set.Data(obj, data)
            obj = obj.setData(data);
        end

        function tf = get.IsTable(obj)
            tf = istable(obj.Data);
        end

        function tf = get.IsCell(obj)
            tf = iscell(obj.Data);
        end
    end

    methods (Access=protected)
        function obj = initTable(obj, varargin)
            assert(mod(numel(varargin), 2)==0, ...
                "Table initialization requires name-value pairs.");
            names = cell2mat(varargin(1:2:end));
            values = varargin(2:2:end);
            obj.Data = table(values{:}, VariableNames=names);
        end

        function data = getData(obj)
            %GETDATA Get the Data property.
            %   Can be overridden by subclasses to customize data access.
            data = obj.Data_;
        end

        function obj = setData(obj, data)
            %SETDATA Set the Data property.
            %   Can be overridden by subclasses to customize data access.
            obj.Data_ = data;
        end

        function obj = subIndex(obj, idcDims, objNew)
            %SUBINDEX performs indexing on the Data field and the dimension label properties.
            arguments
                obj
                idcDims cell
                objNew = []
            end
            if obj.IsTable
                idcDims{2} = ':';
            end
            sz = size(obj.Data);
            extraDataNames = feval(class(obj)+".getExtraDataNames");
            if isequal(objNew, [])
                obj.Data = obj.Data(idcDims{:});
                for ii = 1:numel(extraDataNames)
                    name = extraDataNames(ii);
                    p = obj.(name);
                    obj.(name) = p(idcDims{:});
                end
            else
                obj.Data(idcDims{:}) = objNew.Data;
                for ii = 1:numel(extraDataNames)
                    name = extraDataNames(ii);
                    p = obj.(name);
                    pNew = objNew.(name);
                    p(idcDims{:}) = pNew;
                    obj.(name) = p;
                end
            end
            labelNames = feval(class(obj)+".getDimLabelNames");
            nDims = numel(sz);
            nLabels = numel(labelNames);
            if isscalar(idcDims) && nDims>1
                % Linear indexing into multi-dimensional array
                idx = idcDims{1};
                [idcDims{1:nDims}] = ind2sub(sz, idx);
            end
            for ii = 1:nLabels
                names = labelNames{ii};
                if numel(idcDims)<ii
                    idx = ':';
                else
                    idx = idcDims{ii};
                end
                for jj = 1:numel(names)
                    name = names(jj);
                    p = obj.(name);
                    if isequal(objNew, [])
                        obj.(name) = p(idx, :, :, :, :);
                    else
                        p(idx, :, :, :, :) = objNew.(name);
                        obj.(name) = p;
                    end
                end
            end
        end

        function obj = resize(obj, newSize)
            sz = arrayfun(@(x) 1:x, newSize, UniformOutput=false);
            obj = obj.subIndex(sz);
        end

        function varargout = parenReference(obj, indexOp)
            obj = obj.subIndex(indexOp(1).Indices);
            if isscalar(indexOp)
                varargout{1} = obj;
                return
            end
            [varargout{1:nargout}] = obj.(indexOp(2:end));
        end

        function obj = parenAssign(obj, indexOp, varargin)
            if isequal(obj, [])
                obj = feval(class(varargin{1}));
            end
            if isscalar(indexOp)
                obj1 = varargin{1};
                if isequal(obj1, [])
                    obj1 = feval(class(obj)+".empty");
                end
                obj = obj.subIndex(indexOp(1).Indices, obj1);
                obj.verifyDimLabels();
                return
            end
            objNew = obj.subIndex(indexOp(1).Indices);
            [objNew.(indexOp(2:end))] = varargin{:};
            obj = obj.subIndex(indexOp(1).Indices, objNew);
            obj.verifyDimLabels();
        end

        function obj = parenDelete(obj, indexOp)
            obj = obj.parenAssign(indexOp, []);
        end

        function n = parenListLength(obj, indexOp, indexContext)
            if isscalar(indexOp)
                n = 1;
                return
            end
            obj = obj.subIndex(indexOp(1).Indices);
            n = listLength(obj, indexOp(2:end), indexContext);
        end

        function varargout = braceReference(obj, indexOp)
            if obj.IsCell || obj.IsTable
                data = obj.Data{indexOp(1).Indices{:}};
            else
                data = obj.Data(indexOp(1).Indices{:});
            end
            if isscalar(indexOp)
                varargout{1} = data;
                return
            end
            [varargout{1:nargout}] = data.(indexOp(2:end));
        end

        function obj = braceAssign(obj, indexOp, varargin)
            if isscalar(indexOp)
                if obj.IsCell || obj.IsTable
                    [obj.Data{indexOp(1).Indices{:}}] = varargin{:};
                else
                    [obj.Data(indexOp(1).Indices{:})] = varargin{:};
                end
                return
            end
            if obj.IsCell || obj.IsTable
                data = obj.Data{indexOp(1).Indices{:}};
                [data.(indexOp(2:end))] = varargin{:};
                obj.Data{indexOp(1).Indices{:}} = data;
            else
                data = obj.Data(indexOp(1).Indices{:});
                [data.(indexOp(2:end))] = varargin{:};
                obj.Data(indexOp(1).Indices{:}) = data;
            end
            obj.verifyDimLabels();
        end

        function n = braceListLength(obj, indexOp, indexContext)
            if isscalar(indexOp)
                n = 1;
                return
            end
            n = listLength(obj.Data(indexOp(1).Indices{:}), indexOp(2:end), indexContext);
        end

        function varargout = dotReference(obj, indexOp)
            if obj.IsTable && ismember(indexOp(1).Name, obj.Data.Properties.VariableNames)
                [varargout{1:nargout}] = obj.Data.(indexOp);
            % elseif (exist(indexOp(1).Name, "builtin") || exist(indexOp(1).Name, "file"))
            %     % Handle function call
            %     if isscalar(indexOp)
            %         [varargout{1:nargout}] = feval(indexOp(1).Name, obj);
            %     elseif numel(indexOp)==2
            %         [varargout{1:nargout}] = feval(indexOp(1).Name, obj, indexOp(2).Indices{:});
            %     else
            %         out = feval(indexOp(1).Name, obj, indexOp(2).Indices{:});
            %         [varargout{1:nargout}] = out.(indexOp(3:end));
            %     end
            else
                error("Unrecognized method, property, or field '%s' for class '%s'.", ...
                    indexOp(1).Name, class(obj))
            end
        end

        function obj = dotAssign(obj, indexOp, varargin)
            if obj.IsTable && ismember(indexOp(1).Name, obj.Data.Properties.VariableNames)
                [obj.Data.(indexOp)] = varargin{:};
            else
                error("Unrecognized method, property, or field '%s' for class '%s'.", ...
                    indexOp(1).Name, class(obj))
            end
            obj.verifyDimLabels();
        end

        function n = dotListLength(obj, indexOp, indexContext)
            if isscalar(indexOp)
                n = 1;
                return
            end
            if obj.IsTable && ismember(indexOp(1).Name, obj.Data.Properties.VariableNames)
                n = listLength(obj.Data, indexOp, indexContext);
            else
                error("Unrecognized method, property, or field '%s' for class '%s'.", ...
                    indexOp(1).Name, class(obj))
            end
        end
    end
end