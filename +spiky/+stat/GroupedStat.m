classdef GroupedStat < spiky.core.EventsTable
    %GROUPEDSTAT Base class representing grouped statistics
    %
    % The first dimension is time
    % The second dimension is the groups, which can be neurons or events
    % The third dimension is the partions or samples
    % The fourth and higher dimensions are conditions.

    properties
        Metric string % name of the metric
        Groups (:, 1) % categorical names or spiky.core.Neuron array
        GroupIndices (:, :) logical % logical indices for each group, nGroups x nUnits
        Conditions (:, 1) categorical % condition labels for each condition, nConditions x 1
        Partitions (:, 1) cell % cvpartition for each condition, nConditions x 1
        Chance double % chance level for the statistic
        Shuffle cell % shuffled data, same size as Data
        P double % p values, same size as Data
    end

    properties (Dependent)
        NGroups double
        NPartitions double
        NConditions double
    end

    methods (Static)
        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = ["Data", "Shuffle", "P"];
        end

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
                ["Conditions"; "Partitions"]};
        end

        function h = boxcharts(objs, plotOps, options)
            arguments (Repeating)
                objs spiky.stat.GroupedStat
            end
            arguments
                plotOps.?matlab.graphics.chart.primitive.BoxChart
                options.Parent matlab.graphics.axis.Axes = gca
                options.Percent logical = false
                options.Chance double = []
                options.Scatter logical = true
            end
            plotArgs = namedargs2cell(plotOps);
            optionArgs = namedargs2cell(options);
            n = length(objs);
            x = cell(n, 1);
            y = cell(n, 1);
            c = cell(n, 1);
            for ii = 1:n
                h1 = boxchart(objs{ii}, plotArgs{:}, optionArgs{:});
                x{ii} = h1.XData(:);
                y{ii} = h1.YData(:);
                c{ii} = ones(size(x{ii}))*ii;
                xtl = xticklabels(options.Parent);
                delete(h1);
            end
            cla
            x = cell2mat(x);
            y = cell2mat(y);
            c = cell2mat(c);
            h1 = boxchart(options.Parent, x, y, "GroupByColor", c, plotArgs{:});
            xticks(options.Parent, 1:numel(xtl));
            xticklabels(options.Parent, xtl);
            xtickangle(options.Parent, 30);
            if isempty(options.Chance) && ~isempty(objs{1}.Chance)
                options.Chance = objs{1}.Chance;
            end
            if ~isempty(options.Chance) && ~isnan(options.Chance)
                yline(options.Parent, options.Chance, "-", "Chance", LineWidth=1);
            end
            box off
            if nargout>0
                h = h1;
            end
        end
    end

    methods
        function obj = GroupedStat(time, data, groups, groupIndices, partitions, conditions, options)
            arguments
                time double = []
                data = []
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions (:, 1) = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                options.Metric string = ""
                options.Chance double = NaN
                options.Shuffle cell = cell(size(data))
                options.P double = NaN(size(data))
            end
            if isempty(time) && isempty(data) && isempty(groups)
                return
            end
            assert(height(data)==numel(time), ...
                "The number of time points and values must be the same")
            assert(width(data)==height(groups), ...
                "The number of groups must be the same as the number of columns in the data")
            assert(width(data)==height(groupIndices), ...
                "The number of group indices must be the same as the number of columns in the data")
            assert(size(data, 4)==height(partitions), ...
                "The number of partitions must be the same as the number of conditions")
            assert(size(data, 4)==height(conditions), ...
                "The number of conditions must be the same as the number of conditions")
            if iscell(groupIndices)
                nNeurons = max(cellfun(@max, groupIndices));
                groupIndicesMat = false(height(groups), nNeurons);
                for ii = 1:length(groupIndices)
                    groupIndicesMat(ii, groupIndices(ii, :)) = true;
                end
                groupIndices = groupIndicesMat;
            end
            obj.Time = time;
            obj.Data = data;
            obj.Groups = groups;
            obj.GroupIndices = groupIndices;
            obj.Partitions = partitions;
            obj.Conditions = conditions;
            obj.Metric = options.Metric;
            obj.Chance = options.Chance;
            obj.Shuffle = options.Shuffle;
            obj.P = options.P;
        end

        function n = get.NGroups(obj)
            n = width(obj.Data);
        end

        function n = get.NPartitions(obj)
            n = size(obj.Data, 3);
        end

        function n = get.NConditions(obj)
            n = size(obj.Data, 4);
        end

        function obj = cond2time(obj)
            %COND2TIME Convert the condition dimension to time dimension
            obj.Time = round(double(string(obj.Conditions)), 3);
            obj.Data = permute(obj.Data, [4 2 3 1 5 6]);
            obj.Conditions = categorical(NaN);
            obj.Partitions = {obj.Partitions};
        end

        function obj = filter(obj, filter, filterArg)
            %FILTER Filter the data
            %
            %   obj = FILTER(obj, filter)
            %
            %   obj: grouped statistics
            %   filter: filter
            %
            %   obj: filtered grouped statistics
            arguments
                obj spiky.stat.GroupedStat
                filter
                filterArg = []
            end
            if ischar(filter) || isstring(filter)
                if isempty(filterArg)
                    error("The filter argument must be provided if the filter is a string")
                end
                filter = @(x) ismember(x.(filter), filterArg);
            end
            [~, idc] = feval(filter, obj.Groups);
            obj = obj(:, idc, :);
        end

        function [h, hError] = plot(obj, lineSpec, plotOps, options)
            %PLOT Plot the GroupedStat
            %
            %   h = PLOT(obj, lineSpec, ...)
            %
            %   obj: GroupedStat object
            %   lineSpec: line specification
            %   Name-value arguments:
            %       Color, LineWidth, ...: options passed to plot() 
            %       Clip: [ymin ymax] to clip the data for plotting
            %       Chance: chance level to plot
            %       FaceAlpha: face alpha for the error bars
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot
            %   hError: handle to the error bars
            arguments
                obj spiky.stat.GroupedStat
                lineSpec string = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Percent logical = false
                options.Clip double = []
                options.Smooth double = 0
                options.Chance double = []
                options.Shuffle spiky.stat.GroupedStat = []
                options.FaceAlpha double = .3
                options.Parent matlab.graphics.axis.Axes = gca
            end
            nTrain = size(obj.Data, 4);
            if nTrain>1
                if size(obj.Data, 5)>1
                    if size(obj.Data, 5)~=nTrain
                        error("The number of test conditions must be the same as the number of train conditions for condition plot.")
                    end
                    nPlot = nTrain*nTrain;
                    nTest = nTrain;
                    conditions = string(obj.Conditions)+sprintf(" \x21d2 ")+string(obj.Conditions)';
                    conditions = conditions(:);
                else
                    nPlot = nTrain;
                    nTest = 1;
                    conditions = string(obj.Conditions);
                end
                hs = gobjects(nPlot, 1);
                hErrors = gobjects(nPlot, 1);
                clip = options.Clip;
                options.Clip = [];
                for ii = 1:nPlot
                    if ii==1
                        options.Chance = [];
                    else
                        hold(options.Parent, "on")
                        options.Chance = NaN;
                    end
                    plotArgs = namedargs2cell(plotOps);
                    optionArgs = namedargs2cell(options);
                    [idxTrain, idxTest] = ind2sub([nTrain, nTest], ii);
                    obj1 = subsref(obj, substruct("()", {':', ':', ':', idxTrain, idxTest}));
                    [hs(ii), hErrors(ii)] = obj1.plot(lineSpec, plotArgs{:}, optionArgs{:});
                end
                hold(options.Parent, "off")
                legend(options.Parent, hs, conditions);
                if ~isempty(clip)
                    yl = ylim(options.Parent);
                    yl(1) = max(yl(1), clip(1));
                    yl(2) = min(yl(2), clip(2));
                    ylim(options.Parent, yl);
                end
                if nargout>0
                    h = hs;
                    if nargout>1
                        hError = hErrors;
                    end
                end
                return
            end
            plotArgs = namedargs2cell(plotOps);
            if isempty(options.Chance) && ~isempty(obj.Chance)
                options.Chance = obj.Chance;
            end
            if obj.NPartitions==1
                options.FaceAlpha = 0;
            end
            data = obj.Data;
            if options.Percent
                data = data*100;
                options.Chance = options.Chance*100;
            end
            if ~isempty(options.Clip)
                data = min(max(data, options.Clip(1)), options.Clip(2));
            end
            m = mean(data, 3);
            if options.Smooth > 0
                res = obj.Time(2)-obj.Time(1);
                kSize = 2*ceil(2.5*options.Smooth/res)+1;
                kernel = fspecial("gaussian", [kSize 1], options.Smooth/res);
                m = imfilter(m, kernel, "replicate");
            end
            if options.FaceAlpha==0
                h1 = plot(obj.Time, m, lineSpec, plotArgs{:}, ...
                    Parent=options.Parent);
                hError1 = gobjects(0, 1);
            else
                se = std(data, 0, 3)./sqrt(obj.NPartitions);
                if options.Smooth > 0
                    se = imfilter(se, kernel, "replicate");
                end
                [h1, hError1] = spiky.plot.plotError(obj.Time, m, se, lineSpec, plotArgs{:});
            end
            if obj.NGroups>1
                legend(options.Parent, h1, obj.Groups);
            end
            box off
            xlim(options.Parent, obj.Time([1 end]));
            l = xline(options.Parent, 0, "g", LineWidth=1);
            l.Annotation.LegendInformation.IconDisplayStyle = "off";
            if ~isempty(options.Chance) && ~isnan(options.Chance)
                yline(options.Parent, options.Chance, "-", "Chance", LineWidth=1);
            end
            xlabel("Time (s)");
            if ~isempty(options.Clip)
                yl = ylim(options.Parent);
                yl(1) = max(yl(1), options.Clip(1));
                yl(2) = min(yl(2), options.Clip(2));
                ylim(options.Parent, yl);
            end
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end

        function h = imagesc(obj, plotOps, options)
            arguments
                obj spiky.stat.GroupedStat
                plotOps.?matlab.graphics.primitive.Image
                options.Parent matlab.graphics.axis.Axes = gca
                options.Percent logical = false
                options.Type {mustBeMember(options.Type, ["time", "condition"])} = "condition"
            end
            assert(obj.NGroups==1, "imagesc can only be plotted for one group at a time.")
            data = obj.Data;
            switch options.Type
                case "time"
                    assert(size(data, 4)==height(data), ...
                        "The number of conditions must be the same as the number of time points for time plot.")
                    x = obj.Time;
                    y = obj.Time;
                    data = permute(data, [1 4 3 2]); % nT x nT x nPartitions
                case "condition"
                    assert(size(data, 4)==size(data, 5), ...
                        "The number of test conditions must be the same as the number of train conditions for condition plot.")
                    x = obj.Conditions;
                    y = obj.Conditions;
                    data = permute(data, [4 5 3 1 2]); % nConditions x nConditions x nPartitions
            end
            nComp = height(data);
            if iscell(data) % concatenate confusion
                nCats = height(data{1});
                data = mean(cell2mat(data), 3); % average over partitions
                x = [];
                y = [];
            else
                data = mean(data, 3);
                nCats = 1;
            end
            if options.Percent
                data = data*100;
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = imagesc(options.Parent, x, y, data', plotArgs{:});
            box off
            if nCats>1
                x = (1+nCats)/2:nCats:((nComp-1)*nCats+1+(nCats-1)/2);
                xticks(options.Parent, x);
                xticklabels(options.Parent, obj.Conditions);
                yticks(options.Parent, 1:nCats);
                yticklabels(options.Parent, 1:nCats);
                borders = nCats+0.5:nCats:(nComp-1)*nCats+0.5;
                xline(options.Parent, borders);
                yline(options.Parent, borders);
            end
            if nargout>0
                h = h1;
            end
        end

        function [h, hScatter] = boxchart(obj, plotOps, options)
            %BOXCHART Plot the data as box charts
            %
            %   h = BOXCHART(obj, plotOps, options)
            %
            %   obj: GroupedStat object
            %   plotOps: options passed to boxchart()
            %   Name-Value pairs:
            %       Parent: parent axes for the plot
            %
            %   h: handle to the boxchart
            arguments
                obj spiky.stat.GroupedStat
                plotOps.?matlab.graphics.chart.primitive.BoxChart
                options.Parent matlab.graphics.axis.Axes = gca
                options.Percent logical = false
                options.Chance double = []
                options.Scatter logical = true
            end
            assert(obj.NGroups==1, "Box chart can only be plotted for one group at a time.")
            data = permute(obj.Data(1, :, :, :, :), [3 4 5 1 2]);
            if isempty(options.Chance) && ~isempty(obj.Chance)
                options.Chance = obj.Chance;
            end
            if options.Percent
                data = data*100;
                options.Chance = options.Chance*100;
            end
            nConditions = width(data);
            if size(data, 3)>1
                data = reshape(data, height(data), []);
                conditions = string(obj.Conditions)+sprintf(" \x21d2 ")+string(obj.Conditions)';
                conditions = conditions(:);
            else
                conditions = obj.Conditions;
            end
            plotArgs = namedargs2cell(plotOps);
            x = repelem((1:width(data))', height(data), 1);
            y = data(:);
            h1 = boxchart(options.Parent, x, y, plotArgs{:});
            if options.Scatter
                hold(options.Parent, "on");
                h2 = swarmchart(options.Parent, x, y, MarkerFaceColor=h1.MarkerColor, ...
                    MarkerEdgeColor=h1.MarkerColor, MarkerFaceAlpha=1, SizeData=10, ...
                    XJitter="density", XJitterWidth=0.4);
                hold(options.Parent, "off");
            end
            xticks(options.Parent, 1:height(conditions));
            xticklabels(options.Parent, conditions);
            xtickangle(options.Parent, 30);
            if ~isempty(options.Chance) && ~isnan(options.Chance) && options.Chance~=0
                yline(options.Parent, options.Chance, "-", "Chance", LineWidth=1);
            end
            box off
            if nargout>0
                h = h1;
                if nargout>1 && options.Scatter
                    hScatter = h2;
                end
            end
        end
    end
end