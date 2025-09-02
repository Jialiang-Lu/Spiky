classdef Accuracy < spiky.stat.GroupedStat

    properties
        Chance double % Chance level
    end

    properties (Dependent)
        NFold double
    end

    methods (Static)
        function chance = getChance(data)
            % GETCHANCE Get the chance level for the data
            %
            %   chance: chance level
            data = data(~ismissing(data));
            data = data(:);
            b = groupcounts(data);
            chance = max(b)./sum(b);
        end
    end
    
    methods
        function obj = Accuracy(time, data, groups, groupIndices, chance)
            arguments
                time double = []
                data double = []
                groups (:, 1) = []
                groupIndices cell = cell(height(groups), 1)
                chance double = []
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
            obj.Chance = chance;
        end

        function n = get.NFold(obj)
            % Get the number of folds
            if isempty(obj.Data)
                n = 0;
            else
                n = size(obj.Data, 3);
            end
        end
        
        function [h, hError] = plot(obj, lineSpec, plotOps, options)
            % PLOT Plot the accuracy
            %
            %   h = PLOT(obj, lineSpec, ...)
            %
            %   obj: Accuracy object
            %   lineSpec: line specification
            %   Name-value arguments:
            %       Color, LineWidth, ...: options passed to plot() 
            %       Chance: chance level to plot
            %       FaceAlpha: face alpha for the error bars
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot
            %   hError: handle to the error bars
            arguments
                obj spiky.stat.Accuracy
                lineSpec string = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Chance double = []
                options.FaceAlpha double = .3
                options.Parent matlab.graphics.axis.Axes = gca
            end
            
            plotArgs = namedargs2cell(plotOps);
            if obj.NFold==1
                options.FaceAlpha = 0;
            end
            m = mean(obj.Data, 3)*100;
            if options.FaceAlpha==0
                h1 = plot(obj.Time, m, lineSpec, plotArgs{:}, ...
                    Parent=options.Parent);
                hError1 = gobjects(0, 1);
            else
                se = std(obj.Data, 0, 3)./sqrt(obj.NFold)*100;
                [h1, hError1] = spiky.plot.plotError(obj.Time, m, se, lineSpec, plotArgs{:});
            end
            if obj.NGroups>1
                legend(options.Parent, obj.Groups);
            end
            box off
            xlim(obj.Time([1 end]));
            l = xline(0, "g", LineWidth=2);
            l.Annotation.LegendInformation.IconDisplayStyle = "off";
            if isempty(options.Chance) && ~isempty(obj.Chance)
                options.Chance = obj.Chance;
            end
            if ~isempty(options.Chance)
                l2 = yline(options.Chance*100, "-", "Chance", LineWidth=1);
                l2.Annotation.LegendInformation.IconDisplayStyle = "off";
            end
            xlabel("Time (s)");
            ylabel("Accuracy (%)");
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end
    end
end