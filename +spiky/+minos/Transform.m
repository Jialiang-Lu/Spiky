classdef Transform < spiky.core.MappableObjArray
    %TRANSFORM Class representing a transformation of an object
    %
    %   Properties:
    %       Name (string): name of the transform
    %       Id (int32): id of the transform
    %       Time (double): time points of the transform
    %       Trial (int64): trial number
    %       Active (logical): whether the object is active
    %       Visible (logical): whether the object is visible
    %       Pos (single): position (Nx3xM array, M is number of body parts)
    %       Rot (single): rotation (Nx3xM array, M is number of body parts)
    %       Proj (single): projection (Nx3xM array, M is number of body parts)

    properties
        Name string
        Id int32
    end

    properties (Dependent)
        IsHuman % whether the object is human
        Interval % time interval of the transform
    end

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {["Name"; "Id"]};
        end
    end

    methods
        function obj = Transform(name, id, data)
            arguments
                name (:, 1) string = string.empty
                id (:, 1) int32 = int32.empty
                data (:, 1) cell = {} % cell array of spiky.core.EventsTable
            end
            obj@spiky.core.MappableObjArray(data, Class="spiky.core.EventsTable");
            obj.Name = name;
            obj.Id = id;
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
            obj = obj.Array{1};
            prds = spiky.core.Intervals.concat(obj.Interval);
            [~, idcTr] = prds.haveEvents(time, CellMode=true);
            idcTr = ~cellfun(@isempty, idcTr);
            if ~any(idcTr)
                obj = spiky.minos.Transform;
                return
            end
            obj = obj(idcTr);
            for ii = 1:numel(obj)
                obj{ii} = obj{ii}.interp(time, method, AsEventsTable=true);
            end
            indices = idcTr;
        end

        function isHuman = get.IsHuman(obj)
            obj = obj.Array{1};
            isHuman = size(obj.Pos, 3)==12;
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

        function interval = get.Interval(obj)
            obj = obj.Array{1};
            interval = spiky.core.Intervals([obj.Time(1) obj.Time(end)]);
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
            obj = obj.Array{1};
            gaze = spiky.minos.EyeData.getGaze(obj.Proj, height, width);
        end

        function vec = getVec(obj, vecName, bodyPart, time)
            arguments
                obj spiky.minos.Transform
                vecName string {mustBeMember(vecName, ["Pos" "Rot" "Proj"])}
                bodyPart = "Root"
                time double = []
            end
            obj = obj.Array{1};
            if isempty(bodyPart)
                bodyPart = (1:12)';
            end
            bodyPart = bodyPart(:);
            vec = obj.(vecName);
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
            obj = obj.Array{1};
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
            pt = spiky.core.IntervalsTable(t(idcSort, :), data);
        end
    end

    methods (Access = protected)
        function key = getKey(obj)
            key = obj.Name;
        end
    end
end