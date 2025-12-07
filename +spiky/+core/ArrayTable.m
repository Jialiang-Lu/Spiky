classdef (Abstract) ArrayTable

    properties
        Data
    end

    methods (Static)
        % The following functions can be overridden by subclasses to customize the behavior
        % of indexing and concatenation.

        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the ArrayTable. Dimension names are names of
            %   fields that have the same size as the corresponding dimension of Data, even after
            %   indexing or concatenation. Multiple names for the same dimension can be separated by 
            %   commas.
            %
            %   dimNames: dimension names
            arguments (Output)
                dimNames string
            end
            dimNames = string.empty;
        end

        function [extraDataName, scalarDimension] = getExtraDataName()
            %GETEXTRADATANAME Get the name of the extra data field
            %
            %   extraDataName: name of the each data field, empty if no extra data field
            %   scalarDimension: indices of the scalar dimension for each extra data field
            arguments (Output)
                extraDataName string
                scalarDimension cell
            end
            extraDataName = string.empty;
            scalarDimension = cell.empty;
        end

        function index = getScalarDimension()
            %GETSCALARDIMENSION Get the scalar dimension of the ArrayTable
            %
            %   index: index of the scalar dimension, 0 means no scalar dimension, 
            %       1 means obj(idx) equals obj(idx, :), 2 means obj(idx) equals obj(:, idx), etc.
            arguments (Output)
                index double
            end
            index = 0;
        end

        function b = isScalarRow()
            %ISSCALARROW if each row contains heterogeneous data and should be treated as a scalar
            %   This is useful if the Data is a table or a cell array and the number of columns is fixed.
            %
            %   b: true if each row is a scalar, false otherwise
            arguments (Output)
                b logical
            end
            b = false;
        end
    end

    methods (Static, Access=private)
        function obj = resize(obj, sz)
            sz = arrayfun(@(x) 1:x, sz, UniformOutput=false);
            s = substruct('()', sz);
            obj = subsref(obj, s);
        end
    end

    methods
        function obj = ArrayTable(data)
            arguments
                data = []
            end
            obj.Data = data;
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
            obj = spiky.core.ArrayTable.resize(obj, size(data));
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
            obj = spiky.core.ArrayTable.resize(obj, size(data));
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
            obj = spiky.core.ArrayTable.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = mean(obj, varargin)
            %MEAN Compute the mean of the signal
            %
            %   obj = mean(obj, varargin)
            %   varargin: additional arguments passed to mean

            data = mean(obj.Data, varargin{:});
            obj = spiky.core.ArrayTable.resize(obj, size(data));
            obj.Data = data;
        end

        function obj = median(obj, varargin)
            %MEDIAN Compute the median of the signal
            %
            %   obj = median(obj, varargin)
            %   varargin: additional arguments passed to median

            data = median(obj.Data, varargin{:});
            obj = spiky.core.ArrayTable.resize(obj, size(data));
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

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data+obj2;
        end

        function obj = minus(obj, obj2)
            %MINUS Subtract two signals
            %
            %   obj = minus(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data-obj2;
        end

        function obj = times(obj, obj2)
            %TIMES Multiply two signals
            %
            %   obj = times(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data.*obj2;
        end

        function obj = rdivide(obj, obj2)
            %RDIVIDE Divide two signals
            %
            %   obj = rdivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data./obj2;
        end

        function obj = ldivide(obj, obj2)
            %LDIVIDE Divide two signals
            %
            %   obj = ldivide(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj2./obj.Data;
        end

        function obj = gt(obj, obj2)
            %GT Greater than comparison
            %
            %   obj = gt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data>obj2;
        end

        function obj = ge(obj, obj2)
            %GE Greater than or equal comparison
            %
            %   obj = ge(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data>=obj2;
        end

        function obj = lt(obj, obj2)
            %LT Less than comparison
            %
            %   obj = lt(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data<obj2;
        end

        function obj = le(obj, obj2)
            %LE Less than or equal comparison
            %
            %   obj = le(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data<=obj2;
        end

        function obj = eq(obj, obj2)
            %EQ Equal comparison
            %
            %   obj = eq(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data==obj2;
        end

        function obj = ne(obj, obj2)
            %NE Not equal comparison
            %
            %   obj = ne(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data~=obj2;
        end

        function obj = and(obj, obj2)
            %AND Logical AND
            %
            %   obj = and(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data & obj2;
        end

        function obj = or(obj, obj2)
            %OR Logical OR
            %
            %   obj = or(obj, obj2)
            %   obj2: Lfp object

            if isa(obj2, "spiky.core.ArrayTable")
                obj2 = obj2.Data;
            end
            obj.Data = obj.Data | obj2;
        end

        function s = checkIndexing(obj, s)
            if ismember(s(1).type, {'()', '{}'})
                if obj.isScalarRow() && strcmp(s(1).type, '()')
                    % Obj is treated as a column vector
                    assert(isscalar(s(1).subs) || s(1).subs{2}==':' || s(1).subs{2}==1, ...
                        "Object is a column vector, only scalar subscripts are allowed");
                    s(1).subs = {s(1).subs{1}, ':'};
                elseif isscalar(s(1).subs)
                    % If the first subscript is a scalar and the object has a scalar dimension,
                    % we need to adjust the subscripts to include all dimensions.
                    idx = s(1).subs{1};
                    switch obj.getScalarDimension()
                        case 1
                            s(1).subs = {idx, ':'};
                        case 2
                            s(1).subs = {':', idx};
                        case 3
                            s(1).subs = {':', ':', idx};
                    end
                end
            end
        end

        function varargout = subsref(obj, s)
            if isempty(obj)
                [varargout{1:nargout}] = builtin("subsref", obj, s);
                return
            end
            s = checkIndexing(obj, s);
            switch s(1).type
                case '.'
                    if isprop(obj, s(1).subs)
                        obj = builtin("subsref", obj, s(1));
                        if isscalar(s)
                            varargout{1} = obj;
                        else
                            [varargout{1:nargout}] = subsref(obj, s(2:end));
                        end
                        return
                    end
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        if isscalar(s)
                            varargout{1} = subsref(obj.Data, s);
                        else
                            obj = subsref(obj.Data, s(1));
                            [varargout{1:nargout}] = subsref(obj, s(2:end));
                        end
                        return
                    end
                    if isfield(obj.Data(1, 1), s(1).subs) || isprop(obj.Data(1, 1), s(1).subs)
                        obj1 = reshape(vertcat(obj.Data.(s(1).subs)), ...
                            size(obj.Data));
                        if isscalar(s)
                            varargout{1} = obj1;
                        else
                            [varargout{1:nargout}] = subsref(obj1, s(2:end));
                        end
                        return
                    end
                case '()'
                    sd = s(1);
                    obj.Data = subsref(obj.Data, sd);
                    [edn, sdim] = feval(class(obj)+".getExtraDataName");
                    for ii = 1:numel(edn)
                        name = edn(ii);
                        if name==""
                            continue
                        end
                        sd1 = sd;
                        sd1.subs(sdim{ii}) = {':'};
                        obj.(name) = subsref(obj.(name), sd1);
                    end
                    dn = feval(class(obj)+".getDimNames");
                    for ii = 1:numel(dn)
                        name = dn(ii);
                        if name==""
                            continue
                        end
                        sd1 = sd;
                        if ii>numel(sd.subs)
                            sd1.subs = {1};
                        else
                            sd1.subs = sd1.subs(ii);
                        end
                        n = extract(name, alphanumericsPattern+optionalPattern("'"));
                        for jj = 1:numel(n)
                            n1 = n(jj);
                            sd2 = sd1;
                            if endsWith(n1, "'")
                                n1 = extractBefore(n1, "'");
                                sd2.subs = [':' , sd2.subs{1}];
                            else
                                sd2.subs{2} = ':';
                            end
                            obj.(n1) = subsref(obj.(n1), sd2);
                        end
                    end
                    if isscalar(s)
                        varargout{1} = obj;
                    else
                        [varargout{1:nargout}] = subsref(obj, s(2:end));
                    end
                    return
                case '{}'
                    s(1).type = '()';
                    if isscalar(s)
                        varargout{1} = subsref(obj.Data, s);
                    else
                        obj = subsref(obj.Data, s(1));
                        [varargout{1:nargout}] = subsref(obj, s(2:end));
                    end
                    return
            end
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end

        function obj = subsasgn(obj, s, varargin)
            if isequal(obj, [])
                obj = feval(class(varargin{1}));
            end
            s = checkIndexing(obj, s);
            switch s(1).type
                case '.'
                    if isprop(obj, s(1).subs)
                        if isscalar(s)
                            obj = builtin("subsasgn", obj, s, varargin{:});
                        else
                            obj1 = builtin("subsref", obj, s(1));
                            obj1 = subsasgn(obj1, s(2:end), varargin{:});
                            obj = builtin("subsasgn", obj, s(1), obj1);
                        end
                        return
                    end
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        obj1 = obj.Data;
                        obj1 = builtin("subsasgn", obj1, s, varargin{:});
                        obj.Data = obj1;
                        return
                    end
                    if ~isempty(obj.Data) && ...
                        (isfield(obj.Data(1, 1), s(1).subs) || isprop(obj.Data(1, 1), s(1).subs))
                        if isscalar(s)
                            obj1 = varargin{1};
                        else
                            obj1 = reshape(vertcat(obj.Data.(s(1).subs)), ...
                                size(obj.Data));
                            obj1 = builtin("subsasgn", obj1, s(2:end), varargin{:});
                        end
                        obj1 = num2cell(obj1);
                        [obj.Data.(s(1).subs)] = deal(obj1{:});
                        return
                    end
                case '()'
                    sd = s(1);
                    obj1 = varargin{1};
                    if isempty(obj1)
                        data = [];
                    else
                        data = obj1.Data;
                    end
                    obj.Data = subsasgn(obj.Data, sd, data);
                    [edn, sdim] = feval(class(obj)+".getExtraDataName");
                    for ii = 1:numel(edn)
                        name = edn(ii);
                        if name==""
                            continue
                        end
                        sd1 = sd;
                        sd1.subs(sdim{ii}) = {':'};
                        obj.(name) = subsasgn(obj.(name), sd1, obj1.(name));
                    end
                    dn = feval(class(obj)+".getDimNames");
                    for ii = 1:numel(dn)
                        name = dn(ii);
                        if name==""
                            continue
                        end
                        sd1 = sd;
                        sd1.subs = sd1.subs(ii);
                        n = extract(name, alphanumericsPattern);
                        for jj = 1:numel(n)
                            n1 = n(jj);
                            if isempty(obj1)
                                data = [];
                            else
                                data = obj1.(n1);
                            end
                            obj.(n1) = subsasgn(obj.(n1), sd1, data);
                        end
                    end
                    return
                case '{}'
                    s.type = '()';
                    obj1 = obj.Data;
                    obj1 = builtin("subsasgn", obj1, s, varargin{:});
                    obj.Data = obj1;
                    return
            end
            obj = builtin("subsasgn", obj, s, varargin{:});
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            % switch s(1).type
            %     case '{}'
            %         s(1).type = '()';
            % end
            if isscalar(s)
                if strcmp(s(1).type, '{}')
                    s(1).type = '()';
                end
                n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end

        % function n = numel(obj)
        %     %NUMEL Number of elements in the ArrayTable
        %     %
        %     %   n = numel(obj)

        %     n = prod(size(obj));
        % end

        function varargout = size(obj, varargin)
            if isempty(obj)
                varargout{1} = [0 0];
                return
            end
            [varargout{1:nargout}] = size(obj.Data, varargin{:});
            if obj.isScalarRow()
                % If the object is a scalar row, we return the size as a column vector
                if nargout<=1
                    if isempty(varargin)
                        varargout{1} = [varargout{1}(1) 1];
                    elseif isscalar(varargin)
                        idc = varargin{1}==2;
                        varargout{1}(idc) = 1;
                    else
                        idc = cell2mat(varargin)==2;
                        varargout{1}(idc) = 1;
                    end
                else
                    if isempty(varargin)
                        varargout{2} = 1;
                    elseif isscalar(varargin)
                        idc = varargin{1}==2;
                        varargout{idc} = 1;
                    else
                        idc = cell2mat(varargin)==2;
                        varargout{idc} = 1;
                    end
                end
            end
        end

        function b = isempty(obj)
            b = builtin("isempty", obj);
            if ~b
                b = isempty(obj.Data);
            end
        end

        function obj = cat(dim, varargin)
            n = numel(varargin);
            if n==0
                obj = feval(mfilename("class"));
                return
            end
            obj = varargin{1};
            if n==1
                return
            end
            c = class(obj);
            dn = feval(c+".getDimNames");
            for ii = 2:n
                assert(isa(varargin{ii}, c), "All inputs must be of the same class")
                assert(isequal(class(obj.Data), class(varargin{ii}.Data)), ...
                    "All inputs must have the same data type")
                switch dim
                    case 1
                        assert(isequal(size(obj.Data, 2), size(varargin{ii}.Data, 2)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data; varargin{ii}.Data];
                        if numel(dn)>0 && dn(1)~=""
                            n = extract(dn(1), alphanumericsPattern);
                            for jj = 1:numel(n)
                                n1 = n(jj);
                                obj.(n1) = [obj.(n1); varargin{ii}.(n1)];
                            end
                        end
                    case 2
                        assert(isequal(size(obj.Data, 1), size(varargin{ii}.Data, 1)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data varargin{ii}.Data];
                        if numel(dn)>1 && dn(2)~=""
                            n = extract(dn(2), alphanumericsPattern);
                            for jj = 1:numel(n)
                                n1 = n(jj);
                                obj.(n1) = [obj.(n1); varargin{ii}.(n1)];
                            end
                        end
                    case 3
                        assert(isequal(size(obj.Data, 1:2), size(varargin{ii}.Data, 1:2)), ...
                            "All inputs must have the same size")
                        obj.Data = cat(3, obj.Data, varargin{ii}.Data);
                        if numel(dn)>2 && dn(3)~=""
                            n = extract(dn(3), alphanumericsPattern);
                            for jj = 1:numel(n)
                                n1 = n(jj);
                                obj.(n1) = [obj.(n1); varargin{ii}.(n1)];
                            end
                        end
                    case 4
                        assert(isequal(size(obj.Data, 1:3), size(varargin{ii}.Data, 1:3)), ...
                            "All inputs must have the same size")
                        obj.Data = cat(4, obj.Data, varargin{ii}.Data);
                        if numel(dn)>3 && dn(4)~=""
                            n = extract(dn(4), alphanumericsPattern);
                            for jj = 1:numel(n)
                                n1 = n(jj);
                                obj.(n1) = [obj.(n1); varargin{ii}.(n1)];
                            end
                        end
                    otherwise
                        error("Invalid dimension")
                end
            end
        end

        function obj = horzcat(varargin)
            obj = cat(2, varargin{:});
        end

        function obj = vertcat(varargin)
            obj = cat(1, varargin{:});
        end

        function ind = end(obj,k,n)
            sz = size(obj);
            if k < n
                ind = sz(k);
            else
                ind = prod(sz(k:end));
            end
        end
    end
end