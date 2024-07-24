classdef Stimulus < spiky.core.Metadata & spiky.core.MappableArray

    properties
        Name string
        Type string
        Path string
        Subset double
    end

    methods
        function obj = Stimulus(name, type, path, subset)
            arguments
                name string = ""
                type string {mustBeMember(type, ["Image", "Video", "GameObject"])} = "Image"
                path string = ""
                subset double = 1
            end
            obj.Name = name;
            obj.Type = type;
            obj.Path = path;
            obj.Subset = subset;
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end