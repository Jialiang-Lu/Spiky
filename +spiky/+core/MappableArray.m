classdef (Abstract) MappableArray
    % MAPABLEARRAY Class for arrays that can be referenced by key

    properties (Access = protected, Dependent)
        Key string
    end

    methods
        function key = get.Key(obj)
            key = obj.getKey();
        end
        
        function varargout = subsref(obj, s)
            s(1) = obj.useKey(s(1));
            if isscalar(s)
                [varargout{1:nargout}] = builtin("subsref", obj, s);
            elseif strcmp(s(1).type, '.') && ismember(s(1).subs, methods(obj))
                [varargout{1:nargout}] = builtin("subsref", obj, s);
            else
                obj1 = builtin("subsref", obj, s(1));
                [varargout{1:nargout}] = subsref(obj1, s(2:end));
            end
        end

        function obj = subsasgn(obj, s, varargin)
            if isempty(obj) && all(cellfun(@isempty, varargin))
                return
            end
            if isempty(obj)
                obj = feval(str2func(class(varargin{1})+".empty"));
            end
            s(1) = obj.useKey(s(1));
            if isscalar(s)
                obj = builtin("subsasgn", obj, s, varargin{:});
            else
                obj1 = builtin("subsref", obj, s(1));
                obj1 = subsasgn(obj1, s(2:end), varargin{:});
                obj = builtin("subsasgn", obj, s(1), obj1);
            end
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            [s(1), use] = obj.useKey(s(1));
            if isscalar(s)
                if use
                    n = 1;
                else
                    n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
                end
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end
    end

    methods (Access = protected)
        function [s, use] = useKey(obj, s)
            use = false;
            switch s(1).type
                case {'()', '{}'}
                    is = cellfun(@isstring, s(1).subs);
                    if any(is)
                        keys = [s(1).subs{is}];
                        s.subs = {ismember([obj.Key], keys)};
                        use = true;
                    end
                case '.'
                    is = s(1).subs==[obj.Key];
                    if any(is)
                        s.type = '()';
                        s.subs = {is};
                        use = true;
                    end
            end
            if use && size(obj, 2)>1
                s(1).subs = {s(1).subs{1}, ':'};
            end
        end
    end

    methods (Abstract, Access = protected)
        key = getKey(obj)
    end
end