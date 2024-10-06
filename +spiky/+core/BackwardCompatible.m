classdef BackwardCompatible

    methods (Abstract)
        obj = updateFields(obj, s) % Update fields of the object from a struct of older version
    end
end