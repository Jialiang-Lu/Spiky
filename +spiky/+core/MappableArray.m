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
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end

        function n = numArgumentsFromSubscript(obj, s, indexingContext)
            if strcmp(s(1).type, '.')
                useKey = strcmp(s(1).subs, [obj.Key]);
                if any(useKey)
                    n = 1;
                    return
                end
            end
            n = builtin("numArgumentsFromSubscript", obj, s, indexingContext);
        end
    end

    methods (Abstract, Access = protected)
        key = getKey(obj)
    end
end