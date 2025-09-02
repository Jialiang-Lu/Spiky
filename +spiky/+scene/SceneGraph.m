classdef SceneGraph < spiky.core.TimeTable
    % SCENEGRAPH represents a scene graph structure for entities, attributes, and predicates

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
        IsIndirectVerb % If the rows represent indirect verbs in the scene graph
    end

    methods
        function obj = SceneGraph(period, subject, predicate, object, directObject)
            % SCENEGRAPH Constructor for the SceneGraph class
            % 
            %   period: time periods for the scene graph
            %   subject: SceneNode representing the subject
            %   predicate: SceneNode representing the predicate
            %   object: SceneNode representing the object
            %   directObject: SceneNode representing the direct object
            
            arguments
                period (:, 2) double = double.empty
                subject spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(period))
                predicate spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(period))
                object spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(period))
                directObject spiky.scene.SceneNode = spiky.scene.SceneNode.uniform(height(period))
            end

            if isempty(predicate)
                predicate = spiky.scene.SceneNode.uniform(height(period));
            end
            if isempty(object)
                object = spiky.scene.SceneNode.uniform(height(period));
            end
            n = height(period);
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
            obj.Time = period(:, 1);
            obj.Data = table(period, subject, predicate, object, directObject, ...
                VariableNames=["Period", "Subject", "Predicate", "Object", "DirectObject"]);
            obj.Entities = unique([subject{~ismissing(subject), ["Name" "Type"]};
                object{~ismissing(predicate)&~ismissing(object), ["Name" "Type"]};
                directObject{~ismissing(directObject), ["Name" "Type"]}], "rows");
            obj.Attributes = unique(object{ismissing(predicate) & ~ismissing(object), ...
                ["Name" "Type"]}, "rows");
            obj.Predicates = unique(predicate{~ismissing(predicate), ["Name" "Type"]}, "rows");
        end

        function b = get.IsVisibility(obj)
            b = ~ismissing(obj.Data.Subject) & ...
                ismissing(obj.Data.Predicate) & ...
                ismissing(obj.Data.Object);
        end

        function b = get.IsAttribute(obj)
            % ISATTRIBUTE if the rows represent attributes of entities
            b = ~ismissing(obj.Data.Subject) & ...
                ismissing(obj.Data.Predicate) & ...
                ~ismissing(obj.Data.Object);
        end

        function b = get.IsVerb(obj)
            % ISVERB if the rows represent verbs in the scene graph
            b = ~ismissing(obj.Data.Subject) & ...
                ~ismissing(obj.Data.Predicate) & ...
                ~ismissing(obj.Data.Object);
        end

        function b = get.IsIndirectVerb(obj)
            % ISINDIRECTVERB if the rows represent indirect verbs in the scene graph
            b = ~ismissing(obj.Data.Subject) & ...
                ~ismissing(obj.Data.Predicate) & ...
                ~ismissing(obj.Data.Object) & ...
                ~ismissing(obj.Data.DirectObject);
        end

        function n = getCounts(obj, t)
            % GETCOUNTS Get the number of human at specific time points
            %   n = getCounts(obj, t)
            %
            %   t: time points to count the number of humans
            arguments
                obj spiky.scene.SceneGraph
                t double
            end
            per = obj.Data.Period(obj.IsVisibility, :);
            [~, idcT] = spiky.core.Periods(per).haveEvents(t);
            n = zeros(numel(t), 1);
            [c, idc1] = groupcounts(idcT);
            n(idc1) = c;
        end

        function tt = getIdenties(obj, t)
            % GETIDENTIES Get the identities of humans in the scene graph
            %   tt = getIdenties(obj, t)
            %
            %   t: time points to get the identities of humans
            arguments
                obj spiky.scene.SceneGraph
                t double
            end
            isHumanoid = obj.IsVisibility & obj.Data.Subject.Data.Type=="Humanoid";
            per = obj.Data.Period(isHumanoid, :);
            [~, idcT, idcHuman] = spiky.core.Periods(per).haveEvents(t);
        end

        function tt = getTransitions(obj)
            % GETTRANSITIONS Get the transitions of humans in the scene graph
            %   tt = getTransitions(obj)
            data = obj.Data(obj.IsVisibility, :);
            per = data.Period;
            [names, ~, idcName] = unique(data.Subject.Data.Name);
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
            oldFlags = newFlags - changes;
            isAdd = sum(changes, 2)>0;
            oldCounts = sum(oldFlags, 2);
            newCounts = sum(newFlags, 2);
            tt = spiky.core.TimeTable(t, table(isAdd, oldCounts, newCounts, ...
                spiky.utils.flagsdecode(oldFlags, names), ...
                spiky.utils.flagsdecode(newFlags, names), ...
                spiky.utils.flagsdecode(abs(changes), names), ...
                VariableNames=["IsAdd", "OldCount", "NewCount", "OldName", "NewName", "Change"]));
        end

        function str = toStrings(obj)
            % TOSTRINGS Convert the SceneGraph object to a TimeTable of string representations
            
            strMiss = sprintf("\b");
            str = spiky.core.TimeTable(obj.Time, compose("%s %s %s %s", ...
                fillmissing(string(obj.Data.Subject.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.Predicate.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.Object.Name), "constant", strMiss), ...
                fillmissing(string(obj.Data.DirectObject.Name), "constant", strMiss)));
        end

        function obj = cat(~, varargin)
            obj = cat@spiky.core.ArrayTable(1, varargin{:});
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