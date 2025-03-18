classdef (Abstract) ArrayTable

    properties
        Data
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

        function S = sum(obj, varargin)
            %SUM Compute the sum of the signal
            %
            %   S = sum(obj, varargin)
            %   varargin: additional arguments passed to sum

            S = sum(obj.Data, varargin{:});
        end

        function M = mean(obj, varargin)
            %MEAN Compute the mean of the signal
            %
            %   M = mean(obj, varargin)
            %   varargin: additional arguments passed to mean

            M = mean(obj.Data, varargin{:});
        end

        function M = median(obj, varargin)
            %MEDIAN Compute the median of the signal
            %
            %   M = median(obj, varargin)
            %   varargin: additional arguments passed to median

            M = median(obj.Data, varargin{:});
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

        function varargout = subsref(obj, s)
            if isempty(obj)
                [varargout{1:nargout}] = builtin("subsref", obj, s);
                return
            end
            switch s(1).type
                case '.'
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        obj = obj.Data;
                    end
                case '()'
                    sd = s(1);
                    if isscalar(sd.subs)
                        sd.subs{2} = ':';
                    end
                    obj.Data = subsref(obj.Data, sd);
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
                obj = feval(mfilename("class"));
            end
            switch s(1).type
                case '.'
                    if istable(obj.Data) && ismember(s(1).subs, ...
                        obj.Data.Properties.VariableNames)
                        obj1 = obj.Data;
                        obj1 = builtin("subsasgn", obj1, s, varargin{:});
                        obj.Data = obj1;
                        return
                    end
                case '()'
                    sd = s(1);
                    obj1 = varargin{1};
                    obj.Data = subsasgn(obj.Data, sd, obj1.Data);
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
            switch s(1).type
                case '{}'
                    s(1).type = '()';
            end
            if isscalar(s)
                n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end

        function varargout = size(obj, varargin)
            if isempty(obj)
                varargout{1} = [0 0];
            end
            [varargout{1:nargout}] = size(obj.Data, varargin{:});
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
            for ii = 2:n
                assert(isa(varargin{ii}, c), "All inputs must be of the same class")
                assert(isequal(class(obj.Data), class(varargin{ii}.Data)), ...
                    "All inputs must have the same data type")
                switch dim
                    case 1
                        assert(isequal(size(obj.Data, 2), size(varargin{ii}.Data, 2)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data; varargin{ii}.Data];
                    case 2
                        assert(isequal(size(obj.Data, 1), size(varargin{ii}.Data, 1)), ...
                            "All inputs must have the same size")
                        obj.Data = [obj.Data varargin{ii}.Data];
                    case 3
                        assert(isequal(size(obj.Data, 1:2), size(varargin{ii}.Data, 1:2)), ...
                            "All inputs must have the same size")
                        obj.Data = cat(3, obj.Data, varargin{ii}.Data);
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