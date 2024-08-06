classdef ArrayDisplay

    methods
        function s = struct(obj)
            props = properties(obj);
            s(numel(obj)) = struct;
            for ii = 1:numel(props)
                [s.(props{ii})] = obj.(props{ii});
            end
        end

        function openvar(varargin)
            if isa(varargin{1}, "spiky.core.ArrayDisplay")
                s = inputname(1);
                openvar([s '.struct']);
            elseif isa(varargin{1}, "char") || isa(varargin{1}, "string")
                openvar([varargin{1} '.struct']);
            else
                error("Invalid input type %s.", class(varargin{1}))
            end
        end
    end
end