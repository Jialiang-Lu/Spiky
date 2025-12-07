classdef Transform < spiky.core.MappableArray & spiky.core.Metadata
    %TRANSFORM Class representing a transformation of an object

    properties
        Name string
        Id int32
        Data spiky.core.TimeTable
    end

    properties (Dependent)
        Time double
        Period spiky.core.Periods
        Trial double
        Active logical
        Visible logical
        Pos double
        Rot double
        Proj double
        IsHuman logical
    end

    methods
        function obj = Transform(name, id, data)
            arguments
                name string = ""
                id int32 = 0
                data spiky.core.TimeTable = spiky.core.TimeTable
            end
            if isempty(data)
                data = spiky.core.TimeTable([], table(Size=[0 6], ...
                    VariableTypes=["int64" "logical" "logical" "single" "single" "single"], ...
                    VariableNames=["Trial" "Active" "Visible" "Pos" "Rot" "Proj"]));
            end
            obj.Name = name;
            obj.Id = id;
            obj.Data = data;
        end

        function [obj, indices] = interp(obj, time, method)
            %INTERP Interpolate the data to the given time points
            %
            % obj = INTERP(obj, time)
            %
            %   time: time points to interpolate to
            %
            %   obj: transformed object aligned to the given time points
            %   indices: indices of the time points in the original data

            arguments
                obj
                time double
                method string = "previous"
            end
            if isempty(obj)
                return
            end
            prds = spiky.core.Periods.concat(obj.Period);
            [~, idcTr] = prds.haveEvents(time, true);
            idcTr = ~cellfun(@isempty, idcTr);
            if ~any(idcTr)
                obj = spiky.minos.Transform.empty;
                return
            end
            obj = obj(idcTr);
            for ii = 1:numel(obj)
                obj(ii).Data = obj(ii).Data.interp(time, method, AsTimeTable=true);
            end
            indices = idcTr;
        end

        function time = get.Time(obj)
            time = obj.Data.Time;
        end

        function trial = get.Trial(obj)
            trial = obj.Data.Trial;
        end

        function active = get.Active(obj)
            active = obj.Data.Active;
        end

        function visible = get.Visible(obj)
            if ismember("Visible", obj.Data.Data.Properties.VariableNames)
                visible = any(obj.Data.Visible, 3);
            else
                visible = true(height(obj.Data), 1);
            end
        end

        function pos = get.Pos(obj)
            pos = obj.Data.Pos;
        end

        function isHuman = get.IsHuman(obj)
            isHuman = size(obj.Data.Pos, 3)==12;
        end

        function pos = getPos(obj, bodyPart, time)
            arguments
                obj spiky.minos.Transform
                bodyPart = "Root"
                time double = []
            end
            pos = obj.getVec("Pos", bodyPart, time);
        end

        function rot = getRot(obj, bodyPart, time)
            arguments
                obj spiky.minos.Transform
                bodyPart = "Root"
                time double = []
            end
            rot = obj.getVec("Rot", bodyPart, time);
        end

        function proj = getProj(obj, bodyPart, time)
            arguments
                obj spiky.minos.Transform
                bodyPart = "Root"
                time double = []
            end
            proj = obj.getVec("Proj", bodyPart, time);
        end

        function rot = get.Rot(obj)
            rot = obj.Data.Rot;
        end

        function proj = get.Proj(obj)
            proj = obj.Data.Proj;
        end

        function period = get.Period(obj)
            period = spiky.core.Periods([obj.Data.Time(1) obj.Data.Time(end)]);
        end

        function gaze = getViewGaze(obj, height, width)
            %GETVIEWGAZE Get the gaze direction vector in world coordinates given the viewport size
            %   gaze = getViewGaze(obj, height, width)
            %
            %   height: viewport height in degrees
            %   width: viewport width in degrees
            %
            %   gaze: gaze direction vector (Nx3 matrix)
            arguments
                obj spiky.minos.Transform
                height (1, 1) double
                width (1, 1) double = NaN
            end
            gaze = spiky.minos.EyeData.getGaze(obj.Proj, height, width);
        end

        function vec = getVec(obj, vecName, bodyPart, time)
            arguments
                obj spiky.minos.Transform
                vecName string {mustBeMember(vecName, ["Pos" "Rot" "Proj"])}
                bodyPart = "Root"
                time double = []
            end
            if isempty(bodyPart)
                bodyPart = (1:12)';
            end
            bodyPart = bodyPart(:);
            vec = obj.Data.(vecName);
            if isstring(bodyPart)
                bodyPart = bodyPart(ismember(bodyPart, enumeration("spiky.minos.BodyPart")));
                bodyPart = double(spiky.minos.BodyPart(bodyPart))+1;
            end
            if isempty(time)
                vec = vec(:, :, bodyPart);
            else
                idc = interp1(obj.Time, 1:numel(obj.Time), time, "previous", "extrap");
                idc(idc<1) = 1;
                vec = vec(idc, :, bodyPart);
            end
        end

        function pt = flatten(obj, bodyPart, fov)
            arguments
                obj spiky.minos.Transform
                bodyPart = "Root"
                fov double = 60
            end
            if isstring(bodyPart)
                bodyPart = bodyPart(ismember(bodyPart, enumeration("spiky.minos.BodyPart")));
                bodyPart = double(spiky.minos.BodyPart(bodyPart))+1;
            end
            n = numel(obj);
            nVis = arrayfun(@(x) sum(x.Visible)-1, obj);
            nAll = sum(nVis);
            t = zeros(nAll, 2);
            idc = zeros(nAll, 1);
            idcT = zeros(nAll, 1);
            trials = zeros(nAll, 1, "int64");
            pos = zeros(nAll, 3, "single");
            rot = zeros(nAll, 3, "single");
            proj = zeros(nAll, 3, "single");
            idx = 1;
            for ii = 1:n
                obj1 = obj(ii);
                idc1 = find(obj1.Visible);
                idc1 = idc1(1:end-1);
                idc2 = idx:idx+numel(idc1)-1;
                t(idc2, :) = obj1.Time([idc1 idc1+1]);
                idc(idc2) = ii;
                idcT(idc2) = idc1;
                trials(idc2) = obj1.Trial(idc1);
                pos(idc2, :) = obj1.Pos(idc1, :, bodyPart);
                rot(idc2, :) = obj1.Rot(idc1, :, bodyPart);
                proj(idc2, :) = obj1.Proj(idc1, :, bodyPart);
                idx = idx+numel(idc1);
            end
            [~, idcSort] = sort(t(:, 1));
            data = table(idc(idcSort), idcT(idcSort), trials(idcSort), pos(idcSort, :), ...
                rot(idcSort, :), proj(idcSort, :), ...
                spiky.minos.EyeData.getGaze(proj(idcSort, :), fov), ...
                VariableNames=["Index" "TimeIndex" "Trial" "Pos" "Rot" "Proj" "Ray"]);
            pt = spiky.core.PeriodsTable(t(idcSort, :), data);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end