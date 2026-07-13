classdef Tuning < spiky.stat.NeuronStat
    %TUNING 1D continuous tuning curve
    %   First dimension: bins
    %   Second dimension: neurons
    %   Third dimension: conditions (optional)

    properties
        BinEdges (:, 1) double
        Occupancy double
        Fr (:, 1) double
    end

    properties (Dependent)
        NBins double
        BinCenters (:, 1) double
        NNeurons double
        Res double
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
            dimLabelNames = {"BinEdges"; ["Neuron"; "Fr"; "P"; "Stats"]; "Conditions"};
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
            dataNames = ["Data"; "Occupancy"];
        end
    end

    methods
        function obj = Tuning(fr, binEdges, occupancy, options)
            %TUNING Create a new instance of Tuning
            arguments
                fr (:, :, :) double = []
                binEdges (:, 1) double = 0
                occupancy (:, 1) double = ones(height(fr), 1)
                options.Neuron (:, 1) spiky.core.Neuron = spiky.core.Neuron.zeros(width(fr))
                options.Conditions (:, 1) = (1:size(fr, 3))'
                options.Fr (:, 1) double = squeeze(mean(fr, 1, Weights=occupancy))
                options.P (:, 1) double = NaN(width(fr), 1)
            end
            assert(isequal(height(fr), height(occupancy), height(binEdges)-1), ...
                "The number of rows in fr, occupancy, and binEdges must be consistent.");
            obj.Data = fr;
            obj.BinEdges = binEdges;
            obj.Occupancy = occupancy;
            obj.Neuron = options.Neuron;
            obj.Conditions = options.Conditions;
            obj.Fr = options.Fr;
            obj.P = options.P;
            obj.Type = "Tuning";
            obj.Stats = table(Size=[length(options.Neuron) 0]);
        end

        function nBins = get.NBins(obj)
            nBins = numel(obj.BinEdges)-1;
        end

        function binCenters = get.BinCenters(obj)
            binCenters = (obj.BinEdges(1:end-1)+obj.BinEdges(2:end)) / 2;
        end

        function nNeurons = get.NNeurons(obj)
            nNeurons = width(obj.Data);
        end

        function res = get.Res(obj)
            res = obj.BinEdges(2)-obj.BinEdges(1);
        end
    end
end