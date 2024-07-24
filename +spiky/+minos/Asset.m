classdef Asset < spiky.core.Metadata & spiky.core.MappableArray
    % ASSET Unity asset file

    properties
        Name string
        Path string
        Guid string
        IsDir logical
    end

    methods
        function obj = Asset(name, path, guid, isDir)
            arguments
                name string = ""
                path string = ""
                guid string = ""
                isDir logical = false
            end
            obj.Name = name;
            obj.Path = path;
            obj.Guid = guid;
            obj.IsDir = isDir;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Guid;
        end
    end
end