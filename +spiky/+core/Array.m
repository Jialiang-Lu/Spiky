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
            obj.Data = data;
        end
        
        function obj = sel(obj, idcRow, idcCol)
            %SEL Select a subset of the table data based on row and column indices.
            arguments
                obj spiky.core.Array
                idcRow
                idcCol
            end
            if isstring(idcRow) && isequal(idcRow, ":")
                idcRow = ':';
            end
            if isstring(idcCol) && isequal(idcCol, ":")
                idcCol = ':';
            end
            assert(istable(obj.Data), "Data must be a table to use sel method.");
            obj = subsref(obj, substruct("()", {idcRow, ':'}));
            obj.Data = obj.Data(:, idcCol);
        end
    end
end