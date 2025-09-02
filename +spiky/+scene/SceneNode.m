classdef SceneNode < spiky.core.TimeTable & matlab.mixin.CustomCompactDisplayProvider
    % SCENENODE represents a node in a scene graph structure

    methods (Static)
        function obj = uniform(n, name, type)
            % UNIFORM Create a uniform SceneNode with specified number of entries
            %
            %   n: number of entries in the SceneNode
            %   name: name of the scene node
            %   type: type of the scene node (e.g., "Human", "Animal", "Object")
            %
            %   obj: SceneNode object with uniform data
            arguments
                n (1, 1) double {mustBePositive}
                name string = ""
                type string = ""
            end
            
            time = NaN(n, 1);
            name = repmat(categorical(name), n, 1);
            type = repmat(categorical(type), n, 1);
            id = zeros(n, 1, "int32");
            pos = NaN(n, 3, "single");
            rot = NaN(n, 3, "single");
            proj = NaN(n, 3, "single");
            obj = spiky.scene.SceneNode(time, name, type, id, pos, rot, proj);
        end

        function b = isScalarRow()
            %ISSCALARROW if each row contains heterogeneous data and should be treated as a scalar
            %   This is useful if the Data is a table or a cell array and the number of columns is fixed.
            %
            %   b: true if each row is a scalar, false otherwise
            b = true;
        end
    end

    methods
        function obj = SceneNode(time, name, type, id, pos, rot, proj)
            % SCENENODE Constructor for the SceneNode class
            % 
            %   time: time points for the scene node
            %   name: names of the scene nodes
            %   type: types of the scene nodes (e.g., "Human", "Object", "Verb")
            %   id: unique identifiers for the scene nodes
            %   pos: positions of the scene nodes in 3D space
            %   rot: rotations of the scene nodes in 3D space
            %   proj: projection vectors for the scene nodes
            arguments
                time double = []
                name categorical = categorical(NaN(numel(time), 1))
                type categorical = categorical(NaN(numel(time), 1))
                id int32 = zeros(numel(time), 1, "int32")
                pos (:, 3) single = NaN(numel(time), 3, "single")
                rot (:, 3) single = NaN(numel(time), 3, "single")
                proj (:, 3) single = NaN(numel(time), 3, "single")
            end
            
            n = numel(time);
            if n>1
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
            obj.Time = time;
            obj.Data = table(name, type, id, pos, rot, proj, ...
                VariableNames=["Name", "Type", "Id", "Pos", "Rot", "Proj"]);
        end

        function b = ismissing(obj)
            % ISMISSING Check if the SceneNode has missing data
            %   b = ismissing(obj)
            %
            %   b: true if any of the data fields are missing, false otherwise
            b = ismissing(obj.Data.Name);
        end

        function rep = compactRepresentationForSingleLine(obj, displayConfiguration, width)
            % rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
            %     Annotation=compose("%s: %s", string(cellstr(string(obj.Data.Type))), ...
            %         string(cellstr(string(obj.Data.Name)))));
            rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
                Annotation=compose("%s ", string(cellstr(string(obj.Data.Name)))));
        end

        function rep = compactRepresentationForColumn(obj, displayConfiguration, width)
            % rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
            %     StringArray=compose("%s: %s", string(cellstr(string(obj.Data.Type))), ...
            %         string(cellstr(string(obj.Data.Name)))));
            rep = widthConstrainedDataRepresentation(obj, displayConfiguration, width, ...
                StringArray=compose("%s ", string(cellstr(string(obj.Data.Name)))));
        end
    end
end