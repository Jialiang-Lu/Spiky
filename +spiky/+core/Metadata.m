classdef Metadata
    % Metadata

    methods (Static)
        function s = objToStruct(obj)
            s.Class = class(obj);
            if isenum(obj)
                s.Value = string(obj);
                return
            end
            s.Value = struct;
            m = metaclass(obj);
            props = {m.PropertyList.Name}';
            props = props(~[m.PropertyList.Dependent]);
            if ~isscalar(obj)
                c = cell(size(obj));
                for ii = 1:numel(obj)
                    s1 = spiky.core.Metadata.objToStruct(obj(ii));
                    c{ii} = s1.Value;
                end
                s.Value = cell2mat(c);
                return
            end
            for ii = 1:numel(props)
                propName = props{ii};
                if isobject(obj.(propName)) && startsWith(class(obj.(propName)), "spiky.")
                    s.Value.(propName) = spiky.core.Metadata.objToStruct(obj.(propName));
                else
                    s.Value.(propName) = obj.(propName);
                end
            end
        end

        function obj = structToObj(s)
            if ~isequal(fieldnames(s), {'Class'; 'Value'})
                error("Input struct must have 'Class' and 'Value' fields.")
            end
            n = length(s.Value);
            if n==0
                obj = feval(s.Class+".empty");
                return
            end
            enums = enumeration(s.Class);
            if ~isempty(enums)
                for ii = n:-1:1
                    obj(ii, 1) = feval(s.Class, s.Value(ii));
                end
                obj = reshape(obj, size(s.Value));
                return
            end
            props = intersect(fieldnames(s.Value), properties(s.Class));
            for ii = n:-1:1
                obj(ii, 1) = feval(s.Class);
                for jj = 1:numel(props)
                    propName = props{jj};
                    s1 = s.Value(ii).(propName);
                    if isstruct(s1) && isequal(fieldnames(s1), {'Class'; 'Value'})
                        obj(ii, 1).(propName) = spiky.core.Metadata.structToObj(s1);
                    else
                        obj(ii, 1).(propName) = s1;
                    end
                end
            end
            obj = reshape(obj, size(s.Value));
        end

        function obj = load(fpth)
            data = load(fpth, "data");
            obj = spiky.core.Metadata.structToObj(data.data);
        end
    end
    
    methods
        function s = toStruct(obj)
            s = spiky.core.Metadata.objToStruct(obj);
        end

        function save(obj, fpth)
            data = spiky.core.Metadata.objToStruct(obj);
            save(fpth, "data");
        end
    end
end