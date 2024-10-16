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
            mc = metaclass(obj);
            props = {mc.PropertyList.Name}';
            props = props(~[mc.PropertyList.Dependent] & ...
                ~[mc.PropertyList.Abstract] & ...
                ~[mc.PropertyList.Transient]);
            if ~isa(obj, "spiky.core.TimeTable") && ~isscalar(obj)
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

        function [obj, updated] = structToObj(s)
            updated = false;
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
            mc = matlab.metadata.Class.fromName(s.Class);
            p = {mc.PropertyList(~[mc.PropertyList.Dependent] & ...
                ~[mc.PropertyList.Abstract] & ...
                ~[mc.PropertyList.Transient]).Name}';
            isDiff = ~isempty(setdiff(fieldnames(s.Value), p)) || ...
                ~isempty(setdiff(p, fieldnames(s.Value)));
            props = intersect(fieldnames(s.Value), p);
            if n==1
                obj = feval(s.Class);
                for ii = 1:numel(props)
                    propName = props{ii};
                    s1 = s.Value.(propName);
                    if isstruct(s1) && isequal(fieldnames(s1), {'Class'; 'Value'})
                        obj.(propName) = spiky.core.Metadata.structToObj(s1);
                    else
                        obj.(propName) = s1;
                    end
                end
                if isDiff && ismethod(obj(ii, 1), "updateFields")
                    updated = true;
                    obj = obj.updateFields(s.Value);
                end
                return
            end
            for ii = n:-1:1
                obj(ii, 1) = feval(s.Class);
                for jj = 1:numel(props)
                    propName = props{jj};
                    s1 = s.Value(ii).(propName);
                    if isstruct(s1) && isequal(fieldnames(s1), {'Class'; 'Value'})
                        if isempty(which(s1.Class))
                            isDiff = true;
                            continue
                        end
                        obj(ii, 1).(propName) = spiky.core.Metadata.structToObj(s1);
                    else
                        obj(ii, 1).(propName) = s1;
                    end
                end
                if isDiff && ismethod(obj(ii, 1), "updateFields")
                    updated = true;
                    obj(ii, 1) = obj(ii, 1).updateFields(s.Value(ii));
                end
            end
            obj = reshape(obj, size(s.Value));
        end

        function obj = load(fpth, saveIfUpdated)
            arguments
                fpth (1, 1) string
                saveIfUpdated (1, 1) logical = true
            end
            data = load(fpth, "data");
            [obj, updated] = spiky.core.Metadata.structToObj(data.data);
            if updated && saveIfUpdated
                obj.save(fpth);
            end
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