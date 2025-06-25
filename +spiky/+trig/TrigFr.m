classdef TrigFr < spiky.trig.Trig & spiky.core.Spikes
    % TRIGFR Firing rate triggered by events

    properties
        Options struct
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Events" "Neuron"];
        end

        function index = getScalarDimension()
            %GETSCALARDIMENSION Get the scalar dimension of the ArrayTable
            %
            %   index: index of the scalar dimension, 0 means no scalar dimension, 
            %       1 means obj(idx) equals obj(idx, :), 2 means obj(idx) equals obj(:, idx), etc.
            index = 3;
        end
    end

    methods
        function obj = TrigFr(spikes, events, window, options)
            arguments
                spikes spiky.core.Spikes = spiky.core.Spikes.empty
                events = [] % (n, 1) double or spiky.core.Events
                window double {mustBeVector} = [0, 1]
                options.HalfWidth double {mustBePositive} = 0.1
                options.Kernel string {mustBeMember(options.Kernel, ["gaussian", "box"])} = "gaussian"
                options.Normalize logical = false
            end
            if nargin==0 || isempty(spikes)
                return
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            t = window(:);
            nEvents = numel(events);
            nT = numel(t);
            if isscalar(t)
                res = options.HalfWidth*2;
            else
                res = t(2)-t(1);
            end
            nNeurons = numel(spikes);
            switch options.Kernel
                case "box"
                    fr = zeros(nT, nEvents, nNeurons);
                    prds = reshape(events'+t, [], 1);
                    prds = spiky.core.Periods([prds-options.HalfWidth prds+options.HalfWidth]);
                    [prds, idcSort] = prds.sort();
                    idcSort2(idcSort) = 1:numel(idcSort);
                    parfor ii = 1:nNeurons
                        [~, c] = spiky.mex.findInPeriods(spikes(ii).Time, prds.Time);
                        c = c(idcSort2)./options.HalfWidth/2;
                        if options.Normalize
                            c = (c-mean(c))./sqrt(mean(c)./options.HalfWidth/2);
                        end
                        fr(:, :, ii) = reshape(c, nT, nEvents);
                    end
                case "gaussian"
                    wAdd = round(options.HalfWidth*3/res);
                    idcAdd = wAdd+1:wAdd+nT;
                    tWide = (t(1)-wAdd*res:res:t(end)+wAdd*res)';
                    kernel = exp(-0.5.*(tWide-(tWide(1)+tWide(end))/2).^2./options.HalfWidth.^2)./...
                        (sqrt(2*pi)*options.HalfWidth)*res;
                    obj = spiky.trig.TrigFr(spikes, events, tWide, ...
                        HalfWidth=res/2, Kernel="box");
                    obj.Data = convn(obj.Data, kernel, "same");
                    if options.Normalize
                        m = mean(obj.Data, [1 2]);
                        obj.Data = (obj.Data-m)./sqrt(m./res);
                    end
                    obj.Data = obj.Data(idcAdd, :, :);
                    obj.Time = t;
                    obj.Window = window;
                    obj.N_ = nT;
                    return
                otherwise
                    error("Unknown kernel %s", options.Kernel);
            end
            obj.Start_ = t(1);
            obj.Step_ = res;
            obj.N_ = nT;
            obj.Data = fr;
            obj.EventDim = 2;
            obj.Events_ = events;
            obj.Window = window;
            obj.Neuron = vertcat(spikes.Neuron);
            obj.Options = options;
        end

        function [m, sd] = getFr(obj, window)
            % GETFR Get mean and standard deviation of the firing rate in a window
            arguments
                obj spiky.trig.TrigFr
                window double = []
            end

            if isempty(obj.Data)
                m = [];
                sd = [];
                return
            end
            if isempty(window)
                window = obj.Time([1 end]);
            end
            is = obj(1).Time>=window(1) & obj(1).Time<=window(2);
            data = obj.Data(is, :, :);
            m = squeeze(mean(data, [1 2]));
            sd = squeeze(std(data, 0, [1 2]));
        end

        function [h, hError] = plotFr(obj, cats, lineSpec, plotOps, options)
            %PLOTFR Plot firing rate
            % 
            %   h = plotFr(obj, idcEvents, cats, plotOps)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %   idcEvents: indices of events to plot
            %   lineSpec: line specification
            %   Name-value arguments:
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       Color, LineWidth, ...: options passed to plot() 
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
                options.Parent matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
            end

            if isempty(options.Parent)
                fg = findall(0, "Type", "Figure");
                if isempty(fg)
                    spiky.plot.fig
                end
                options.Parent = gca;
            end
            n = obj.NEvents;
            idcEvents = options.IdcEvents;
            if isempty(idcEvents)
                idcEvents = 1:n;
            end
            if islogical(idcEvents)
                idcEvents = find(idcEvents);
            end
            data = obj.Data(:, idcEvents)';
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
                [h1, hError1] = spiky.plot.plotError(obj.Time', m, se, lineSpec, plotArgs{:});
            else
                plotArgs = namedargs2cell(plotOps);
                h1 = plot(obj.Time', m, lineSpec, plotArgs{:});
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

        function [h, hMean] = plotScatter(obj, cats, sz, c, mkr, options, plotOps)
            %PLOTSCATTER Plot scatter plot of firing rate
            %
            %   h = plotScatter(obj, cats, sz, c, mkr, plotOps)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %   sz: size of the markers, the second value is used for the mean
            %   c: color of the markers, the second row is used for the mean
            %   mkr: marker type, the second value is used for the mean
            %   Name-value arguments:
            %       PlotMean: plot the mean
            %       IdcNeurons: indices of neurons to plot
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       Subsample: two-element vector where the first value is the number of events in 
            %           each subsample and the second value is the number of subsamples, e.g. [10 5]
            %       LineWidth, ...: options passed to scatter()
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot

            arguments
                obj spiky.trig.TrigFr
                cats categorical = categorical.empty
                sz double = 10
                c = "w"
                mkr string = "o"
                options.PlotMean logical = true
                options.IdcNeurons (1, 2) double = [1 2]
                options.IdcEvents = []
                options.SubSet = []
                options.Subsample double = []
                options.Parent matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
                plotOps.?matlab.graphics.chart.primitive.Scatter
            end

            if isempty(options.Parent)
                options.Parent = gca;
            end
            if isempty(c)
                c = "w";
            end
            if ~isnumeric(c)
                c = validatecolor(c, "multiple");
            end
            if options.PlotMean
                if isscalar(sz)
                    sz = [sz, sz*3];
                end
                if height(c)==1
                    c = [c; c];
                end
                if isscalar(mkr)
                    mkr = [mkr mkr];
                end
            end
            plotArgs = namedargs2cell(plotOps);
            n = size(obj, 2);
            idcEvents = options.IdcEvents;
            if isempty(idcEvents)
                idcEvents = 1:n;
            end
            if islogical(idcEvents)
                idcEvents = find(idcEvents);
            end
            data = permute(obj.Data(1, idcEvents, options.IdcNeurons), [2 3 1]);
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
                [idcGroups, groups] = findgroups(cats);
                nCats = numel(groups);
            else
                cats = ones(height(data), 1);
                nCats = 1;
                [idcGroups, groups] = findgroups(cats);
            end
            if nCats>1
                c1 = spiky.plot.colormap("tab10", nCats, true);
                c2 = c1;
            else
                c1 = c(1, :);
                c2 = c(2, :);
            end
            h1 = gobjects(nCats, 1);
            np = get(options.Parent, "NextPlot");
            hold(options.Parent, "on");
            for ii = 1:nCats
                data1 = data(idcGroups==ii, :);
                if ~isempty(options.Subsample)
                    nSub = options.Subsample(2);
                    nEvents = options.Subsample(1);
                    data1 = reshape(datasample(data1, nEvents*nSub, 1), nEvents, nSub, 2);
                    data1 = permute(mean(data1, 1), [2 3 1]);
                end
                h1(ii) = scatter(options.Parent, data1(:, 1), data1(:, 2), sz(1), c1(ii, :), ...
                    mkr(1), plotArgs{:});
            end
            if options.PlotMean
                m = groupsummary(data, cats, @mean);
                hMean1 = gobjects(nCats, 1);
                for ii = 1:nCats
                    data1 = m(ii, :);
                    hMean1(ii) = scatter(options.Parent, data1(:, 1), data1(:, 2), sz(2), c2(ii, :), ...
                        mkr(2), plotArgs{:});
                end
            end
            if nCats>1
                legend(h1, groups);
            end
            set(options.Parent, "NextPlot", np);
            if nargout>0
                h = h1;
                if nargout>1
                    hMean = hMean1;
                end
            end
        end

        function tuning = tuning(obj, pos, binEdges)
            arguments
                obj spiky.trig.TrigFr
                pos double
                binEdges double
            end

            if height(pos)~=obj.NEvents
                error("The number of positions must be the same as the number of events")
            end
            nDims = width(pos);
            if width(binEdges)~=nDims
                error("The number of bin edges must be the same as the number of dimensions")
            end
            if nDims==1
                tuning = spiky.stat.Tuning(obj(1, :, :), pos, binEdges);
            elseif nDims==2
                tuning = spiky.stat.Tuning2(obj(1, :, :), pos, binEdges(:, 1), binEdges(:, 2));
            else
                error("Only 1D and 2D tuning curves are supported")
            end
        end

        function p = ttest(obj, baseline, window)
            %TTEST Perform t-test on the firing rate in a window
            %
            %   p = ttest(obj, baseline, window)
            %
            %   obj: triggered firing rate object
            %   baseline: baseline firing rate or window
            %   window: window for the analysis
            %
            %   p: p-values

            arguments
                obj spiky.trig.TrigFr
                baseline double = []
                window double = []
            end

            nUnits = size(obj, 3);
            if isempty(baseline)
                baseline = obj.Window([1 end]);
            end
            if isequal(size(baseline), [1, 2])
                % baseline is a window
                m = mean(obj.getFr(baseline), 2);
            elseif ~isequal(length(baseline), nUnits)
                error("Baseline must be a window or equal to the number of neurons")
            else
                m = baseline;
            end
            if isempty(window)
                window = obj.Window([1 end]);
            end
            is = obj.Time>=window(1) & obj.Time<=window(2);
            nT = sum(is);
            p = NaN(nT, nUnits);
            for ii = 1:nUnits
                [~, p(:, ii)] = ttest(obj.Data(is, :, ii), m(ii), Dim=2);
            end
            p = spiky.core.TimeTable(obj.Time(is), p);
        end

        function [ss, proj] = getSubspaces(obj, groupIndices, groups, eventLabels, idcEvents, options)
            %GETBASES Get subspaces for the firing rate
            %
            %   ss = getSubspaces(obj, groupIndices, groups, eventLabels, idcEvents, options)
            %
            %   obj: triggered firing rate object
            %   groupIndices: indices of unit groups
            %   groups: names of unit groups
            %   eventLabels: labels of events, basis vector is calculated over average of each label
            %   group
            %   idcEvents: indices of events to use
            %   Name-value arguments:
            %       KFold: number of folds for cross-validation
            %
            %   ss: subspaces for the firing rate
            %   proj: projection of the firing rate on the subspaces
            arguments
                obj spiky.trig.TrigFr
                groupIndices = []
                groups = []
                eventLabels = []
                idcEvents = []
                options.KFold double = []
            end
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            eventLabels = eventLabels(idcEvents);
            nSubspaces = numel(unique(eventLabels));
            obj.Data = obj.Data(:, idcEvents, :);
            if isempty(options.KFold)
                nFolds = 1;
                indices = {1:numel(eventLabels)};
                eventLabels = {eventLabels};
            else
                nFolds = options.KFold;
                partition = cvpartition(eventLabels, KFold=nFolds);
                indices = arrayfun(@(ii) partition.training(ii), 1:nFolds, UniformOutput=false);
                eventLabels = cellfun(@(idc) eventLabels(idc), indices, UniformOutput=false);
            end
            nT = height(obj);
            nNeurons = size(obj, 3);
            if isempty(groupIndices)
                groupIndices = ones(nNeurons, 1);
            end
            if isnumeric(groupIndices)
                groupIndices = arrayfun(@(x) groupIndices==x, unique(groupIndices), UniformOutput=false);
            end
            nGroups = numel(groupIndices);
            data = cell(nT, nGroups, nFolds);
            for ii = 1:nT
                for jj = 1:nGroups
                    idcGroups = groupIndices{jj};
                    for kk = 1:nFolds
                        idcEvents = indices{kk};
                        d = obj.Data(ii, idcEvents, idcGroups);
                        d = permute(d, [2 3 1]);
                        m = mean(d, 1);
                        v = groupsummary(d, eventLabels{kk}, @mean)-m;
                        data{ii, jj, kk} = spiky.stat.Coords(m', v');
                    end
                end
            end
            data = cell2mat(data);
            ss = spiky.stat.Subspaces(obj.Time, data, groups, groupIndices);
            if nargout>1
                proj = ss.project(obj);
            end
        end

        function pc = pca(obj, groupIndices, groups, eventLabels, idcEvents, options)
            %PCA Perform PCA on the firing rate
            %
            %   pc = pca(obj, options)
            %
            %   obj: triggered firing rate object
            %   groupIndices: indices of unit groups
            %   groups: names of unit groups
            %   eventLabels: labels of events, PCA is peformed over average of each label group
            %   idcEvents: indices of events to use
            %   Name-value arguments:
            %       KFold: number of folds for cross-validation
            %
            %   pc: PCA object
            arguments
                obj spiky.trig.TrigFr
                groupIndices = []
                groups = []
                eventLabels = []
                idcEvents = []
                options.KFold double = []
            end
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            eventLabels = eventLabels(idcEvents);
            obj.Data = obj.Data(:, idcEvents, :);
            if isempty(options.KFold)
                nFolds = 1;
                indices = {1:numel(eventLabels)};
            else
                nFolds = options.KFold;
                partition = cvpartition(eventLabels, KFold=nFolds);
                indices = arrayfun(@(ii) partition.training(ii), 1:nFolds, UniformOutput=false);
                eventLabels = cellfun(@(idc) eventLabels(idc), indices, UniformOutput=false);
            end
            nT = height(obj);
            data = cell(nT, nFolds);
            for ii = 1:nT
                for jj = 1:nFolds
                    data{ii, jj} = permute(obj.Data(ii, indices{jj}, :), [2 3 1]);
                end
            end
            pc = spiky.stat.PCA(obj.Time, data, groupIndices, groups, eventLabels);
        end

        function stats = anova(obj, factors, idcEvents, options)
            % ANOVA Perform analysis of variance
            %
            %   stats = anova(obj, factors)
            %
            %   obj: triggered firing rate object
            %   factors: factors for the input
            %   idcEvents: indices of subset of events to use
            %   options: options for the analysis
            %       Pool: pool the time points
            %
            %   stats: ANOVA models
            arguments
                obj spiky.trig.TrigFr
                factors
                idcEvents = []
                options.Pool = false
            end

            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            factors = factors(idcEvents);
            if iscategorical(factors)
                factors = removecats(factors);
            end
            factors = factors(:);
            t = obj.Time;
            data = obj.Data(:, idcEvents, :);
            if options.Pool
                data = reshape(data, 1, numel(t)*numel(idcEvents), size(data, 3));
                factors = reshape(repmat(factors', numel(t), 1), [], 1);
                t = obj.Events(1);
            end
            stats = spiky.stat.ANOVA(t, factors, data, [obj.Neuron]');
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
            %   Name-value arguments:
            %       Learners: type of learners to use, e.g. "svm", "tree", "knn"
            %       Coding: coding scheme, "onevsall" or "onevsone"
            %       KFold: number of folds for cross-validation
            %       ClassNames: names of the classes
            %       GroupIndices: indices of groups of neurons to use, can be a numeric array or a
            %           cell array
            %       GroupNames: names of the groups of neurons, must be the same length as
            %           GroupIndices
            %
            %   mdl: classification models
            arguments
                obj spiky.trig.TrigFr
                labels
                window double = []
                idcEvents = []
                options.Learners = "svm"
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} = "onevsall"
                options.KFold double = []
                options.ClassNames = []
                options.GroupIndices = []
                options.GroupNames string = string.empty
            end

            if isempty(window)
                window = obj.Window([1 end]);
            end
            is = obj.Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            t = obj.Time(is);
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            labels = labels(idcEvents);
            nUnits = size(obj, 3);
            if isempty(options.GroupIndices)
                options.GroupIndices = {1:nUnits};
            elseif isnumeric(options.GroupIndices) || iscategorical(options.GroupIndices)
                if isempty(options.GroupNames)
                    options.GroupNames = unique(options.GroupIndices);
                end
                options.GroupIndices = arrayfun(@(x) find(x==options.GroupIndices), ...
                    unique(options.GroupIndices), UniformOutput=false);
            elseif iscell(options.GroupIndices)
                if ~all(cellfun(@isnumeric, options.GroupIndices))
                    error("GroupIndices must be numeric")
                end
            else
                error("GroupIndices must be numeric or cell array of numeric arrays")
            end
            nGroups = numel(options.GroupIndices);
            if isempty(options.GroupNames)
                options.GroupNames = strings(nGroups, 1);
            end
            if numel(options.GroupNames)~=nGroups
                error("The number of group names must be the same as the number of groups")
            end
            n = nT*nGroups;
            % if isempty(options.ClassNames)
            %     options.ClassNames = unique(labels);
            % end
            X = permute(obj.Data(is, idcEvents, :), [3 2 1]);
            mdls = cell(nT, nGroups);
            optionsFit = statset(UseParallel=true);
            pb = spiky.plot.ProgressBar(n, "Fitting models", parallel=true);
            parfor ii = 1:n
                [idxT, idxGroup] = ind2sub([nT, nGroups], ii);
                if isempty(options.KFold)
                    mdls{ii} = fitcecoc(X(options.GroupIndices{idxGroup}, :, idxT), labels, ...
                    Coding=options.Coding, ObservationsIn="columns", Learners=options.Learners, ...
                        ClassNames=options.ClassNames, Options=optionsFit);
                else
                    mdls{ii} = fitcecoc(X(options.GroupIndices{idxGroup}, :, idxT), labels, ...
                    Coding=options.Coding, ObservationsIn="columns", Learners=options.Learners, ...
                        ClassNames=options.ClassNames, KFold=options.KFold, Options=optionsFit);
                end
                pb.step
            end
            mdls = spiky.stat.Classifier(t, mdls, options.GroupNames(:), options.GroupIndices);
        end

        function mdls = fitglm(obj, factors, modelspec, window, idcEvents, options)
            % FITGLM Fit a generalized linear model
            %
            %   mdl = fitglm(obj, window, factors)
            %
            %   obj: triggered firing rate object
            %   factors: factors for the input
            %   modelspec: model specification
            %   window: window for the analysis
            %   idcEvents: indices of subset of events to use
            %   options: options for fitglm
            %
            %   mdl: GLMs
            arguments
                obj spiky.trig.TrigFr
                factors
                modelspec string = "linear"
                window double = []
                idcEvents = []
                options.KFold double = []
                options.Distribution string {mustBeMember(options.Distribution, ...
                    ["binomial", "poisson", "normal", "gamma", "inverse gaussian"])} = "normal"
            end

            if isempty(modelspec)
                modelspec = "linear";
            end
            if isempty(window)
                window = obj.Window([1 end]);
            end
            is = obj.Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            t = obj.Time(is);
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            factors = factors(idcEvents);
            % factors = factors(:);
            % if ~istable(factors)
            %     factors = table(factors, VariableNames="X");
            % end
            if isempty(options.KFold)
                nFolds = 1;
                factors = {factors};
                indices = {1:numel(factors)};
                partition = [];
            else
                nFolds = options.KFold;
                partition = cvpartition(factors, KFold=nFolds);
                indices = arrayfun(@(ii) partition.training(ii), 1:nFolds, UniformOutput=false);
                factors = cellfun(@(idc) factors(idc, :), indices, UniformOutput=false);
            end
            nUnits = size(obj, 3);
            n = nT*nUnits*nFolds;
            y = permute(obj.Data(is, idcEvents, :), [2 3 1]);
            mdls = cell(nT, nUnits, nFolds);
            pb = spiky.plot.ProgressBar(n, "Fitting models", parallel=true);
            parfor ii = 1:n
                [idxT, idxUnit, idxFold] = ind2sub([nT, nUnits, nFolds], ii);
                mdls{ii} = fitglm(factors{idxFold}, y(indices{idxFold}, idxUnit, idxT), modelspec, ...
                    Distribution=options.Distribution);
                pb.step
            end
            mdls = spiky.stat.GLM(t, mdls, obj.Neuron);
            mdls.Partition = partition;
        end

        function varargout = subsref(obj, s)
            if strcmp(s(1).type, '()') && isscalar(s(1).subs)
                s(1).subs = [{':', ':'}, s(1).subs];
            end
            [varargout{1:nargout}] = subsref@spiky.core.TimeTable(obj, s);
        end
    end
end