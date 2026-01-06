classdef (Abstract) MappableArray < spiky.core.ArrayBase
    %MAPABLEARRAY Class for arrays that can be referenced by key

    properties (Access=protected, Dependent)
        Key_ string
    end

    methods
        function key = get.Key_(obj)
            key = obj.getKey();
        end
    end

    methods (Access=protected)
        function s = processSubstruct(obj, s)
            if isempty(obj)
                return
            end
            subs1 = s(1).subs;
            switch s(1).type
                case {'()', '{}'}
                    if ~isstring(subs1{1}) && ~iscellstr(subs1{1})
                        return
                    end
                    idc = ismember(obj.Key_, subs1{1});
                    s(1).subs{1} = idc;
                case '.'
                    if isprop(obj, subs1) || ismethod(obj, subs1) || ...
                        (obj.IsTable && ismember(subs1, obj.Data.Properties.VariableNames))
                        return
                    end
                    idc = obj.Key_==subs1;
                    s(1).type = '()';
                    s(1).subs = {idc, ':', ':', ':', ':', ':'};
            end
        end
    end

    methods (Abstract, Access=protected)
        key = getKey(obj)
    end
end