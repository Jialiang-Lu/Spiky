classdef GLM < spiky.core.Array
    %GLM Generalized linear model fitted to binned spike counts
    %
    % First dimension is predictors, second dimension is neurons, third dimension is partitions 
    % (e.g. cross-validation folds)

    properties
        Neuron (:, 1) spiky.core.Neuron % Neurons the model is fitted to
        Intercepts (1, :, :) double % Intercept term for each neuron and partition
        Name (:, 1) string % Names of the predictors
        Lambda (1, 1) double % Regularization parameter
        Alpha (1, 1) double % Elastic net mixing parameter
        Deviance (1, :, :) double % Deviance of the model for each neuron and partition
        Options struct % Options used for fitting the GLM
    end

    properties (Dependent)
        Coeffs
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
            dimLabelNames = {"Name"; "Neuron"};
        end

        function [extraDataName, scalarDimension] = getExtraDataName()
            %GETEXTRADATANAME Get the name of the extra data field
            %
            %   extraDataName: name of the each data field, empty if no extra data field
            %   scalarDimension: indices of the scalar dimension for each extra data field
            extraDataName = ["Intercepts" "Deviance"];
            scalarDimension = { 1, 1 };
        end
    end

    methods
        function obj = GLM(coeffs, intercepts, names, neuron, lambda, alpha, deviance, options)
            arguments
                coeffs = []
                intercepts (1, :, :) double = []
                names (:, 1) string = string.empty(0, 1)
                neuron (:, 1) = spiky.core.Neuron
                lambda (1, 1) double = NaN
                alpha (1, 1) double = NaN
                deviance (1, :, :) double = []
                options struct = struct()
            end
            if isempty(coeffs)
                return
            end
            if height(coeffs) ~= numel(names)
                error("The number of predictor names must be the same as the number of predictors")
            end
            obj.Data = coeffs;
            obj.Intercepts = intercepts;
            obj.Name = names;
            obj.Neuron = neuron;
            obj.Lambda = lambda;
            obj.Alpha = alpha;
            obj.Deviance = deviance;
            obj.Options = options;
        end

        function ss = getSubspace(obj, name, options)
            %GETSUBSPACE Get the subspace corresponding to a predictor
            %   ss = GETSUBSPACE(obj, name)
            %
            %   obj: GLM object
            %   name: name of the predictor
            %   Name-value arguments:
            %       Average: Dimensions to perform averaging over (default: no averaging)
            %
            %   ss: spiky.stat.Subspace object
            arguments
                obj spiky.stat.GLM
                name (1, 1) string
                options.Average (1, :) double = []
            end
            names = split(obj.Name, ".");
            isMatch = names(:, 1)==name;
            if ~any(isMatch)
                error("No predictor found with name '%s'", name);
            end
            classes = unique(names(isMatch, 2));
            n = sum(isMatch);
            bases = obj.Data(isMatch, :, :);
            newNames = compose("%s.%s", names(isMatch, 2), names(isMatch, 3));
            if ~isempty(options.Average)
                bases = cell2mat(arrayfun(@(c) mean(bases(names(isMatch, 2)==c, :, :), options.Average), ...
                    classes, UniformOutput=false));
                n = height(bases);
                newNames = classes;
            end
            regions = unique(obj.Neuron.Region);
            groupIndices = arrayfun(@(r) find(obj.Neuron.Region==r), regions, UniformOutput=false);
            coords = cell(1, numel(groupIndices), size(bases, 3));
            for ii = 1:numel(groupIndices)
                for jj = 1:size(bases, 3)
                    coords{1, ii, jj} = spiky.stat.Coords(zeros(n, 1), ...
                        bases(:, groupIndices{ii}, jj), newNames, obj.Neuron(groupIndices{ii}));
                end
            end
            ss = spiky.stat.Subspaces(0, coords, regions, groupIndices);
        end

        function coeffs = get.Coeffs(obj)
            coeffs = obj.Data;
        end
    end
end