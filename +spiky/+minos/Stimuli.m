classdef Stimuli < spiky.core.Array
    %STIMULI Class representing stimuli used in Minos

    methods
        function obj = Stimuli(name, type, path, subset, label)
            arguments
                name (:, 1) string = string.empty
                type (:, 1) categorical = categorical.empty
                path (:, 1) string = string.empty
                subset (:, 1) double = double.empty
                label (:, 1) categorical = categorical.empty
            end
            n = length(name);
            if isscalar(type)
                type = repmat(type, n, 1);
            end
            if isscalar(subset)
                subset = repmat(subset, n, 1);
            end
            if isscalar(label)
                label = repmat(label, n, 1);
            end
            obj.Data = table(name, type, path, subset, label, ...
                'VariableNames', ["Name", "Type", "Path", "Subset", "Label"]);
        end
    end
end