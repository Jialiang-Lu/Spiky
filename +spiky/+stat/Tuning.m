classdef Tuning < spiky.core.Array
    %TUNING 1D continuous tuning curve

    properties
        BinEdges (:, 1) double
        Occupancy double
    end

    properties (Dependent)
        NBins double
        BinCenters (:, 1) double
        NNeurons double
        Res double
    end

    methods
        function nBins = get.NBins(obj)
            nBins = numel(obj.BinEdges) - 1;
        end

        function binCenters = get.BinCenters(obj)
            binCenters = (obj.BinEdges(1:end-1) + obj.BinEdges(2:end)) / 2;
        end

        function nNeurons = get.NNeurons(obj)
            nNeurons = size(obj.Data, 2);
        end

        function res = get.Res(obj)
            res = obj.BinEdges(2) - obj.BinEdges(1);
        end
    end
end