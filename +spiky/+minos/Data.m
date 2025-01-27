classdef Data

    properties (Constant, Hidden)
        LogPattern = "\[(?<timestamp>\d+)\] (?<name>[\w\.]+) \(?(?<type>.*?)\)? ?= (?<value>[^\r\n]*)";
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
        function obj = Data(fpth, memmapOnly, flattenVector)
            %DATA Create a new instance of Data
            %   
            %   fpth: path to file
            %   memmapOnly: load only memmapfile
            %   flattenVector: flatten vector2 and vector3 fields
            %
            %   obj: Data object
            arguments
                fpth string {mustBeFile} = []
                memmapOnly (1, 1) logical = false
                flattenVector (1, 1) logical = false
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
                    [fmt, info1, tbl] = ti.getFormat(flattenVector);
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
                            n = length(info1);
                            value = cell(1, n);
                            fid = fopen(fpth);
                            for ii = 1:n
                                fseek(fid, offset+tbl.Offset(ii), "bof");
                                wid = tbl.Size(ii, 2);
                                tmp = fread(fid, [wid len], sprintf("%d*%s=>%s", ...
                                    wid, tbl.Type(ii), tbl.Type(ii)), ...
                                    ti.Bytes-tbl.Bytes(ii))';
                                if info1(ii).Type=="logical"
                                    tmp = logical(tmp);
                                elseif info1(ii).Type=="char"
                                    tmp = cellfun(@(x) string(native2unicode(x)), num2cell(tmp, 2));
                                    tmp = strip(tmp, char(0));
                                end
                                if ~isempty(info1(ii).Constants)
                                    tmp = info1(ii).decode(tmp);
                                end
                                value{ii} = tmp;
                            end
                            value = table(value{:}, VariableNames=tbl.Name');
                            obj.Values = value;
                            fclose(fid);
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

        function save(obj, fpth, flattenVector)
            arguments
                obj spiky.minos.Data
                fpth string = string.empty
                flattenVector (1, 1) logical = false
            end
            if isempty(fpth)
                fpth = obj.Path;
            end
            switch obj.Type
                case "Binary"
                    header = [obj.Info.Str{1} newline];
                    offset = 2^nextpow2(length(header)+8);
                    padding = zeros(1, offset-length(header)-8);
                    header = [header padding];
                    [~, info1, tbl] = obj.Info.getFormat(flattenVector);
                    % tbl.Name = arrayfun(@(s) string([lower(s{1}(1)) s{1}(2:end)]), tbl.Name);
                    fid = fopen(fpth, "w");
                    fwrite(fid, [2 66 73 78 1 0 typecast(uint16(length(header)), "uint8")], "uint8");
                    fwrite(fid, header, "char");
                    nSamples = height(obj.Values);
                    nBytesPerSample = obj.Info.Bytes*obj.Info.Length;
                    data = zeros(nBytesPerSample, nSamples, "uint8");
                    for ii = 1:height(tbl)
                        value = typecast(info1(ii).encode(obj.Values.(tbl.Name{ii})), "uint8");
                        value = reshape(value, [], nSamples);
                        data(tbl.Offset(ii)+1:tbl.Offset(ii)+tbl.Bytes(ii), :) = value;
                    end
                    fwrite(fid, data, "uint8");
                    fclose(fid);
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

        function varargout = subsref(obj, s)
            switch s(1).type
                case '.'
                    if ismember(s(1).subs, obj.Values.Properties.VariableNames)
                        obj = obj.Values;
                    end
            end
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end

        function obj = subsasgn(obj, s, varargin)
            if isequal(obj, [])
                obj = spiky.core.TimeTable.empty;
            end
            switch s(1).type
                case '.'
                    if ismember(s(1).subs, obj.Values.Properties.VariableNames)
                        obj1 = obj.Values;
                        obj1 = builtin("subsasgn", obj1, s, varargin{:});
                        obj.Values = obj1;
                        return
                    end
            end
            obj = builtin("subsasgn", obj, s, varargin{:});
        end
    end
end