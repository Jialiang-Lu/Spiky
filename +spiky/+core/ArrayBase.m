classdef (Abstract) ArrayBase
    %ARRAYBASE Base class for array-like data structures with dimension labels.

    properties (Dependent)
        IsTable logical % Whether the Data property is a table
        IsCell logical % Whether the Data property is a cell array
        IsStruct logical % Whether the Data property is a struct array
        VarNames string % Variable names of the Data table, if applicable
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
            obj = obj.resize(size(data));
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
            obj = obj.resize(size(data));
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
            obj = obj.resize(size(data));
            obj = obj.setData(data);
        end

        function obj = mean(obj, varargin)
            %MEAN Compute the mean of the signal
            %
            %   obj = mean(obj, varargin)
            %   varargin: additional arguments passed to mean

            data = mean(obj.getData(), varargin{:});
            obj = obj.resize(size(data));
            obj = obj.setData(data);
        end

        function obj = median(obj, varargin)
            %MEDIAN Compute the median of the signal
            %
            %   obj = median(obj, varargin)
            %   varargin: additional arguments passed to median

            data = median(obj.getData(), varargin{:});
            obj = obj.resize(size(data));
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

        function [obj, idc] = sort(obj, varargin)
            %SORT Sort the data
            %
            %   [obj, idc] = sort(obj, varargin)
            %   varargin: additional arguments passed to sort

            data = obj.getData();
            [~, idc] = sortrows(data, varargin{:});
            if ~isempty(varargin) && isnumeric(varargin{1})
                dim = varargin{1};
            else
                dim = 1;
            end
            if dim==1
                obj = subsref(obj, substruct('()', {idc, ':'}));
            elseif dim==2
                obj = subsref(obj, substruct('()', {':', idc}));
            elseif dim==3
                obj = subsref(obj, substruct('()', {':', ':', idc}));
            elseif dim==4
                obj = subsref(obj, substruct('()', {':', ':', ':', idc}));
            elseif dim==5
                obj = subsref(obj, substruct('()', {':', ':', ':', ':', idc}));
            else
                error("Sorting along dimension %d is not supported.", dim);
            end
        end

        function [obj, idc] = sortrows(obj, varargin)
            %SORTRows Sort the data along the first dimension
            %
            %   [obj, idc] = sortrows(obj, varargin)
            %   varargin: additional arguments passed to sortrows

            data = obj.getData();
            [~, idc] = sortrows(data, varargin{:});
            obj = subsref(obj, substruct('()', {idc, ':'}));
        end

        function varargout = size(obj, varargin)
            if isempty(obj)
                [varargout{1:nargout}] = size(double.empty(0, 1), varargin{:});
                return
            end
            dataNames = obj.getDataNames();
            name = dataNames(1);
            if istable(obj.(name))
                % Treat table as a column vector for size purposes
                sz = size(obj.(name), varargin{:});
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
                [varargout{1:nargout}] = size(obj.(name), varargin{:});
            end
        end

        function l = length(obj)
            sz = size(obj);
            l = max(sz);
        end

        function obj = horzcat(varargin)
            obj = cat(2, varargin{:});
        end

        function obj = vertcat(varargin)
            obj = cat(1, varargin{:});
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
            n = prod(size(obj));
        end

        function tf = get.IsTable(obj)
            tf = istable(obj.getData());
            if isempty(tf)
                tf = false;
            end
        end

        function tf = get.IsCell(obj)
            tf = iscell(obj.getData());
            if isempty(tf)
                tf = false;
            end
        end

        function tf = get.IsStruct(obj)
            tf = isstruct(obj.getData());
            if isempty(tf)
                tf = false;
            end
        end

        function names = get.VarNames(obj)
            names = obj.getVarNames();
        end

        function varargout = subsref(obj, s)
            if isequal(obj, [])
                [varargout{1:nargout}] = builtin("subsref", obj, s);
                return
            end
            s = obj.processSubstruct(s);
            switch s(1).type
                case '()'
                    obj = obj.subIndex(s(1).subs);
                    if isscalar(s)
                        varargout{1} = obj;
                        return
                    end
                    [varargout{1:nargout}] = subsref(obj, s(2:end));
                case '{}'
                    [varargout{1:nargout}] = obj.subIndexData(s(1).subs);
                    if isscalar(s)
                        return
                    end
                    if nargout==1
                        varargout{1} = subsref(varargout{1}, s(2:end));
                    else
                        varargout = cellfun(@(x) subsref(x, s(2:end)), varargout, ...
                            UniformOutput=false);
                    end
                case '.'
                    if ~strcmp(s(1).subs, "VarNames") && ismember(s(1).subs, obj.VarNames)
                        [varargout{1:nargout}] = obj.subIndexStruct(s(1).subs);
                        if isscalar(s)
                            return
                        end
                        varargout{1} = subsref(varargout{1}, s(2:end));
                        return
                    end
                    idx = 1;
                    if numel(s)>1 && strcmp(s(2).type, '()') && isstrprop(s(1).subs(1), "lower")
                        idx = 2;
                    end
                    if numel(s)==idx
                        [varargout{1:nargout}] = builtin("subsref", obj, s);
                        return
                    end
                    obj = builtin("subsref", obj, s(1:idx));
                    [varargout{1:nargout}] = subsref(obj, s(idx+1:end));
                otherwise
                    error("Unsupported subscript type '%s'.", s(1).type);
            end
        end

        function obj = subsasgn(obj, s, varargin)
            if isequal(obj, [])
                obj = feval(class(varargin{1}));
            end
            s = obj.processSubstruct(s);
            switch s(1).type
                case '()'
                    if isscalar(s)
                        obj = obj.subIndex(s(1).subs, varargin{:});
                        return
                    end
                    objNew = obj.subIndex(s(1).subs);
                    objNew = subsasgn(objNew, s(2:end), varargin{:});
                    obj = obj.subIndex(s(1).subs, objNew);
                case '{}'
                    if isscalar(s)
                        obj = obj.subIndexData(s(1).subs, varargin{:});
                        return
                    end
                    data = obj.subIndexData(s(1).subs);
                    data = subsasgn(data, s(2:end), varargin{:});
                    obj = obj.subIndexData(s(1).subs, data);
                case '.'
                    if ~strcmp(s(1).subs, "VarNames") && ismember(s(1).subs, obj.VarNames)
                        if isscalar(s)
                            obj = obj.subIndexStruct(s(1).subs, varargin{:});
                            return
                        end
                        data = obj.subIndexStruct(s(1).subs);
                        data = subsasgn(data, s(2:end), varargin{:});
                        obj = obj.subIndexStruct(s(1).subs, data);
                        return
                    end
                    if isscalar(s)
                        obj = builtin("subsasgn", obj, s, varargin{:});
                        return
                    end
                    obj1 = builtin("subsref", obj, s(1));
                    obj1 = subsasgn(obj1, s(2:end), varargin{:});
                    obj = subsasgn(obj, s(1), obj1);
                otherwise
                    error("Unsupported subscript type '%s'.", s(1).type);
            end
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            if isa(obj, "spiky.core.ArrayBase")
                s = obj.processSubstruct(s);
            end
            switch s(1).type
                case '()'
                    if isscalar(s)
                        n = 1;
                        return
                    end
                    obj = subsref(obj, s(1));
                    n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
                case '{}'
                    data = obj.getData();
                    if ~iscell(data) && ~istable(data)
                        s(1).type = '()';
                    end
                    n = numArgumentsFromSubscript(data, s(1), indexingContext);
                    if isscalar(s)
                        return
                    end
                    if iscell(data) && n>1 && numel(s)==2 && strcmp(s(2).type, '.')
                        return
                    end
                    assert(n==1, "Intermediate brace '{}' indexing produced a comma-separated " + ...
                        "list with %d values, but it must produce a single value when followed by " + ...
                        "subsequent indexing operations.", n)
                    data = subsref(data, s(1));
                    n = numArgumentsFromSubscript(data, s(2:end), indexingContext);
                case '.'
                    if isscalar(s)
                        if ~strcmp(s.subs, "getData")
                            n = 1;
                        else
                            n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
                        end
                        return
                    end
                    idx = 1;
                    if numel(s)>1 && strcmp(s(2).type, '()') && isstrprop(s(1).subs(1), "lower")
                        idx = 2;
                    end
                    if numel(s)==idx
                        n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
                        return
                    end
                    obj = subsref(obj, s(1:idx));
                    n = numArgumentsFromSubscript(obj, s(idx+1:end), indexingContext);
                otherwise
                    error("Unsupported subscript type '%s'.", s(1).type);
            end
        end

        function ind = end(obj,k,n)
            sz = size(obj);
            if k < n
                ind = sz(k);
            else
                ind = prod(sz(k:end));
            end
        end

        function tf = isempty(obj)
            tf = builtin("isempty", obj);
            if ~tf && isempty(obj.getData())
                tf = true;
            end
        end
    end

    methods (Access=protected)
        function verifyDimLabels(obj)
            %VERIFYDIMLABELS Verify that dimension label properties are consistent with Data.
            dataNames = obj.getDataNames();
            labelNames = obj.getDimLabelNames();
            data = obj.(dataNames(1));
            for ii = 1:numel(labelNames)
                names = labelNames{ii};
                for jj = 1:numel(names)
                    name = names(jj);
                    if height(obj.(name))>1 && size(data, ii)>1
                        assert(height(obj.(name))==size(data, ii), ...
                            "Property '%s' height does not match dimension %d of Data.", ...
                            name, ii);
                    end
                end
            end
        end

        function s = processSubstruct(obj, s)
            %PROCESSSUBSTRUCT Process subscript structure before subsref/subsasgn.
            %
            %   s: subscript structure
            % Default implementation does nothing
        end

        function obj = initTable(obj, varargin)
            assert(mod(numel(varargin), 2)==0, ...
                "Table initialization requires name-value pairs.");
            names = horzcat(varargin{1:2:end});
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

        function varargout = getData(obj, n)
            %GETDATA Get the Data properties.
            arguments (Input)
                obj
                n (1, 1) double = 0
            end
            dataNames = obj.getDataNames();
            if n==0
                n = numel(dataNames);
            else
                n = min(n, numel(dataNames));
            end
            for ii = n:-1:1
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
        
        function names = getVarNames(obj)
            %GETVARNAMES Get variable names of the Data table, if applicable.
            if obj.IsTable
                data = obj.getData();
                names = string(data.Properties.VariableNames);
            elseif obj.IsStruct
                data = obj.getData();
                names = string(fieldnames(data));
            else
                names = string.empty;
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
            if obj.IsTable || (~isempty(varargin) && ~isempty(varargin{1}) && varargin{1}.IsTable)
                idcDims{2} = ':';
                idcDims = idcDims(1:2);
            end
            dataNames = obj.getDataNames();
            n = numel(dataNames);
            if isempty(varargin)
                for ii = 1:n
                    name = dataNames(ii);
                    p = obj.(name);
                    sz = size(p);
                    obj.(name) = subsref(p, substruct('()', idcDims));
                end
            else
                objNew = varargin{1};
                for ii = 1:n
                    name = dataNames(ii);
                    p = obj.(name);
                    sz = size(p);
                    if isequal(objNew, [])
                        p = subsasgn(p, substruct('()', idcDims), []);
                    else
                        if isempty({objNew.(name)})
                            continue
                        end
                        pNew = objNew.(name);
                        if ~any(size(p)) && ...
                                (isa(pNew, "spiky.core.ArrayBase") || istable(pNew))
                            p = feval(class(pNew));
                        end
                        p = subsasgn(p, substruct('()', idcDims), pNew);
                    end
                    obj.(name) = p;
                end
            end
            labelNames = obj.getDimLabelNames();
            nDims = numel(sz);
            nLabels = numel(labelNames);
            if isscalar(idcDims) && sum(sz>1)>1
                % Linear indexing into multi-dimensional array
                idx = idcDims{1};
                [idcDims{1:nDims}] = ind2sub(sz, idx);
            end
            for ii = 1:nLabels
                names = labelNames{ii};
                if numel(idcDims)<ii
                    idx = 1;
                else
                    idx = idcDims{ii};
                end
                for jj = 1:numel(names)
                    name = names(jj);
                    if isempty({obj.(name)})
                        continue
                    end
                    p = obj.(name);
                    if isequal(p, []) || ~any(size(p))
                        clear p
                    end
                    if isempty(varargin)
                        obj.(name) = subsref(p, substruct('()', {idx, ':', ':', ':', ':'}));
                    elseif isequal(objNew, [])
                        obj.(name) = subsasgn(p, substruct('()', {idx, ':', ':', ':', ':'}), []);
                    else
                        obj.(name) = subsasgn(p, substruct('()', {idx, ':', ':', ':', ':'}), objNew.(name));
                    end
                end
            end
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

        function varargout = subIndexStruct(obj, name, varargin)
            data = obj.getData();
            assert(isstruct(data) || istable(data), ...
                "Unrecognized method, property, or field '%s' for class %s.", name, class(obj));
            if isempty(varargin)
                % if isstruct(data)
                %     assert(isfield(data, name), ...
                %         "Field '%s' does not exist in the Data struct array.", name);
                % elseif istable(data)
                %     assert(ismember(name, data.Properties.VariableNames), ...
                %         "Variable '%s' does not exist in the Data table.", name);
                % end
                if isscalar(data) || istable(data)
                    varargout{1} = data.(name);
                else
                    varargout{1} = arrayfun(@(x) x.(name), data);
                end
            else
                if isscalar(data) || istable(data)
                    data.(name) = varargin{1};
                else
                    assert(isequal(size(varargin{1}), size(data)), ...
                        "Size of assigned value does not match size of Data struct array.");
                    for ii = 1:numel(data)
                        data(ii).(name) = varargin{1}(ii);
                    end
                end
                obj = obj.setData(data);
                varargout{1} = obj;
            end
        end

        function obj = resize(obj, newSize)
            sz = arrayfun(@(x) 1:x, newSize, UniformOutput=false);
            obj = obj.subIndex(sz);
        end
    end
end