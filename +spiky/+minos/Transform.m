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
            if ismember("Visible", obj.Data.Properties.VariableNames)
                visible = obj.Data.Visible;
            else
                visible = true(height(obj.Data), 1, size(obj.Data.Active, 3));
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

            arguments
                obj spiky.minos.Transform
                height (1, 1) double
                width (1, 1) double = NaN
            end
            if isnan(width)
                width = height/9*16;
            end
            % vp = [gaze(:, 1)./gaze(:, 3)./tand(width/2).*0.5+0.5...
            %     gaze(:, 2)./gaze(:, 3)./tand(height/2).*0.5+0.5];
            vp = obj.Proj(:, 1:2);
            gaze = ones(height(vp), 3);
            gaze(:, 1) = (vp(:, 1)-0.5).*tand(width/2).*2;
            gaze(:, 2) = (vp(:, 2)-0.5).*tand(height/2).*2;
            gaze = gaze./vecnorm(gaze, 2, 2);
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
            if isstring(bodyPart) || ischar(bodyPart) || iscellstr(bodyPart)
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
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end