classdef Asset < spiky.core.MappableArray & spiky.core.Array
    %ASSET Unity asset file
    %
    %   Fields:
    %       Name: name
    %       Path: path
    %       Guid: unique identifier
    %       IsDir: whether it is a directory

    methods
        function obj = Asset(name, path, guid, isDir)
            arguments
                name (:, 1) string = ""
                path (:, 1) string = ""
                guid (:, 1) string = ""
                isDir (:, 1) logical = false
            end
            obj = obj.initTable(Name=name, Path=path, Guid=guid, IsDir=isDir);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Guid;
        end
    end
end