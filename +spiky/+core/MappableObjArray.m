classdef MappableObjArray < spiky.core.ObjArray & spiky.core.MappableArray
    %MAPABLEOBJARRAY Class for ObjArrays that can be referenced by key

    methods
        function obj = MappableObjArray(array, options)
            %MAPABLEOBJARRAY Constructor for MappableObjArray class.
            arguments
                array cell = {}
                options.Class string = string.empty
            end
            optionsCell = namedargs2cell(options);
            obj@spiky.core.ObjArray(array, optionsCell{:});
        end
    end

    methods (Access=protected)
        function s = processSubstruct(obj, s)
            s = processSubstruct@spiky.core.MappableArray(obj, s);
            s = processSubstruct@spiky.core.ObjArray(obj, s);
        end
    end
end