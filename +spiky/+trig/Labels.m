classdef Labels < spiky.trig.Trig
    %LABELS Class representing labels for events

    properties
        Groups (:, 1)
    end

    properties (Dependent)
        NGroups double
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Events" "Groups"];
        end
    end

    methods
        function obj = Labels(time, data, events, groups)
            arguments
                time double = []
                data = []
                events (:, 1) = NaN(width(data), 1)
                groups (:, 1) = NaN(size(data, 3), 1)
            end
            if isempty(time) && isempty(data)
                return
            end
            obj.Time = time;
            obj.Data = data;
            obj.EventDim = 2;
            obj.Events_ = events;
            obj.Groups = groups;
        end

        function n = get.NGroups(obj)
            n = size(obj.Data, 3);
        end

        function [h, hError] = plot(obj, cats, lineSpec, plotOps, options)
            %PLOT Plot the labels
            %
            %   h = PLOT(obj, cats, lineSpec, ...)
            %
            %   obj: Labels object
            %   cats: categories of events
            %   lineSpec: line specification
            %   Name-value arguments:
            %       Grouping: grouping of the data, can be "Cats", "Events", 
            %           or "Neurons"
            %       SubSet: subset of categories to plot
            %       Color, LineWidth, ...: options passed to plot() 
            %       FaceAlpha: face alpha for the error bars
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot
            %   hError: handle to the error bars

            arguments
                obj spiky.trig.Labels
                cats = zeros(obj.NEvents, 1)
                lineSpec string = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Grouping string {mustBeMember(options.Grouping, ["Cats", "Events", "Groups"])} = "Cats"
                options.SubSet = unique(cats)
                options.FaceAlpha double = 0
                options.Parent matlab.graphics.axis.Axes = gca
            end

            n = obj.NEvents;
            idcEvents = ismember(cats, options.SubSet);
            cats = cats(idcEvents);
            switch options.Grouping
                case "Cats"
                    data = mean(obj.Data(:, idcEvents, :), 3)';
                case "Events"
                    data = mean(obj.Data(:, idcEvents, :), 3)';
                    cats = 1:height(data);
                    options.FaceAlpha = 0;
                case "Groups"
                    data = mean(permute(obj.Data(:, idcEvents, :), [3 1 2]), 3);
                    cats = obj.Groups;
                    options.FaceAlpha = 0;
            end
            [m, names] = groupsummary(data, cats, @mean);
            if options.FaceAlpha>0
                [se, ~] = groupsummary(data, cats, @std);
                se = se./sqrt(groupcounts(cats));
            end
            if isempty(m)
                error("No data to plot")
            end
            if options.FaceAlpha>0
                plotOps.FaceAlpha = options.FaceAlpha;
                plotArgs = namedargs2cell(plotOps);
                [h1, hError1] = spiky.plot.plotError(obj.Time', m, se, lineSpec, plotArgs{:});
            else
                plotArgs = namedargs2cell(plotOps);
                h1 = plot(obj.Time', m, lineSpec, plotArgs{:});
                hError1 = gobjects(0, 1);
            end

            if size(m, 1)>1
                legend(h1, names);
            end

            box off
            xlim(obj.Time([1 end]));
            l = xline(0, "g", LineWidth=2);
            l.Annotation.LegendInformation.IconDisplayStyle = "off";
            xlabel("Time (s)");
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end
    end
end