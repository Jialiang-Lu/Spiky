classdef Confusion < spiky.stat.Decoder
    %CONFUSION Class representing confusion matrices from decoding analyses.
    %
    % The first dimension is time
    % The second dimension is the groups, which can be neurons or events
    % The third dimension is the partions or samples
    % The fourth and fifth dimensions are conditions.
    % The sixth dimension is the true labels
    % The seventh dimension is the predicted labels

    properties
        Cats (:, 1) categorical
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
            dimLabelNames = {"Time", ["Groups"; "GroupIndices"], string.empty, ...
                ["Conditions"; "Partitions"; "Y"], string.empty, "Cats"};
        end
    end

    methods
        function obj = Confusion(time, data, ...
                groups, groupIndices, partitions, conditions, weights, options)
            %CONFUSION Create a new instance of Confusion
            arguments
                time double = []
                data = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                weights cell = cell(size(data))
                options.Type (1, 1) string = "mean"
                options.DataTest = cell(size(data))
                options.Proj spiky.stat.Subspaces = spiky.stat.Subspaces(time, data, groups, groupIndices, partitions, conditions)
                options.Cats (:, 1) categorical = categorical(NaN(size(data, 6), 1))
            end
            obj@spiky.stat.Decoder(time, data, cell(size(data, 4), 1), cell(size(data, 4), 1), ...
                groups, groupIndices, partitions, conditions)
            obj.Proj = weights;
            obj.Type_ = options.Type;
            obj.DataTest = options.DataTest;
            obj.Cats = options.Cats;
        end

        function [h, hSig] = imagesc(obj, plotOps, options)
            %IMAGESC Plot the data as an image
            %   h = IMAGESC(obj, ...)
            %
            %   obj: GroupedStat object
            %   Name-value arguments:
            %       ...: options passed to imagesc()
            %       Parent: parent axes for the plot
            %       Percent: whether to convert the data to percentage
            %       SigStar: whether to plot significance stars
            arguments
                obj spiky.stat.GroupedStat
                plotOps.?matlab.graphics.primitive.Image
                options.Parent matlab.graphics.axis.Axes = gca
                options.Percent logical = false
                options.SigStar logical = true
            end
            data = obj.Data(1, 1, :, 1, 1, :, :);
            data = mean(data, 3, "omitnan");
            data = shiftdim(data, 5); % nCats x nCats
            if options.Percent
                data = data*100;
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = imagesc(options.Parent, data, plotArgs{:});
            nCats = size(data, 1);
            xticks(1:nCats)
            yticks(1:nCats)
            xticklabels(obj.Cats)
            yticklabels(obj.Cats)
            xlabel("Predicted label")
            ylabel("True label")
            plotSig = options.SigStar && ~isempty(obj.P) && ~isnan(obj.P(1));
            if plotSig
                sigStar = shiftdim(obj.SigStar(1, 1, 1, 1, 1, :, :), 5); % nCats x nCats
                [x1, y1] = meshgrid(1:nCats);
                hSig1 = text(options.Parent, x1(:), y1(:), string(sigStar(:)), HorizontalAlignment="center", ...
                    VerticalAlignment="middle", FontSize=10, Color="k", ...
                    BackgroundColor="none");
            end
            if nargout>0
                h = h1;
            end
            if nargout>1 && plotSig
                hSig = hSig1;
            end
        end
    end
end