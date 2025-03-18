classdef GLM < spiky.stat.GroupedStat

    properties
        Partition
    end

    properties (Dependent)
        Coefficients double
    end

    methods
        function obj = GLM(time, data, groups)
            arguments
                time double = []
                data cell = {}
                groups = []
            end
            obj@spiky.stat.GroupedStat(time, data, groups);
        end

        function c = get.Coefficients(obj)
            c = obj.getStat("Estimate");
        end

        function pc = pca(obj, groupIndices, groups)
            arguments
                obj spiky.stat.GLM
                groupIndices = []
                groups = []
            end
            c = obj.Coefficients;
            c = permute(num2cell(c, [2 4]), [1 3 2]);
            c = cellfun(@(x) permute(x, [4 2 1 3]), c, UniformOutput=false);
            pc = spiky.stat.PCA(obj.Time, c, groupIndices, groups);
        end
    end

    methods (Access=protected)
        function out = getStat(obj, var)
            out = cellfun(@(x) reshape(x.Coefficients{2:end, var}, 1, 1, 1, []), obj.Data, ...
                UniformOutput=false);
            out = cell2mat(out);
        end
    end
end