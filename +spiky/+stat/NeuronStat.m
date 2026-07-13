classdef NeuronStat < spiky.core.Array
    %NEURONSTAT Class representing statistics computed for neurons.

    properties
        Type (1, 1) string = ""
        Neuron (:, 1) spiky.core.Neuron
        Conditions (:, 1)
        P double
        Stats table
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
            dimLabelNames = {["Neuron"; "Stats"]; "Conditions"};
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
        function obj = NeuronStat(neuron, data, options)
            %NEURONSTAT Constructor for NeuronStat class.
            arguments
                neuron (:, 1) spiky.core.Neuron = spiky.core.Neuron
                data = []
                options.Type (1, 1) string = ""
                options.Neuron (:, 1) spiky.core.Neuron = spiky.core.Neuron.zeros(height(data))
                options.Conditions (:, 1) = categorical(NaN(width(data), 1))
                options.P (:, :) double = NaN(height(data), 1)
            end
            obj.Neuron = neuron;
            obj.Data = data;
            obj.Type = options.Type;
            obj.Conditions = options.Conditions;
            obj.P = options.P;
            obj.Stats = table(Size=[height(data) 0]);
        end

        function h = plotScatter(obj, sz, options, plotOps)
            arguments
                obj spiky.stat.NeuronStat
                sz double = 20
                options.IdcConditions (1, 2) double = [1 2]
                options.Parent matlab.graphics.axis.Axes = gca
                plotOps.?matlab.graphics.chart.primitive.Scatter
            end
            assert(numel(obj.Conditions)>=max(options.IdcConditions));
            regions = categories(obj.Neuron.Region, OutputType="string");
            nRegions = numel(regions);
            colors = options.Parent.ColorOrder;
            colors = repmat(colors, ceil(nRegions/size(colors, 1)), 1);
            colors = colors(1:nRegions, :);
            np = options.Parent.NextPlot;
            h1 = gobjects(nRegions, 1);
            idc = options.IdcConditions;
            plotArgs = namedargs2cell(plotOps);
            for ii = 1:nRegions
                if ii>1
                    hold(options.Parent, "on");
                end
                idcRegion = obj.Neuron.Region==regions(ii);
                h1(ii) = scatter(options.Parent, obj.Data(idcRegion, idc(1)), obj.Data(idcRegion, idc(2)), ...
                    sz, "filled", plotArgs{:}, "DisplayName", regions(ii));
            end
            xlabel(options.Parent, obj.Conditions(idc(1)));
            ylabel(options.Parent, obj.Conditions(idc(2)));
            options.Parent.NextPlot = np;
            if nRegions>1
                legend(Location="northeast")
            end
            if nargout>0
                h = h1;
            end
        end
    end
end

