classdef SceneGraph < spiky.core.IntervalsTable
    %SCENEGRAPH represents a scene graph structure for entities, attributes, and predicates

    properties
        Entities table % Table of entities with columns: Name, Type (Humanoid, Object)
        Attributes table % Table of attributes with columns: Name, Type (Color etc.)
        Predicates table % Table of predicates with columns: Name, Type (Attribute, HumanHuman, 
            % HumanObject, ObjectObject)
    end

    properties (Dependent)
        IsVisibility % If the rows represent visibility of entities
        IsAttribute % If the rows represent attributes of entities
        IsVerb % If the rows represent verbs in the scene graph
        IsDirectVerb % If the rows represent direct verbs in the scene graph
        IsIndirectVerb % If the rows represent indirect verbs in the scene graph
    end

    methods
        function obj = SceneGraph(intervals, subject, predicate, object, directObject)
            %SCENEGRAPH Constructor for the SceneGraph class
            % 
            %   intervals: time intervals for the scene graph
            %   subject: SceneNode representing the subject
            %   predicate: SceneNode representing the predicate
            %   object: SceneNode representing the object
            %   directObject: SceneNode representing the direct object
            
            arguments
                intervals (:, 2) double = double.empty
                subject spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(intervals))
                predicate spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(intervals))
                object spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(intervals))
                directObject spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(intervals))
            end

            if isempty(predicate)
                predicate = spiky.scene.SceneNode.uniform(height(intervals));
            end
            if isempty(object)
                object = spiky.scene.SceneNode.uniform(height(intervals));
            end
            n = height(intervals);
            if n>1
                if isrow(subject)
                    subject = repmat(subject, n, 1);
                end
                if isrow(predicate)
                    predicate = repmat(predicate, n, 1);
                end
                if isrow(object)
                    object = repmat(object, n, 1);
                end
                if isrow(directObject)
                    directObject = repmat(directObject, n, 1);
                end
            end
            obj.Time = intervals;
            obj.Data = table(subject, predicate, object, directObject, ...
                VariableNames=["Subject", "Predicate", "Object", "DirectObject"]);
            obj.Entities = unique([subject.Data(~ismissing(subject), ["Name" "Type"]);
                object.Data(~ismissing(predicate)&~ismissing(object), ["Name" "Type"]);
                directObject.Data(~ismissing(directObject), ["Name" "Type"])], "rows");
            obj.Attributes = unique(object.Data(ismissing(predicate) & ~ismissing(object), ...
                ["Name" "Type"]), "rows");
            obj.Predicates = unique(predicate.Data(~ismissing(predicate), ["Name" "Type"]), "rows");
        end

        function b = get.IsVisibility(obj)
            b = ~ismissing(obj.Data.Subject) & ...
                ismissing(obj.Data.Predicate);
        end

        function b = get.IsAttribute(obj)
            %ISATTRIBUTE if the rows represent attributes of entities
            b = ~ismissing(obj.Data.Subject) & ...
                ismissing(obj.Data.Predicate) & ...
                ~ismissing(obj.Data.Object);
        end

        function b = get.IsVerb(obj)
            %ISVERB if the rows represent verbs in the scene graph
            b = ~ismissing(obj.Data.Subject) & ...
                ~ismissing(obj.Data.Predicate) & ...
                obj.Data.Predicate.Type=="Verb";
        end

        function b = get.IsDirectVerb(obj)
            %ISDIRECTVERB if the rows represent direct verbs in the scene graph
            b = obj.IsVerb & ismissing(obj.Data.DirectObject);
        end

        function b = get.IsIndirectVerb(obj)
            %ISINDIRECTVERB if the rows represent indirect verbs in the scene graph
            b = obj.IsVerb & ~ismissing(obj.Data.DirectObject);
        end

        function tt = getCounts(obj, t)
            %GETCOUNTS Get the number of human at specific time points
            %   tt = getCounts(obj, t)
            %
            %   t: time points to count the number of humans
            arguments
                obj spiky.scene.SceneGraph
                t double = []
            end
            per = obj.Time(obj.IsVisibility, :);
            if isempty(t)
                t = unique(per, "sorted");
            end
            [~, idcT] = spiky.core.Intervals(per).haveEvents(t);
            n = zeros(numel(t), 1);
            [c, idc1] = groupcounts(idcT);
            n(idc1) = c;
            tt = spiky.core.EventsTable([-realmax; t], [0; n]);
        end

        function tt = getIdenties(obj)
            %GETIDENTIES Get the identities of humans in the scene graph
            %   tt = getIdenties(obj)
            data = obj.Data{obj.IsVisibility, "Subject"}.Data.Name;
            t = obj.Time(obj.IsVisibility, :);
            tt = spiky.core.IntervalsTable([[-realmax t(1)]; t], [missing; data]).toEventsTable();
        end

        function tt = getTransitions(obj)
            %GETTRANSITIONS Get the transitions of humans in the scene graph
            %   tt = getTransitions(obj)
            idc = obj.IsVisibility & obj.Data.Subject.Type=="Humanoid";
            data = obj.Data(idc, :);
            per = obj.Time(idc, :);
            [names, ~, idcName] = unique(data.Subject.Name);
            nHumans = numel(names);
            n = height(per);
            t = per(:);
            changes = zeros(n*2, nHumans);
            for ii = 1:n
                changes(ii, idcName(ii)) = 1; % Start of visibility
                changes(ii+n, idcName(ii)) = -1; % End of visibility
            end
            [t, idcT] = sort(t);
            changes = changes(idcT, :);
            newFlags = cumsum(changes, 1);
            oldFlags = newFlags-changes;
            isAdd = sum(changes, 2)>0;
            oldCounts = sum(oldFlags, 2);
            newCounts = sum(newFlags, 2);
            tt = spiky.core.EventsTable(t, table(isAdd, oldCounts, newCounts, ...
                spiky.utils.flagsdecode(oldFlags, names), ...
                spiky.utils.flagsdecode(newFlags, names), ...
                spiky.utils.flagsdecode(abs(changes), names), ...
                VariableNames=["IsAdd", "OldCount", "NewCount", "OldName", "NewName", "Change"]));
        end

        function tt = getVerbs(obj)
            %GETVERBS Get the verbs in the scene graph
            %   tt = getVerbs(obj)
            data = obj.Data{obj.IsVerb, "Predicate"}.Data.Name;
            t = obj.Time(obj.IsVerb, :);
            tt = spiky.core.IntervalsTable(t, data).toEventsTable();
            tt = tt(~contains(string(tt.Data), "|"), :);
            tt = tt([true; tt.Data(2:end)~=tt.Data(1:end-1)], :); % remove consecutive duplicates
            tt.Data(ismissing(tt.Data)) = "Idle";
        end

        function obj = getActions(obj)
            %GETACTIONS Get the actions (direct and indirect verbs) in the scene graph
            %   obj = getActions(obj)
            idc = obj.IsVerb & ~ismember(obj.Data.Predicate.Name, ["Idle" "Walk"]);
            obj.Data = obj.Data(idc, :);
            obj.Time = obj.Time(idc, :);
            obj.Data.SubjectLeft = obj.Data.Subject.Pos(:, 1)<obj.Data.Object.Pos(:, 1);
            obj.Data.Left = obj.Data.Subject;
            obj.Data.Left.Data(~obj.Data.SubjectLeft, :) = ...
                obj.Data.Object.Data(~obj.Data.SubjectLeft, :);
            obj.Data.Right = obj.Data.Object;
            obj.Data.Right.Data(obj.Data.SubjectLeft, :) = ...
                obj.Data.Subject.Data(obj.Data.SubjectLeft, :);
            roles = categorical(strings(height(obj.Data), 2), ["Subject" "Object"]);
            roles(:, 1) = "Subject";
            roles(:, 2) = "Object";
            roles(~obj.Data.SubjectLeft, :) = fliplr(roles(~obj.Data.SubjectLeft, :));
            obj.Data.LeftRole = roles(:, 1);
            obj.Data.RightRole = roles(:, 2);
        end

        function str = toStrings(obj)
            %TOSTRINGS Convert the SceneGraph object to a EventsTable of string representations
            
            strMiss = sprintf("\b");
            str = spiky.core.EventsTable(obj.Time, compose("%s %s %s %s", ...
                fillmissing(string(obj.Data.Subject.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.Predicate.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.Object.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.DirectObject.Name), "constant", strMiss)));
        end

        function obj = cat(~, varargin)
            obj = cat@spiky.core.Array(1, varargin{:});
            obj.Entities = spiky.scene.SceneGraph.combineTbl("Entities", varargin{:});
            obj.Attributes = spiky.scene.SceneGraph.combineTbl("Attributes", varargin{:});
            obj.Predicates = spiky.scene.SceneGraph.combineTbl("Predicates", varargin{:});
        end
    end

    methods (Static, Access = protected)
        function tbl = combineTbl(name, varargin)
            arguments
                name string {mustBeMember(name, ["Entities", "Attributes", "Predicates"])}
            end
            arguments (Repeating)
                varargin {mustBeA(varargin, "spiky.scene.SceneGraph")}
            end
            tbls = cellfun(@(x) x.(name), varargin, UniformOutput=false);
            tbl = unique(vertcat(tbls{:}), "rows");
        end
    end
end