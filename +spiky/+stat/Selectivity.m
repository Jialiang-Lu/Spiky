classdef Selectivity < spiky.stat.NeuronStat
    %TUNING 1D discrete selectivity of neurons
    %   First dimension: neurons
    %   Second dimension: stimulus categories or labels
    %   Third dimension: conditions (optional)

    properties
        Labels % labels for each stimulus category, typically a categorical vector
        Fr (:, 1) double % basline firing rate for each neuron
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
            dimLabelNames = {["Neuron"; "Stats"; "Fr"]; "Labels"; "Conditions"};
        end

        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = ["Data"; "P"];
        end
    end

    methods
        function obj = Selectivity(fr, labels, neuron, options)
            %SELECTIVITY Create a new instance of Selectivity
            arguments
                fr (:, :, :) double = []
                labels (:, 1) = categorical(NaN(width(fr), 1))
                neuron (:, 1) spiky.core.Neuron = spiky.core.Neuron.zeros(height(fr))
                options.Conditions (:, 1) = categorical(NaN(size(fr, 3), 1))
                options.P (:, :) double = NaN(size(fr))
            end
            assert(isequal(width(fr), height(labels)), ...
                "The number of rows in fr and labels must be consistent.");
            obj.Labels = labels;
            obj.Fr = squeeze(mean(fr, 2));
            obj.Neuron = neuron;
            obj.Data = fr;
            obj.Conditions = options.Conditions;
            obj.P = options.P;
            obj.Stats = table(Size=[height(fr) 0]);
        end

        function obj = normalize(obj, method)
            %NORMALIZE Normalize the selectivity data across stimulus categories for each neuron.
            %   obj = normalize(method)
            arguments
                obj spiky.stat.Selectivity
                method (1, 1) string {mustBeMember(method, ["zscore", "minmax"])} = "zscore"
            end
            switch method
                case "zscore"
                    obj.Data = zscore(obj.Data, 0, 2);
                case "minmax"
                    obj.Data = (obj.Data-min(obj.Data, [], 2))./(max(obj.Data, [], 2)-min(obj.Data, [], 2));
                otherwise
                    error("Unknown normalization method: %s", options.Method);
            end
        end

        function [idc, order] = orderByPreference(obj)
            %ORDERBYPREFERENCE Order the neurons based on their preferred stimulus category.
            %   [idc, order] = orderByPreference()
            %
            %   idc: indices of the ordered neurons
            %   order: the order of the preferred stimulus categories for each neuron
            [~, order] = sort(obj.Data, 2, "descend");
            [~, idc] = sortrows(order);
        end

        function [idc, tree] = cluster(obj, options)
            %CLUSTER Cluster the neurons or stimulus categories based on their selectivity profiles.
            %   [idc, tree] = cluster(...)
            %
            %   Name-value arguments:
            %       Direction: "neurons" (default) or "labels", indicating whether to cluster neurons or stimulus categories.
            %       Weights: weights for each neuron or label, default is empty (no weighting).
            %       Method: linkage method for hierarchical clustering, default is "average".
            %       Distance: distance metric for clustering, default is "euclidean".
            %
            %   idc: indices of the clustered neurons or labels
            %   tree: hierarchical clustering tree, (m-1)-by-3 matrix, where m is the number of neurons or labels
            arguments
                obj spiky.stat.Selectivity
                options.Direction (1, 1) string {mustBeMember(options.Direction, ["neurons", "labels"])} = "neurons"
                options.Weights (:, 1) double = []
                options.Method (1, 1) string {mustBeMember(options.Method, ["ward", "single", "complete", "average"])} = "average"
                options.Distance (1, 1) string {mustBeMember(options.Distance, ["euclidean", "cityblock", "cosine", "correlation"])} = "euclidean"
            end
            data = obj.Data;
            if options.Direction=="labels"
                data = permute(data, [2 1 3]);
            end
            w = options.Weights;
            if isempty(w)
                w = ones(width(data), 1);
            end
            data = data.*w';
            assert(width(data)>=2, "Not enough data to cluster.");
            if height(data)==1
                warning("Only one neuron or label, clustering is not applicable.");
                idc = 1;
                tree = zeros(0, 3);
                return
            end
            dist = pdist(data, options.Distance);
            tree = linkage(data, options.Method, options.Distance);
            idc = optimalleaforder(tree, dist)';
        end

        function h = imagesc(obj, plotOps, options)
            arguments
                obj spiky.stat.Selectivity
                plotOps.?matlab.graphics.primitive.Image
                options.Parent matlab.graphics.axis.Axes = gca
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = imagesc(options.Parent, obj.Data, plotArgs{:});
            % hc = colorbar(plotOps.Parent);
            % hc.Label.String = "Selectivity";
            xticks(options.Parent, 1:width(obj.Data));
            xticklabels(options.Parent, string(obj.Labels));
            % xtickangle(options.Parent, 45);
            ylabel(options.Parent, "Neurons");
            box(options.Parent, "off");
            if nargout> 0
                h = h1;
            end
        end
    end
end



