classdef Metadata
    % Metadata
    
    methods
        function obj = copyFrom(obj, objSource)
            if ~isscalar(obj)&&isscalar(objSource)
                objSource = repmat(objSource, size(obj));
            end
            if isscalar(obj)&&~isscalar(objSource)
                obj = repmat(obj, size(objSource));
            end
            if ~all(size(obj)==size(objSource))
                error("Input objects must have the same size.")
            end
            if ~isscalar(obj)
                for i = 1:numel(obj)
                    obj(i) = obj(i).copyFrom(objSource(i));
                end
                return
            end
            if isa(objSource, "spiky.core.Metadata")
                inputProps = properties(objSource);
                for i = 1:numel(inputProps)
                    propName = inputProps{i};
                    if isprop(obj, propName)
                        obj.(propName) = objSource.(propName);
                    end
                end
            end
        end
    end
end