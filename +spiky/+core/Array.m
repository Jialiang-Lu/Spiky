classdef Array < spiky.core.ArrayBase
    %ARRAY class for array-like data structures with dimension labels.

    properties
        Data
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
            dataNames = "Data";
        end
    end

    methods
        function obj = Array(data)
            %ARRAY Constructor for Array class.
            arguments
                data = []
            end
            obj = obj.setData(data);
        end
    end
end