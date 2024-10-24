classdef TypeInfo
    %TYPEINFO Info for (de-)serializing Minos struct

    properties (Constant, Hidden)
        BuiltIns = dictionary(["logical", "char", "int8", "uint8", "int16", "uint16", ...
            "int32", "uint32", "int64", "uint64", "single", "double"],...
            ["b4", "c1", "i1", "u1", "i2", "u2", "i4", "u4", "i8", "u8", "f4", "f8"])
        BasePattern = "(?<name>[a-zA-Z_][a-zA-Z0-9_]*)?:?(?<comment>\^?)"+...
            "(?<length>\d+)(?<descr>[buicfd\^]+)(?<bytes>\d+)";
        CommentPattern = "(?<name>[a-zA-Z_][a-zA-Z0-9_]*):?(?<value>[-\d]+)?";
        VectorFields = ["(x,y)2f4" "(x,y,z)3f4"]
    end

    properties %(SetAccess = private)
        Name string
        EnumType string {mustBeMember(EnumType, ["None", "Enum", "Flag", "EnumLike"])} = "None"
        Constants table {mustBeTableOfConstants(Constants)} = ...
            table(Size=[0, 2], VariableTypes=["string", "int32"], ...
            VariableNames=["name", "value"])
        Length int32 {mustBePositive}
        Type string = ""
        Bytes int32 {mustBeNonnegative}
        Children spiky.minos.TypeInfo
        Str string
    end

    properties (Hidden)
        Name_ string
    end
    
    methods (Static)
        function tokens = createTokens(str)
            % Convert string rep to token list
            n = strlength(str);
            rep = table(Size=[n, 3], VariableTypes=["int32", "int32", "string"], ...
                VariableNames=["index", "level", "c"]);
            level = 1;
            maxLevel = 1;
            for k = 1:n
                c = string(str{1}(k));
                rep.index(k) = k;
                switch c
                    case "("
                        rep.level(k) = level;
                        rep.c(k) = "^";
                        level = level+1;
                        if level>maxLevel
                            maxLevel = level;
                        end
                    case ")"
                        rep.level(k) = level;
                        rep.c(k) = "$";
                        level = level-1;
                    otherwise
                        rep.level(k) = level;
                        rep.c(k) = c;
                end
            end
            tokens = cell(maxLevel, 1);
            for k = 1:maxLevel
                tokens{k} = rep(rep.level==k, :);
            end
        end

        function obj = parse(tokens, level, start, len)
            % Parse string rep
            arguments (Input)
                tokens cell
                level (1, 1) {mustBePositive} = 1
                start (1, 1) {mustBePositive} = 1
                len (1, 1) {mustBePositive} = Inf
            end
            if isinf(len)
                len = height(tokens{level});
            end
            thisLevel = tokens{level}(start:start+len-1, :);
            s = join(thisLevel.c, "");
            [m, extents] = regexp(s, spiky.minos.TypeInfo.BasePattern, "names", "tokenExtents");
            if isempty(m)
                error("Invalid type specification %s", s)
            end
            extents = extents{1};
            obj = spiky.minos.TypeInfo;
            if m.name~=""
                obj.Name_ = m.name;
                obj.Name = string([upper(m.name{1}(1)) spiky.utils.ternary(strlength(m.name)>1, m.name{1}(2:end), '')]);
            else
                obj.Name_ = "";
                obj.Name = "";
            end
            obj.Length = spiky.utils.str2int(m.length, "int32");
            obj.Bytes = spiky.utils.str2int(m.bytes, "int32");
            names = "";
            if strcmp(m.comment, "^")
                index = thisLevel.index(extents(2, 1))+1;
                nextIndex = find(tokens{level+1}.index==index, 1);
                count = find(tokens{level+1}.c(nextIndex:end)=="$", 1)-1;
                comment = join(tokens{level+1}.c(nextIndex:nextIndex+count-1), "");
                cs = regexp(comment, spiky.minos.TypeInfo.CommentPattern, "names");
                if isempty(cs)
                    error("Invalid comment %s", comment)
                end
                if cs(1).value==""
                    names = [cs.name]';
                else
                    id = m.descr+m.bytes;
                    obj.Type = string(spiky.minos.TypeInfo.BuiltIns.keys{strcmp(id, ...
                        spiky.minos.TypeInfo.BuiltIns.values)});
                    obj.Constants = table([cs.name]', spiky.utils.str2int([cs.value]', obj.Type), ...
                        VariableNames=["name", "value"]);
                    obj.EnumType = spiky.utils.ternary(obj.Constants.value(1)~=0, "EnumLike", "Enum");
                end
                if comment{1}(1)=='^'
                    obj.EnumType = "Flag";
                end
            end
            if ~strcmp(m.descr, "^")
                id = m.descr+m.bytes;
                obj.Type = string(spiky.minos.TypeInfo.BuiltIns.keys{strcmp(id, spiky.minos.TypeInfo.BuiltIns.values)});
                if names~=""
                    if obj.Length~=length(names)
                        error("Comment %s doesn't match field length %d", comment, obj.Length)
                    end
                    ti1 = obj;
                    ti1.Length = 1;
                    for k = 1:obj.Length
                        ti1.Name = names(k);
                        ti1.Name_ = names(k);
                        ti1 = updateString(ti1);
                        obj.Children(k, 1) = ti1;
                    end
                    obj.Length = 1;
                    obj.Type = "";
                    obj.Bytes = obj.Bytes*length(names);
                end
            else
                children = spiky.minos.TypeInfo;
                index = thisLevel.index(extents(4, 1))+1;
                nextIndex = sum(tokens{level+1}.index<=index);
                k = 1;
                while true
                    count = find(ismember(tokens{level+1}.c(nextIndex:end), ["$", ","]), 1)-1;
                    children(k, 1) = spiky.minos.TypeInfo.parse(tokens, level+1, nextIndex, count);
                    children(k, 1) = children(k, 1).updateString();
                    k = k+1;
                    nextIndex = nextIndex+count;
                    if tokens{level+1}.c(nextIndex)=="$"
                        break
                    end
                    nextIndex = nextIndex+1;
                end
                if names~=""
                    if length(children)~=1
                        error("Invalid comment %s", comment);
                    end
                    ti1 = children(1);
                    ti1.Length = 1;
                    for k = 1:length(names)
                        ti1.Name = names(k);
                        ti1.Name_ = names(k);
                        ti1 = updateString(ti1);
                        children(k, 1) = ti1;
                    end
                end
                obj.Children = children;
            end
            obj = obj.updateString();
        end
    end

    methods
        function obj = TypeInfo(varargin)
            % Constructor
            %   obj = TypeInfo(str);
            %   obj = TypeInfo(str, name);
            %   obj = TypeInfo(typeInfo, multiplier);
            if isempty(varargin)
                return
            end
            if isscalar(varargin) && (ischar(varargin{1}) || isStringScalar(varargin{1}))
                obj = spiky.minos.TypeInfo.parse(spiky.minos.TypeInfo.createTokens(varargin{1}));
            elseif length(varargin)==2 && (ischar(varargin{1}) || isStringScalar(varargin{1})) ... 
                    && (ischar(varargin{2}) || isStringScalar(varargin{2}))
                obj = spiky.minos.TypeInfo.parse(spiky.minos.TypeInfo.createTokens(varargin{1}));
                obj.Name = varargin{2};
            elseif length(varargin)==2 && isa(varargin{1}, "spiky.minos.TypeInfo") && isnumeric(varargin{2})
                typeInfo = varargin{1};
                multiplier = varargin{2};
                obj.Length = multiplier;
                obj.Bytes = typeInfo.Bytes;
                if isempty(typeInfo.Children) || isscalar(typeInfo.Children)
                    obj.EnumType = typeInfo.EnumType;
                    obj.Constants = typeInfo.Constants;
                    obj.Type = typeInfo.Type;
                    obj.Children = typeInfo.Children;
                else
                    obj.Children = typeInfo;
                end
                obj = updateString(obj);
            end
        end
        
        function obj = updateString(obj)
            % To string
            switch obj.EnumType
                case "None"
                    if isempty(obj.Children) % built-in type or its array
                        obj.Str = sprintf("%d%s", obj.Length, obj.BuiltIns(obj.Type));
                    elseif length(obj.Children)>1 % struct
                        if isscalar(unique([obj.Children.Str]))
                            obj.Str = sprintf("(%s)%s", ...
                                join([obj.Children.Name_], ","), ...
                                spiky.minos.TypeInfo(obj.Children(1), length(obj.Children)).Str);
                        else
                            obj.Str = sprintf("1(%s)%d", ...
                                selectJoin(@(x) spiky.utils.ternary(x.Name_=="", "", x.Name_+":")+x.Str, ...
                                obj.Children, ","), obj.Bytes);
                        end
                    else % struct array
                        obj.Str = sprintf("%d(%s)%d", obj.Length, obj.Children(1).Str, obj.Bytes);
                    end
                case "Enum" % enum
                    obj.Str = sprintf("(%s)%d%s", constants2str(obj.Constants), obj.Length, ...
                        obj.BuiltIns(obj.Type));
                case "Flag" % flags
                    obj.Str = sprintf("((flags)%s)%d%s", constants2str(obj.Constants), obj.Length, ...
                        obj.BuiltIns(obj.Type));
                case "EnumLike" % enum-like
                    obj.Str = sprintf("(%s)%di4", constants2str(obj.Constants), obj.Length);
            end
        end
        
        function n = childrenCountAll(obj)
            if isempty(obj.Children)
                n = 1;
            else
                n = 0;
                for k = 1:length(obj.Children)
                    n = n+obj.Children(k).childrenCountAll();
                end
            end
        end

        function objs = flatten(obj, flattenVector)
            arguments
                obj spiky.minos.TypeInfo
                flattenVector logical = false
            end
            if ~flattenVector && ismember(obj.Str, spiky.minos.TypeInfo.VectorFields)
                n = length(obj.Children);
                obj.Type = obj.Children(1).Type;
                obj.Bytes = obj.Children(1).Bytes;
                obj.Length = n;
                obj.Children = spiky.minos.TypeInfo.empty;
                objs = obj;
                return
            end
            if isempty(obj.Children)
                objs = obj;
            else
                n = length(obj.Children);
                c = cell(n, 1);
                for k = 1:n
                    c{k} = obj.Children(k).flatten(flattenVector);
                end
                objs = vertcat(c{:});
                % prefix = ternary(isempty(obj.Name), "", [obj.Name "_"]);
                isTop = obj.Name=="";
                for k = 1:length(objs)
                    if objs(k).Name==""
                        name = "_";
                    elseif ~isTop && strlength(objs(k).Name)==1
                        name = obj.Name+upper(objs(k).Name);
                    elseif ~isTop
                        name = obj.Name+upper(objs(k).Name{1}(1))+objs(k).Name{1}(2:end);
                    else
                        name = objs(k).Name;
                    end
                    objs(k).Name = name;
                end
            end
        end

        function [fmt, objs, tbl] = getFormat(obj, flattenVector)
            arguments
                obj spiky.minos.TypeInfo
                flattenVector logical = false
            end
            objs = obj.flatten(flattenVector);
            n = length(objs);
            fmt = cell(n, 3);
            for k = 1:n
                t = objs(k).Type;
                if strcmp(t, "logical")
                    t = "int32";
                elseif strcmp(t, "char")
                    t = "uint8";
                end
                fmt{k, 1} = t;
                fmt{k, 2} = double([1 objs(k).Length]);
                fmt{k, 3} = objs(k).Name;
            end
            tbl = cell2table(fmt, VariableNames=["Type", "Size", "Name"]);
            tbl.Bytes = [objs.Bytes]'.*[objs.Length]';
            tbl.Offset = cumsum([0; tbl.Bytes(1:end-1)]);
        end

        function out = decode(obj, values)
            %DECODE Decode values
            %
            %   out = decode(obj, values)
            %
            %   obj: spiky.minos.TypeInfo
            %   values: array

            arguments
                obj spiky.minos.TypeInfo
                values
            end
            sz = size(values);
            n = numel(values);
            values = values(:);
            if obj.EnumType=="Flag"
                out = strings(sz);
                isCode = bitand(values', obj.Constants.value)>0;
                for ii = 1:n
                    out(ii) = join(obj.Constants.name(isCode(:, ii)), "_");
                end
            elseif obj.EnumType=="Enum"
                isCode = values'==obj.Constants.value;
                if ~all(any(isCode, 1))
                    error("Undecodable value")
                end
                [~, idc] = max(isCode, [], 1);
                out = obj.Constants.name(idc');
            else
                out = values;
            end
        end

        function out = encode(obj, values)
            %ENCODE Encode values
            %
            %   out = encode(obj, values)
            %
            %   obj: spiky.minos.TypeInfo
            %   values: array

            arguments
                obj spiky.minos.TypeInfo
                values
            end
            sz = size(values);
            n = numel(values);
            values = values(:);
            if obj.EnumType=="Flag"
                out = arrayfun(@(x) sum(obj.Constants.value(logical(sum(...
                    split(x, "_")==obj.Constants.name', 1))), "native"), values);
            elseif obj.EnumType=="Enum"
                out = arrayfun(@(x) obj.Constants.value(x==obj.Constants.name), values);
            else
                out = values;
            end
        end
    end
end

function out = selectJoin(func, in, sep)
    if iscell(in)
        out = cellfun(func, in);
    else
        out = arrayfun(func, in);
    end
    if exist("sep", "var") && sep~=""
        out = join(out, sep);
    end
end

function str = constants2str(t)
    n = height(t);
    c = strings(n, 1);
    for k = 1:n
        c(k) = sprintf("%s:%d", t.name(k), t.value(k));
    end
    str = join(c, ",");
end

function mustBeTableOfConstants(t)
    if ~istable(t) || ~all(strcmpi(t.Properties.VariableNames, ["name", "value"]))
        error("Not a table of constants")
    end
end


