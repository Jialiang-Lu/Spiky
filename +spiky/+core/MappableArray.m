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
            switch s(1).type
                case '()'
                    useKey = cellfun(@isstring, s(1).subs);
                    if any(useKey)
                        keys = [s(1).subs{useKey}];
                        s(1).subs = {ismember([obj.Key], keys)'};
                    end
                case '.'
                    useKey = strcmp(s(1).subs, [obj.Key]);
                    if any(useKey)
                        s(1).type = '()';
                        s(1).subs = {useKey};
                    end
            end
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
            switch s(1).type
                case '()'
                    useKey = cellfun(@isstring, s(1).subs);
                    if any(useKey)
                        keys = [s(1).subs{useKey}];
                        s(1).subs = {ismember([obj.Key], keys)'};
                    end
                case '.'
                    useKey = strcmp(s(1).subs, [obj.Key]);
                    if any(useKey)
                        s(1).type = '()';
                        s(1).subs = {useKey};
                    end
            end
            if isscalar(s)
                obj = builtin("subsasgn", obj, s, varargin{:});
            else
                obj1 = builtin("subsref", obj, s(1));
                obj1 = subsasgn(obj1, s(2:end), varargin{:});
                obj = builtin("subsasgn", obj, s(1), obj1);
            end
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            if ismember(s(1).type, {'.', '()'})
                if strcmp(s(1).type, '.')
                    useKey = strcmp(s(1).subs, [obj.Key]);
                else
                    useKey = cellfun(@isstring, s(1).subs);
                end
                if any(useKey)
                    if isscalar(s)
                        n = 1;
                    else
                        obj = subsref(obj, s(1));
                        n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
                    end
                    return
                end
            end
            if isscalar(s)
                n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
            else
                obj = subsref(obj, s(1));
                n = numArgumentsFromSubscript(obj, s(2:end), indexingContext);
            end
        end
    end

    methods (Abstract, Access = protected)
        key = getKey(obj)
    end
end