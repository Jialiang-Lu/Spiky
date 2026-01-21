classdef ObjArray < spiky.core.ArrayBase & matlab.mixin.CustomDisplay & ...
    matlab.mixin.CustomCompactDisplayProvider
    %OBJARRAY An homogeneous array of objects
    %   MATLAB doesn't internally support arrays of non-scalar objects. This class
    %   provides a workaround by storing the objects in cell array and accessing
    %   them like a struct array.

    properties
        Array cell
    end

    properties (Dependent)
        ElementClass string
    end

    methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = "Array";
        end
    end
    
    methods
        function obj = ObjArray(array, options)
            %OBJARRAY Create a new instance of ObjArray
            arguments
                array cell = {}
                options.Class string = string.empty
            end
            if isempty(array)
                return
            end
            if ~isempty(options.Class)
                cls = options.Class;
            else
                cls = class(array{1});
            end
            assert(all(cellfun(@(x) isa(x, cls), array), "all"), ...
                "All elements in the array must be of class '%s'.", cls);
            obj = obj.setData(array);
        end

        function rep = compactRepresentationForSingleLine(obj, displayConfiguration, width)
            rep = matlab.display.DimensionsAndClassNameRepresentation(obj, displayConfiguration, ...
                UseSimpleName=true, ClassName=sprintf("%s (%s)", class(obj), obj.ElementClass));
        end

        function rep = compactRepresentationForColumn(obj, displayConfiguration, width)
            rep = matlab.display.DimensionsAndClassNameRepresentation(obj, displayConfiguration, ...
                UseSimpleName=true, ClassName=sprintf("%s (%s)", class(obj), obj.ElementClass));
        end

        function cls = get.ElementClass(obj)
            %GET.ELEMENTCLASS Get the class name of the elements in the ObjArray
            %
            %   cls: class name of the elements
            arguments (Output)
                cls (1, 1) string
            end
            data = obj.getData();
            if isempty(data)
                cls = "";
            else
                cls = class(data{1});
            end
        end
    end

    methods (Access = protected)
        function s = processSubstruct(obj, s)
            if ~strcmp(s(1).type, '.') || obj.isProperty(s(1).subs) || obj.isMethod(s(1).subs)
                return
            end
            s1 = substruct('{}', {':'});
            s = [s1 s];
        end
        
        function s = getHeader(obj)
            s = getHeader@matlab.mixin.CustomDisplay(obj);
            idx = strfind(s, '</a>');
            s = sprintf('%s (%s)%s', s(1:idx-1), obj.ElementClass, s(idx:end));
        end

        function names = getVarNames(obj)
            %GETVARNAMES Get variable names of the Data table, if applicable.
            if isempty(obj.Array) || isempty(obj.Array{1})
                names = string.empty;
                return
            end
            data = obj.Array{1};
            if istable(data)
                names = string(data.Properties.VariableNames);
            elseif isa(data, "spiky.core.ArrayBase")
                names = data.getVarNames();
            else
                names = string.empty;
            end
        end
    end
end