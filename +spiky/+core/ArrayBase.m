classdef (Abstract) ArrayBase < matlab.mixin.indexing.RedefinesParen & ...
    matlab.mixin.indexing.RedefinesBrace & ...
    matlab.mixin.indexing.RedefinesDot
    %ARRAYBASE Base class for array-like data structures with dimension labels.

    properties (Dependent)
        IsTable logical % Whether the Data property is a table
        IsCell logical % Whether the Data property is a cell array
        IsStruct logical % Whether the Data property is a struct array
    end

    methods (Static, Abstract)
        dataNames = getDataNames()
        %GETDATANAMES Get the names of all data properties.
        %   These properties must all have the same size. The first one is assumed to be the 
        %   main Data property.
        %
        %   dataNames: data property names, must be a string array
    end

    methods (Static)
        function obj = empty(varargin)
            %EMPTY Create an empty array object.
            obj = [];
            % error("Empty array not supported. Use default constructor instead.");
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
    end

    methods
        function obj = apply(obj, fun, varargin)
            %APPLY Apply a function to the data
            %
            %   obj = apply(obj, fun, varargin)
            %   fun: function handle
            %   varargin: additional arguments passed to fun

            obj = obj.setData(fun(obj.getData(), varargin{:}));
        end

        function obj = sum(obj, varargin)
            %SUM Compute the sum of the signal
            %
            %   obj = sum(obj, varargin)
            %   varargin: additional arguments passed to sum

            data = sum(obj.getData(), varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj = obj.setData(data);
        end

        function obj = max(obj, varargin)
            %MAX Compute the maximum of the signal
            %
            %   obj = max(obj, varargin)
            %   varargin: additional arguments passed to max

            if isempty(varargin)
                varargin = {"all"};
            end
            data = max(obj.getData(), [], varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj = obj.setData(data);
        end

        function obj = min(obj, varargin)
            %MIN Compute the minimum of the signal
            %
            %   obj = min(obj, varargin)
            %   varargin: additional arguments passed to min

            if isempty(varargin)
                varargin = {"all"};
            end
            data = min(obj.getData(), [], varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj = obj.setData(data);
        end

        function obj = mean(obj, varargin)
            %MEAN Compute the mean of the signal
            %
            %   obj = mean(obj, varargin)
            %   varargin: additional arguments passed to mean

            data = mean(obj.getData(), varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj = obj.setData(data);
        end

        function obj = median(obj, varargin)
            %MEDIAN Compute the median of the signal
            %
            %   obj = median(obj, varargin)
            %   varargin: additional arguments passed to median

            data = median(obj.getData(), varargin{:});
            obj = spiky.core.Array.resize(obj, size(data));
            obj = obj.setData(data);
        end

        function obj = uminus(obj)
            %UMINUS Negate the signal
            %
            %   obj = uminus(obj)

            obj = obj.setData(-obj.getData());
        end

        function obj = plus(obj, obj2)
            %PLUS Add two signals
            %
            %   obj = plus(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()+obj2);
        end

        function obj = minus(obj, obj2)
            %MINUS Subtract two signals
            %
            %   obj = minus(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()-obj2);
        end

        function obj = times(obj, obj2)
            %TIMES Multiply two signals
            %
            %   obj = times(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData().*obj2);
        end

        function obj = rdivide(obj, obj2)
            %RDIVIDE Divide two signals
            %
            %   obj = rdivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()./obj2);
        end

        function obj = ldivide(obj, obj2)
            %LDIVIDE Divide two signals
            %
            %   obj = ldivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj2./obj.getData());
        end

        function obj = gt(obj, obj2)
            %GT Greater than comparison
            %
            %   obj = gt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()>obj2);
        end

        function obj = ge(obj, obj2)
            %GE Greater than or equal comparison
            %
            %   obj = ge(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()>=obj2);
        end

        function obj = lt(obj, obj2)
            %LT Less than comparison
            %
            %   obj = lt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()<obj2);
        end

        function obj = le(obj, obj2)
            %LE Less than or equal comparison
            %
            %   obj = le(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()<=obj2);
        end

        function obj = eq(obj, obj2)
            %EQ Equal comparison
            %
            %   obj = eq(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()==obj2);
        end

        function obj = ne(obj, obj2)
            %NE Not equal comparison
            %
            %   obj = ne(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData()~=obj2);
        end

        function obj = and(obj, obj2)
            %AND Logical AND
            %
            %   obj = and(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData() & obj2);
        end

        function obj = or(obj, obj2)
            %OR Logical OR
            %
            %   obj = or(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.Array")
                obj2 = obj2.Data;
            end
            obj = obj.setData(obj.getData() | obj2);
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
                sz = size(obj.getData(), varargin{:});
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
                [varargout{1:nargout}] = size(obj.getData(), varargin{:});
            end
        end

        function obj = cat(dim, varargin)
            n = numel(varargin);
            obj = varargin{1};
            c = class(obj);
            labelNames = obj.getDimLabelNames();
            nDims = numel(labelNames);
            for ii = 2:n
                objNew = varargin{ii};
                assert(isequal(class(objNew), c), ...
                    "All inputs to cat must be of the same class '%s'. Found '%s'.", ...
                    c, class(objNew));
                dataNames = obj.getDataNames();
                datas = cell(numel(dataNames), 1);
                [datas{:}] = obj.getData();
                datasNew = cell(numel(dataNames), 1);
                [datasNew{:}] = objNew.getData();
                datas = cellfun(@(x, y) cat(dim, x, y), datas, datasNew, ...
                    UniformOutput=false);
                obj = obj.setData(datas{:});
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
            n = numel(obj.getData());
        end

        function tf = get.IsTable(obj)
            tf = istable(obj.getData());
        end

        function tf = get.IsCell(obj)
            tf = iscell(obj.getData());
        end

        function tf = get.IsStruct(obj)
            tf = isstruct(obj.getData());
        end
    end

    methods (Access=protected)
        function obj = initTable(obj, varargin)
            assert(mod(numel(varargin), 2)==0, ...
                "Table initialization requires name-value pairs.");
            names = cell2mat(varargin(1:2:end));
            values = varargin(2:2:end);
            n = max(cellfun(@(x) size(x, 1), values));
            if n==0
                return
            end
            for ii = 1:numel(values)
                v = values{ii};
                if isscalar(v)
                    values{ii} = repmat(v, n, 1);
                elseif isempty(v)
                    values{ii} = feval(class(v), NaN(n, 1));
                elseif size(v, 1)~=n
                    error("All table columns must have the same number of rows.");
                end
            end
            obj = obj.setData(table(values{:}, VariableNames=names));
        end

        function varargout = getData(obj)
            %GETDATA Get the Data properties.
            dataNames = obj.getDataNames();
            for ii = nargout:-1:1
                varargout{ii} = obj.(dataNames(ii));
            end
        end

        function obj = setData(obj, varargin)
            %SETDATA Set the Data properties.
            dataNames = obj.getDataNames();
            for ii = 1:numel(dataNames)
                obj.(dataNames(ii)) = varargin{ii};
            end
        end

        function obj = subIndex(obj, idcDims, varargin)
            %SUBINDEX performs indexing on the Data field and the dimension label properties.
            arguments
                obj
                idcDims cell
            end
            arguments (Repeating)
                varargin
            end
            if obj.IsTable || (~isempty(varargin) && varargin{1}.IsTable)
                idcDims{2} = ':';
                idcDims = idcDims(1:2);
            end
            sz = size(obj.getData());
            dataNames = obj.getDataNames();
            n = numel(dataNames);
            datas = cell(n, 1);
            [datas{:}] = obj.getData();
            if isempty(varargin)
                datas = cellfun(@(x) x(idcDims{:}), datas, UniformOutput=false);
                obj = obj.setData(datas{:});
            else
                objNew = varargin{1};
                for ii = 1:n
                    name = dataNames(ii);
                    p = obj.(name);
                    if isequal(p, [])
                        clear p
                    end
                    if isequal(objNew, [])
                        p(idcDims{:}) = [];
                    else
                        pNew = objNew.(name);
                        p(idcDims{:}) = pNew;
                    end
                    obj.(name) = p;
                end
            end
            labelNames = obj.getDimLabelNames();
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
                    if isequal(p, [])
                        clear p
                    end
                    if isempty(varargin)
                        obj.(name) = p(idx, :, :, :, :);
                    elseif isequal(objNew, [])
                        p(idx, :, :, :, :) = [];
                        obj.(name) = p;
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
            obj = obj.subIndex(indexOp(1).Indices, []);
        end

        function n = parenListLength(obj, indexOp, indexContext)
            if isscalar(indexOp)
                n = 1;
                return
            end
            obj = obj.subIndex(indexOp(1).Indices);
            n = listLength(obj, indexOp(2:end), indexContext);
        end

        function varargout = subIndexData(obj, idcDims, varargin)
            data = obj.getData();
            if isempty(varargin)
                if obj.IsTable || obj.IsCell
                    [varargout{1:nargout}] = data{idcDims{:}};
                else
                    [varargout{1:nargout}] = data(idcDims{:});
                end
            else
                if obj.IsTable || obj.IsCell
                    data{idcDims{:}} = varargin{:};
                else
                    data(idcDims{:}) = varargin{:};
                end
                obj = obj.setData(data);
                varargout{1} = obj;
            end
        end

        function varargout = braceReference(obj, indexOp)
            if isscalar(indexOp)
                [varargout{1:nargout}] = obj.subIndexData(indexOp(1).Indices);
                return
            end
            data = obj.subIndexData(indexOp(1).Indices);
            [varargout{1:nargout}] = data.(indexOp(2:end));
        end

        function obj = braceAssign(obj, indexOp, varargin)
            if isscalar(indexOp)
                obj = obj.subIndexData(indexOp(1).Indices, varargin{:});
                return
            end
            data = obj.subIndexData(indexOp(1).Indices);
            [data.(indexOp(2:end))] = varargin{:};
            obj = obj.subIndexData(indexOp(1).Indices, data);
            obj.verifyDimLabels();
        end

        function n = braceListLength(obj, indexOp, indexContext)
            if obj.IsCell || obj.IsTable
                n = listLength(obj.getData(), indexOp, indexContext);
            elseif ~isscalar(indexOp)
                data = obj.getData();
                data = data(indexOp(1).Indices{:});
                n = listLength(data, indexOp(2:end), indexContext);
            else
                n = 1;
            end
        end

        function checkField(obj, name)
            assert((obj.IsTable && ismember(name, obj.getData().Properties.VariableNames)) || ...
                (obj.IsStruct && isfield(obj.getData(), name)), ...
                "Unrecognized field '%s' for class '%s'.", name, class(obj));
        end

        function varargout = dotReference(obj, indexOp)
            obj.checkField(indexOp(1).Name);
            [varargout{1:nargout}] = obj.getData().(indexOp(1).Name);
            if isscalar(indexOp)
                return
            end
            [varargout{1:nargout}] = varargout{1}.(indexOp(2:end));
        end

        function obj = dotAssign(obj, indexOp, varargin)
            obj.checkField(indexOp(1).Name);
            data = obj.getData().(indexOp(1).Name);
            if isscalar(indexOp)
                [data] = varargin{:};
            else
                [data.(indexOp(2:end))] = varargin{:};
            end
            obj.getData().(indexOp(1).Name) = data;
            obj.verifyDimLabels();
        end

        function n = dotListLength(obj, indexOp, indexContext)
            obj.checkField(indexOp(1).Name);
            n = listLength(obj.getData(), indexOp, indexContext);
        end
    end
end