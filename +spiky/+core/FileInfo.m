classdef FileInfo
    % FileInfo represents a file or folder in the file system.

    properties (SetAccess = protected)
        Name string
        Folder string
        Path string
        Date datetime
        Bytes double
        IsDir logical
    end

    methods
        function obj = FileInfo(name)
            % FileInfo creates a new instance of FileInfo.
            % 
            %   name: name of the query, may contain wildcards

            arguments
                name string = ""
            end

            if name == ""
                return
            end
            fi = dir(name);
            if isempty(fi)
                obj = spiky.core.FileInfo;
                return
            end
            fi(strcmp({fi.name}', ".")) = [];
            fi(strcmp({fi.name}', "..")) = [];
            [~, ids] = spiky.utils.natsortfiles.natsortfiles({fi.name}');
            fi = fi(ids);
            n = length(fi);
            for ii = n:-1:1
                obj(ii, 1).Name = string(fi(ii).name);
                obj(ii, 1).Folder = string(fi(ii).folder);
                obj(ii, 1).Path = obj(ii).Folder + filesep + obj(ii).Name;
                obj(ii, 1).Date = datetime(fi(ii).datenum, "ConvertFrom", "datenum");
                obj(ii, 1).Bytes = fi(ii).bytes;
                obj(ii, 1).IsDir = fi(ii).isdir;
            end
        end
    end
end