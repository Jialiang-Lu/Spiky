classdef TrigFr
    % TRIGFR Firing rate triggered by events

    properties
        Neuron spiky.core.Neuron
        Data spiky.core.TimeTable
        Time (1, :) double
        Options struct
    end

    methods
        function obj = TrigFr(neuron, data, time, options)
            arguments
                neuron spiky.core.Neuron = spiky.core.Neuron.empty
                data spiky.core.TimeTable = spiky.core.TimeTable.empty
                time (1, :) double = []
                options struct = struct
            end
            obj.Neuron = neuron;
            obj.Data = data;
            obj.Time = time;
            obj.Options = options;
        end

        function [m, se] = getFr(obj, window)
            % GETFR Get mean and standard error of the firing rate in a window
            arguments
                obj spiky.trig.TrigFr
                window double = []
            end

            if isempty(obj(1).Data)
                m = [];
                se = [];
                return
            end
            if isempty(window)
                window = obj(1).Time([1 end]);
            end
            is = obj(1).Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            n = height(obj(1).Data);
            m = zeros(numel(obj), nT);
            if nargout>1
                se = zeros(numel(obj), nT);
            end
            for ii = 1:numel(obj)
                m(ii, :) = mean(obj(ii).Data.Fr(:, is), 1);
                if nargout>1
                    se(ii, :) = std(obj(ii).Data.Fr(:, is), 0, 1)./sqrt(n);
                end
            end
        end

        function [h, hError] = plotFr(obj, cats, lineSpec, plotOps, options)
            % PLOTFR Plot firing rate
            % 
            %   h = plotFr(obj, idcEvents, cats, plotOps)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %   idcEvents: indices of events to plot
            %   lineSpec: line specification
            %   plotOps: options for the plot
            %   options: additional options
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       FaceAlpha: face alpha for the error bars
            %
            %   h: handle to the plot
            %   hError: handle to the error bars

            arguments
                obj spiky.trig.TrigFr
                cats categorical = categorical.empty
                lineSpec string = "k-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.IdcEvents = []
                options.SubSet = []
                options.FaceAlpha double = 0
            end

            fg = findall(0, "Type", "Figure");
            if isempty(fg)
                spiky.plot.fig
            end
            n = obj.Data.Length;
            idcEvents = options.IdcEvents;
            if isempty(idcEvents)
                idcEvents = 1:n;
            end
            if islogical(idcEvents)
                idcEvents = find(idcEvents);
            end
            data = obj.Data.Fr(idcEvents, :);
            if ~isempty(cats)
                cats = cats(:);
                if numel(cats)==n
                    cats = cats(idcEvents);
                elseif numel(cats)~=numel(idcEvents)
                    error("Wrong size of categories")
                end
                if ~isempty(options.SubSet)
                    idcEvents = ismember(cats, options.SubSet);
                    data = data(idcEvents, :);
                    cats = cats(idcEvents);
                end
                [m, names] = groupsummary(data, cats, @mean);
                if options.FaceAlpha>0
                    [se, ~] = groupsummary(data, cats, @std);
                    se = se./sqrt(groupcounts(cats));
                end
            else
                m = mean(data, 1);
                if options.FaceAlpha>0
                    se = std(data, 0, 1)./size(data, 1);
                end
            end
            if isempty(m)
                error("No data to plot")
            end
            if options.FaceAlpha>0
                plotOps.FaceAlpha = options.FaceAlpha;
                plotArgs = namedargs2cell(plotOps);
                [h1, hError1] = spiky.plot.plotError(obj.Time, m, se, lineSpec, plotArgs{:});
            else
                plotArgs = namedargs2cell(plotOps);
                h1 = plot(obj.Time, m, lineSpec, plotArgs{:});
            end
            box off
            xlim(obj.Time([1 end]));
            xline(0, "g", LineWidth=2);
            xlabel("Time (s)");
            ylabel("Firing rate (Hz)");
            if size(m, 1)>1
                legend(h1, names);
            end
            if nargout>0
                h = h1;
                if nargout>1
                    hError = hError1;
                end
            end
        end

        function p = ttest(obj, baseline, window)
            % TTEST Perform t-test on the firing rate in a window
            arguments
                obj spiky.trig.TrigFr
                baseline double
                window double = []
            end

            if isequal(size(baseline), [1, 2])
                % baseline is a window
                m = mean(obj.getFr(baseline), 2);
            elseif ~isequal(size(baseline), size(obj))
                error("Baseline must be a window or have the same size as the object")
            else
                m = baseline;
            end
            if isempty(window)
                window = obj(1).Time([1 end]);
            end
            is = obj(1).Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            p = NaN(numel(obj), nT);
            for ii = 1:numel(obj)
                [~, p(ii, :)] = ttest(obj(ii).Data.Fr(:, is), m(ii));
            end
        end

        function mdls = fitcecoc(obj, labels, window, idcEvents, options)
            % FITCECOC Fit a multiclass error-correcting output codes model
            %
            %   mdl = fitcecoc(obj, window, labels)
            %
            %   obj: triggered firing rate object
            %   labels: labels for the classes
            %   window: window for the analysis
            %   idcEvents: indices of subset of events to use
            %   options: options for fitcecoc
            %
            %   mdl: classification models
            arguments
                obj spiky.trig.TrigFr
                labels
                window double = []
                idcEvents = []
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} = "onevsall"
                options.KFold double = []
                options.ClassNames = []
            end

            if isempty(obj(1).Data)
                mdls = [];
                return
            end
            if isempty(window)
                window = obj(1).Time([1 end]);
            end
            is = obj(1).Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            n = height(obj(1).Data);
            if isempty(idcEvents)
                idcEvents = true(n, 1);
            end
            labels = labels(idcEvents);
            n = numel(labels);
            X = zeros(numel(obj), n, nT);
            for ii = 1:numel(obj)
                X(ii, :, :) = permute(obj(ii).Data.Fr(idcEvents, is), [3 1 2]);
            end
            % if isempty(options.ClassNames)
            %     options.ClassNames = unique(labels);
            % end
            mdls = cell(nT, 1);
            %spiky.plot.timedWaitbar(0, "Fitting models");
            parfor ii = 1:nT
                if isempty(options.KFold)
                    mdls{ii} = fitcecoc(X(:, :, ii), labels, Coding=options.Coding, ObservationsIn="columns", ...
                        ClassNames=options.ClassNames, Options=statset(UseParallel=true));
                else
                    mdls{ii} = fitcecoc(X(:, :, ii), labels, Coding=options.Coding, ObservationsIn="columns", ...
                        ClassNames=options.ClassNames, KFold=options.KFold, Options=statset(UseParallel=true));
                end
                %spiky.plot.timedWaitbar(ii/nT);
                fprintf("Fitting model %d\n", ii);
            end
            %spiky.plot.timedWaitbar([]);
        end
    end
end