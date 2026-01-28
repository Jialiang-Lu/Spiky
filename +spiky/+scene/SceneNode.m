classdef SceneNode < spiky.core.IntervalsTable & matlab.mixin.CustomCompactDisplayProvider
    %SCENENODE represents a node in a scene graph structure

    methods (Static)
        function obj = uniform(n, name, type)
            %UNIFORM Create a uniform SceneNode with specified number of entries
            %
            %   n: number of entries in the SceneNode
            %   name: name of the scene node
            %   type: type of the scene node (e.g., "Human", "Animal", "Object")
            %
            %   obj: SceneNode object with uniform data
            arguments
                n (1, 1) double = 0
                name categorical = categorical(strings(n, 1))
                type categorical = categorical(strings(n, 1))
            end
            
            intervals = NaN(n, 2);
            id = zeros(n, 1, "int32");
            pos = NaN(n, 3, "single");
            rot = NaN(n, 3, "single");
            proj = NaN(n, 3, "single");
            obj = spiky.scene.SceneNode(intervals, name, type, id, pos, rot, proj);
        end
    end

    methods
        function obj = SceneNode(intervals, name, type, id, pos, rot, proj)
            %SCENENODE Constructor for the SceneNode class
            % 
            %   intervals: intervals for the scene nodes
            %   name: names of the scene nodes
            %   type: types of the scene nodes (e.g., "Human", "Object", "Verb")
            %   id: unique identifiers for the scene nodes
            %   pos: positions of the scene nodes in 3D space
            %   rot: rotations of the scene nodes in 3D space
            %   proj: projection vectors for the scene nodes
            arguments
                intervals (:, 2) double = []
                name categorical = categorical(NaN(height(intervals), 1))
                type categorical = categorical(NaN(height(intervals), 1))
                id int32 = zeros(height(intervals), 1, "int32")
                pos (:, 3) single = NaN(height(intervals), 3, "single")
                rot (:, 3) single = NaN(height(intervals), 3, "single")
                proj (:, 3) single = NaN(height(intervals), 3, "single")
            end
            
            n = height(intervals);
            if n~=1
                if isscalar(name)
                    name = repmat(name, n, 1);
                end
                if isscalar(type)
                    type = repmat(type, n, 1);
                end
                if isscalar(id)
                    id = repmat(id, n, 1);
                end
                if isrow(pos)
                    pos = repmat(pos, n, 1);
                end
                if isrow(rot)
                    rot = repmat(rot, n, 1);
                end
                if isrow(proj)
                    proj = repmat(proj, n, 1);
                end
            end
            obj@spiky.core.IntervalsTable(intervals, table(name, type, id, pos, rot, proj, ...
                VariableNames=["Name", "Type", "Id", "Pos", "Rot", "Proj"]));
        end

        function b = ismissing(obj)
            %ISMISSING Check if the SceneNode has missing data
            %   b = ismissing(obj)
            %
            %   b: true if any of the data fields are missing, false otherwise
            b = ismissing(obj.Data.Name);
        end

        function str = string(obj)
            %STRING Convert the SceneNode to a string representation
            %   str = string(obj)
            %
            %   str: string representation of the SceneNode
            str = compose("%s", string(cellstr(string(obj.Data.Name))));
        end

        function rep = compactRepresentationForSingleLine(obj, displayConfiguration, width)
            % rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
            %     Annotation=compose("%s: %s", string(cellstr(string(obj.Data.Type))), ...
            %         string(cellstr(string(obj.Data.Name)))));
            rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
                Annotation=string(obj)+" ");
        end

        function rep = compactRepresentationForColumn(obj, displayConfiguration, width)
            % rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
            %     StringArray=compose("%s: %s", string(cellstr(string(obj.Data.Type))), ...
            %         string(cellstr(string(obj.Data.Name)))));
            rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
                StringArray=string(obj)+" ");
        end
    end
end