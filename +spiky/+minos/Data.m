classdef Data

    properties (Constant, Hidden)
        LogPattern = "\[(?<timestamp>\d+)\] (?<name>[\w\.]+) \(?(?<type>.*?)\)? ?= (?<value>[^\r\n]+)";
        MessagePattern = "\[(?<timestamp>\d+)\] (?<message>[^\r\n]+)";
        NetNumbers = ["System.SByte" "System.Byte" "System.Int16" "System.UInt16" ...
            "System.Int32" "System.UInt32" "System.Int64" "System.UInt64" ...
            "System.Single" "System.Double"];
    end

    properties
        Path string
        Type {mustBeMember(Type, ["Binary", "Log"])} = "Binary"
        Values table
        Info spiky.minos.TypeInfo
        Map
    end

    methods (Static)
        function out = str2array(str, func)
            % STR2ARRAY Convert a string to an array
            %
            %   str: string
            %   func: function to convert the elements
            %
            %   out: array

            arguments
                str string
                func = @double
            end
            out = arrayfun((@(s) func(strsplit(s, ","))), str, "UniformOutput", false);
        end

        function func = getConvertFunc(type)
            % GETCONVERTFUNC Get the conversion function for a type
            %
            %   type: type

            arguments
                type string
            end

            func = @(x) x;
            if endsWith(type, "[]")
                func = @(s) spiky.minos.Data.str2array(s, ...
                    spiky.minos.Data.getConvertFunc(extractBefore(type, "[]")));
                return
            end
            if ismember(type, spiky.minos.Data.NetNumbers)
                func = @double;
            elseif type=="System.Boolean"
                func = @(s) s=="True";
            elseif type=="UnityEngine.Color"
                func = @(s) cell2mat(arrayfun(@(s1) sscanf(s1, ...
                    "RGBA(%f, %f, %f, %f)")', s, UniformOutput=false));
            end
        end
    end

    methods
        function obj = Data(fpth, memmapOnly)
            %DATA Create a new instance of Data
            %   
            %   fpth: path to file
            %   memmapOnly: load only memmapfile
            %
            %   obj: Data object
            arguments
                fpth string {mustBeFile} = []
                memmapOnly (1, 1) logical = false
            end
            obj.Path = fpth;
            if isempty(fpth)
                return
            end
            fi = spiky.core.FileInfo(fpth);
            [~, ~, fext] = fileparts(fpth);
            if fext==".bin"
                obj.Type = "Binary";
                fid = fopen(fpth, "r");
                s = fread(fid, 8, "uint8=>uint8")';
                fclose(fid);
                ver = s([5 6]);
                headerLength = typecast(s([7 8]), "uint16");
                offset = double(headerLength+8);
                if all(ver==[1 0])
                    fid = fopen(fpth);
                    fseek(fid, 8, "bof");
                    header = string(fread(fid, headerLength, "char*1=>char")');
                    fclose(fid);
                    ti = spiky.minos.TypeInfo(header);
                    len = (fi.Bytes-offset)/double(ti.Bytes);
                    if abs(len-round(len))>eps
                        error("Number of entries is not an integer")
                    end
                    [fmt, info1] = ti.getFormat();
                    obj.Info = ti;
                    if len==0
                        if memmapOnly
                        else
                            value = table(Size=[0, length(info1)], VariableTypes=[fmt{:, 1}], ...
                                VariableNames=[fmt{:, 3}]);
                            obj.Values = value;
                        end
                    else
                        if ~memmapOnly
                            chunkSize = 2^20;
                            if len>chunkSize
                                nChunks = ceil(len/chunkSize);
                                value = cell(nChunks, 1);
                                spiky.plot.timedWaitbar(0, sprintf("Loading %s", fi.Name));
                                for ii = 1:nChunks
                                    m = memmapfile(fpth, Offset=offset, Format=fmt, ...
                                        Writable=false);
                                    idc = (ii-1)*chunkSize+1:min(ii*chunkSize, len);
                                    value{ii} = struct2table(m.Data(idc), AsArray=true);
                                    clear m
                                    spiky.plot.timedWaitbar(ii/nChunks);
                                end
                                value = vertcat(value{:});
                            else
                                m = memmapfile(fpth, Offset=offset, Format=fmt, ...
                                    Writable=false);
                                value = struct2table(m.Data, AsArray=true);
                            end
                            n = length(info1);
                            for ii = 1:n
                                if info1(ii).Type=="logical"
                                    value.(info1(ii).Name) = logical(value.(info1(ii).Name));
                                end
                                if ~isempty(info1(ii).Constants)
                                    value.(info1(ii).Name) = info1(ii).decode(value.(info1(ii).Name));
                                end
                            end
                            obj.Values = value;
                        else
                            m = memmapfile(fpth, Offset=offset, Format=fmt, ...
                                Writable=true);
                            obj.Map = m;
                        end
                    end
                else
                    error("Unsupported version %d.%d", ver(1), ver(2))
                end
            elseif fext==".txt"
                obj.Type = "Log";
                txt = string(fileread(fpth));
                txt = split(txt, newline);
                txt(txt=="") = [];
                n = length(txt);
                value = table(strings(n, 1), strings(n, 1), strings(n, 1), strings(n, 1), ...
                    VariableNames=["Timestamp", "Name", "Type", "Value"]);
                tokens = regexp(txt, spiky.minos.Data.LogPattern, "names");
                isLog = ~cellfun(@isempty, tokens);
                tokens = struct2table(cell2mat(tokens), AsArray=true);
                value(isLog, :) = tokens;
                if any(~isLog)
                    tokens = regexp(txt(~isLog), spiky.minos.Data.MessagePattern, "names");
                    tokens = struct2table(cell2mat(tokens), AsArray=true);
                    value.Timestamp(~isLog) = tokens.timestamp;
                    value.Value(~isLog) = tokens.message;
                end
                value.Timestamp = spiky.utils.str2int(value.Timestamp, "int64");
                value.Name = strrep(value.Name, ".", "");
                obj.Values = value;
            else
                error("Unsupported file extension %s", fext)
            end
        end

        function save(obj)
            switch obj.Type
                case "Binary"
                    error("Not implemented")
                case "Log"
                    txt = string.empty;
                    n = height(obj.Values);
                    for ii = 1:n
                        if obj.Values.type(ii)==""
                            txt = [txt; sprintf("[%d] %s", obj.Values.Timestamp(ii), obj.Values.value(ii))];
                        else
                            txt = [txt; sprintf("[%d] %s (%s) = %s", obj.Values.Timestamp(ii), obj.Values.name(ii), ...
                                obj.Values.type(ii), obj.Values.value(ii))];
                        end
                    end
                    txt = join(txt, newline)+newline;
                    fid = fopen(obj.Path, "w");
                    fwrite(fid, txt);
                    fclose(fid);
                otherwise
                    error("Unsupported type %s", obj.Type)
            end
        end

        function out = getParameters(obj, func)
            % GETPARAMETERS Get parameters from the data
            %
            %   obj: Data object
            %   func: function to transform the time
            %
            %   out: parameters

            arguments
                obj spiky.minos.Data
                func = []
            end

            values = obj.Values(obj.Values.Name~="", :);
            ts = double(values.Timestamp)/1e7;
            [names, ~, idcName] = unique(values.Name, "stable");
            for ii = length(names):-1:1
                idc = idcName==ii;
                time = ts(idc);
                type = values.Type(find(idc, 1));
                value = values.Value(idc);
                convert = spiky.minos.Data.getConvertFunc(type);
                value = convert(value);
                out(ii, 1) = spiky.core.Parameter(names(ii), type, time, value);
            end
            if ~isempty(func)
                out = out.syncTime(func);
            end
        end
    end
end