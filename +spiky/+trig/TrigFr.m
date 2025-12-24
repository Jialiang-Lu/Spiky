classdef TrigFr < spiky.trig.Trig & spiky.core.Spikes
    %TRIGFR Firing rate triggered by events
    %
    %   First dimension is time, second dimension is events, third dimension is neurons, fourth
    %   dimension is samples if any.

    properties
        Samples (:, 1)
        Options struct
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the EventsTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Events" "Neuron" "Samples"];
        end

        function index = getScalarDimension()
            %GETSCALARDIMENSION Get the scalar dimension of the ArrayTable
            %
            %   index: index of the scalar dimension, 0 means no scalar dimension, 
            %       1 means obj(idx) equals obj(idx, :), 2 means obj(idx) equals obj(:, idx), etc.
            index = 3;
        end

        function [f, g] = multiTimeSoftmaxObjective(theta, X, yInt, Ymat, ...
            pLocal, nLocal, Tlocal, d, Klocal, lambda, lambdaBias, timeAgg, betaTime)
            %MULTITIMESOFTMAXOBJECTIVE Computes multi-time softmax loss and gradient with shared U.
            arguments
                theta (:, 1) double
                X double
                yInt (:, 1) double
                Ymat double
                pLocal (1, 1) double
                nLocal (1, 1) double
                Tlocal (1, 1) double
                d (1, 1) double
                Klocal (1, 1) double
                lambda (1, 1) double
                lambdaBias (1, 1) double
                timeAgg (1, 1) string
                betaTime (1, 1) double
            end

            [U1, W, b] = spiky.trig.TrigFr.unpackThetaMulti(theta, pLocal, d, Klocal, Tlocal);

            fPerTime = zeros(Tlocal, 1);
            gUtime = zeros(pLocal, d, Tlocal);
            gWtime = zeros(d, Klocal, Tlocal);
            gbtime = zeros(Klocal, Tlocal);

            for tt = 1:Tlocal
                Xtt = X(:, :, tt);
                Z = U1' * Xtt; % d-by-n
                S = squeeze(W(:, :, tt))' * Z + b(:, tt); % K-by-n

                [logZ, P] = spiky.trig.TrigFr.logsumexpMat(S);

                nll = -sum(sum(Ymat .* (S - logZ), 1)) / nLocal;
                reg = 0.5 * lambda * sum(W(:, :, tt).^2, "all") ...
                    + 0.5 * lambdaBias * sum(b(:, tt).^2);
                fPerTime(tt) = nll + reg;

                R = (P - Ymat); % K-by-n
                gWtime(:, :, tt) = (Z * R') / nLocal + lambda * W(:, :, tt);
                gbtime(:, tt) = sum(R, 2) / nLocal + lambdaBias * b(:, tt);
                gUtime(:, :, tt) = (Xtt * (W(:, :, tt) * R)') / nLocal;
            end

            if Tlocal <= 1 || timeAgg == "sum"
                f = sum(fPerTime);
                alpha = ones(Tlocal, 1);
            else
                beta = betaTime;
                fMin = min(fPerTime);
                exps = exp(-beta * (fPerTime - fMin));
                Zsum = sum(exps);
                alpha = exps / Zsum;
                f = fMin - (1 / beta) * log(Zsum);
            end

            gU = zeros(pLocal, d);
            gW = zeros(d, Klocal, Tlocal);
            gb = zeros(Klocal, Tlocal);
            for tt = 1:Tlocal
                gU = gU + alpha(tt) * gUtime(:, :, tt);
                gW(:, :, tt) = alpha(tt) * gWtime(:, :, tt);
                gb(:, tt) = alpha(tt) * gbtime(:, tt);
            end

            g = spiky.trig.TrigFr.packThetaMulti(gU, gW, gb, pLocal, d, Klocal, Tlocal);
        end

        function [f, g] = multiTimeSmoothedHingeObjective(theta, X, yInt, ...
            Klocal, pLocal, nLocal, Tlocal, d, lambda, lambdaBias, tau, timeAgg, betaTime)
        %MULTITIMESMOOTHEDHINGEOBJECTIVE Computes multi-time smoothed hinge loss and gradient.
            arguments
                theta (:, 1) double
                X double
                yInt (:, 1) double
                Klocal (1, 1) double
                pLocal (1, 1) double
                nLocal (1, 1) double
                Tlocal (1, 1) double
                d (1, 1) double
                lambda (1, 1) double
                lambdaBias (1, 1) double
                tau (1, 1) double
                timeAgg (1, 1) string
                betaTime (1, 1) double
            end

            [U1, W, b] = spiky.trig.TrigFr.unpackThetaMulti(theta, pLocal, d, Klocal, Tlocal);

            fPerTime = zeros(Tlocal, 1);
            gUtime = zeros(pLocal, d, Tlocal);
            gWtime = zeros(d, Klocal, Tlocal);
            gbtime = zeros(Klocal, Tlocal);

            for tt = 1:Tlocal
                Xtt = X(:, :, tt);
                Z = U1' * Xtt; % d-by-n
                S = squeeze(W(:, :, tt))' * Z + b(:, tt); % K-by-n

                Sy = S(sub2ind([Klocal nLocal], yInt', 1:nLocal));
                M = 1 + S - Sy;
                mask = true(Klocal, nLocal);
                mask(sub2ind([Klocal nLocal], yInt', 1:nLocal)) = false;

                E = zeros(Klocal, nLocal);
                E(mask) = exp(M(mask) / tau);
                sumE = sum(E, 1);
                loss = tau * sum(log(1 + sumE)) / nLocal;

                reg = 0.5 * lambda * sum(W(:, :, tt).^2, "all") ...
                    + 0.5 * lambdaBias * sum(b(:, tt).^2);
                fPerTime(tt) = loss + reg;

                denom = 1 + sumE;
                Alpha = E ./ denom; % K-by-n

                sumAlpha = sum(Alpha, 1);
                Alpha(sub2ind([Klocal nLocal], yInt', 1:nLocal)) = -sumAlpha;

                gWtime(:, :, tt) = (Z * Alpha') / nLocal + lambda * W(:, :, tt);
                gbtime(:, tt) = sum(Alpha, 2) / nLocal + lambdaBias * b(:, tt);
                gUtime(:, :, tt) = (Xtt * (W(:, :, tt) * Alpha)') / nLocal;
            end

            if Tlocal <= 1 || timeAgg == "sum"
                f = sum(fPerTime);
                alpha = ones(Tlocal, 1);
            else
                beta = betaTime;
                fMin = min(fPerTime);
                exps = exp(-beta * (fPerTime - fMin));
                Zsum = sum(exps);
                alpha = exps / Zsum;
                f = fMin - (1 / beta) * log(Zsum);
            end

            gU = zeros(pLocal, d);
            gW = zeros(d, Klocal, Tlocal);
            gb = zeros(Klocal, Tlocal);
            for tt = 1:Tlocal
                gU = gU + alpha(tt) * gUtime(:, :, tt);
                gW(:, :, tt) = alpha(tt) * gWtime(:, :, tt);
                gb(:, tt) = alpha(tt) * gbtime(:, tt);
            end

            g = spiky.trig.TrigFr.packThetaMulti(gU, gW, gb, pLocal, d, Klocal, Tlocal);
        end

        function [c, ceq] = orthoConstraintsMulti(theta, pLocal, d, Klocal, Tlocal)
        %ORTHOCONSTRAINTSMULTI Enforces U' * U = I as nonlinear equality constraints.
            arguments
                theta (:, 1) double
                pLocal (1, 1) double
                d (1, 1) double
                Klocal (1, 1) double %#ok<INUSD>
                Tlocal (1, 1) double %#ok<INUSD>
            end

            [U1, ~, ~] = spiky.trig.TrigFr.unpackThetaMulti(theta, pLocal, d, Klocal, Tlocal);
            G = U1' * U1 - eye(d);
            c = [];
            ceq = G(:);
        end

        function theta = packThetaMulti(U, W, b, pLocal, d, Klocal, Tlocal)
        %PACKTHETAMULTI Packs U, W, b into a single parameter vector.
            arguments
                U double
                W double
                b double
                pLocal (1, 1) double
                d (1, 1) double
                Klocal (1, 1) double
                Tlocal (1, 1) double
            end

            theta = zeros(pLocal * d + d * Klocal * Tlocal + Klocal * Tlocal, 1);
            idx = 0;
            theta(idx + (1:(pLocal * d))) = U(:);
            idx = idx + pLocal * d;
            theta(idx + (1:(d * Klocal * Tlocal))) = W(:);
            idx = idx + d * Klocal * Tlocal;
            theta(idx + (1:(Klocal * Tlocal))) = b(:);
        end

        function [U, W, b] = unpackThetaMulti(theta, pLocal, d, Klocal, Tlocal)
        %UNPACKTHETAMULTI Unpacks a parameter vector into U, W, b.
            arguments
                theta (:, 1) double
                pLocal (1, 1) double
                d (1, 1) double
                Klocal (1, 1) double
                Tlocal (1, 1) double
            end

            idx = 0;
            U = reshape(theta(idx + (1:(pLocal * d))), pLocal, d);
            idx = idx + pLocal * d;
            W = reshape(theta(idx + (1:(d * Klocal * Tlocal))), d, Klocal, Tlocal);
            idx = idx + d * Klocal * Tlocal;
            b = reshape(theta(idx + (1:(Klocal * Tlocal))), Klocal, Tlocal);
        end

        function [logZ, P] = logsumexpMat(S)
        %LOGSUMEXPMAT Computes log-sum-exp normalization and softmax probabilities.
            arguments
                S double
            end

            Smax = max(S, [], 1);
            E = exp(S - Smax);
            Z = sum(E, 1);
            logZ = Smax + log(Z);
            P = E ./ Z;
        end
    end

    methods
        function obj = TrigFr(start, step, fr, events, window, neuron, samples)
            %TRIGFR Constructor for TrigFr class
            %   obj = TrigFr(start, step, fr, events, window, neuron, samples)
            arguments
                start double = NaN
                step double = NaN
                fr double = double.empty(0, 0, 0)
                events (:, 1) = NaN(width(fr), 1)
                window double {mustBeVector} = [0, 1]
                neuron spiky.core.Neuron = spiky.core.Neuron
                samples (:, 1) = NaN(size(fr, 4), 1)
            end
            obj.Start_ = start;
            obj.Step_ = step;
            obj.N_ = size(fr, 1);
            obj.Data = fr;
            obj.EventDim = 2;
            obj.Events_ = events;
            obj.Window = window;
            obj.Neuron = neuron;
            obj.Samples = samples;
        end

        function [m, sd] = getFr(obj, window)
            %GETFR Get mean and standard deviation of the firing rate in a window
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

        function [m, se] = getGroupMean(obj, cats)
            %GETGROUPMEAN Get group mean and standard error of the firing rate
            %   [m, se] = getGroupMean(obj, cats)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %
            %   m: mean firing rate for each category
            %   se: standard error of the mean for each category

            arguments
                obj spiky.trig.TrigFr
                cats (:, 1) = categorical(strings(obj.NEvents, 1))
            end

            data = permute(obj.Data, [2 1 3 4]);
            % [m1, names] = groupsummary(data, cats, @mean);
            names = unique(cats);
            m1 = NaN(height(names), size(data, 2), size(data, 3), size(data, 4));
            for ii = 1:height(names)
                idc = cats==names(ii);
                if any(idc)
                    m1(ii, :, :, :) = mean(data(idc, :, :, :), 1);
                end
            end
            m = obj;
            m.Data = permute(m1, [2 1 3 4]);
            m.Events = names;
            if nargout>1
                % [se1, ~] = groupsummary(data, cats, @std);
                % se1 = se1./sqrt(groupcounts(cats));
                se1 = NaN(height(names), size(data, 2), size(data, 3), size(data, 4));
                for ii = 1:height(names)
                    idc = cats==names(ii);
                    if any(idc)
                        se1(ii, :, :, :) = std(data(idc, :, :, :), 0, 1)./sqrt(sum(idc));
                    end
                end
                se = obj;
                se.Data = permute(se1, [2 1 3 4]);
                se.Events = names;
            end
        end

        function groupedFr = group(obj, options)
            %GROUP Group the triggered firing rate by neuron region
            %   groupedFr = group(obj, options)
            %
            %   obj: triggered firing rate object
            %   Name-value arguments:
            %       GroupTime: group the time dimension as well
            %       Permute: permutation of the dimensions
            %
            %   groupedFr: grouped triggered firing rate object
            arguments
                obj spiky.trig.TrigFr
                options.GroupTime logical = false
                options.Permute double = 1:5
            end
            [groupNames, ~, idcGroups] = unique(obj.Neuron.Region);
            groupIndices = arrayfun(@(x) find(idcGroups==x), unique(idcGroups), ...
                UniformOutput=false);
            nGroups = numel(groupNames);
            if options.GroupTime
                data = cell(height(obj), nGroups);
                for ii = 1:height(obj)
                    for jj = 1:nGroups
                        data{ii, jj} = permute(obj.Data(ii, :, groupIndices{jj}, :, :), options.Permute);
                    end
                end
                t = obj.Time;
            else
                data = cell(1, nGroups);
                for jj = 1:nGroups
                    data{1, jj} = permute(obj.Data(:, :, groupIndices{jj}, :, :), options.Permute);
                end
                t = 0;
            end
            groupedFr = spiky.stat.GroupedStat(t, data, groupNames, groupIndices);
        end

        function obj = flatten(obj)
            %FLATTEN Flatten the triggered firing rate object to 1D
            %   obj = flatten(obj)
            %
            %   obj: flattened triggered firing rate object

            data = reshape(obj.Data, height(obj.Data)*width(obj.Data), 1, ...
                size(obj.Data, 3), size(obj.Data, 4));
            t = reshape(obj.Time(:)+obj.Events(:)', [], 1);
            obj.Time = t;
            obj.Data = data;
            obj.Events = 0;
        end

        function [h, hError] = plotFr(obj, cats, lineSpec, plotOps, options)
            %PLOTFR Plot firing rate
            % 
            %   h = plotFr(obj, cats, lineSpec, ...)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %   idcEvents: indices of events to plot
            %   lineSpec: line specification
            %   Name-value arguments:
            %       Grouping: grouping of the data, can be "Cats", "Events", 
            %           or "Neurons"
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       Color, LineWidth, ...: options passed to plot() 
            %       FaceAlpha: face alpha for the error bars
            %       Parent: parent axes for the plot
            %
            %   h: handle to the plot
            %   hError: handle to the error bars

            arguments
                obj spiky.trig.TrigFr
                cats = zeros(obj.NEvents, 1)
                lineSpec string = "-"
                plotOps.?matlab.graphics.chart.primitive.Line
                options.Grouping string {mustBeMember(options.Grouping, ["Cats", "Events", "Neurons"])} = "Cats"
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
                case "Neurons"
                    data = mean(permute(obj.Data(:, idcEvents, :), [3 1 2]), 3);
                    cats = (1:height(data))';
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
            if ~strcmp(options.Grouping, "Cats")
                set(h1, Color=h1(1).Color);
                if ~isempty(hError1)
                    set(hError1, FaceColor=h1(1).Color, EdgeColor="none");
                end
            else
                if size(m, 1)>1
                    legend(h1, names);
                end
            end
            box off
            xlim(obj.Time([1 end]));
            l = xline(0, "g", LineWidth=1);
            xlabel("Time (s)");
            ylabel("Firing rate (Hz)");
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

        function h = plotEllipsoid(obj, cats, options, plotOps)
            %PLOTELLIPSOID Plot ellipsoid of the firing rate
            %
            %   h = plotEllipsoid(obj, cats, options, plotOps)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events
            %   Name-value arguments:
            %       IdcNeurons: indices of neurons to plot
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       Parent: parent axes for the plot
            %       NumFaces: number of Faces to use for the ellipsoid
            %       LineWidth, ...: options passed to surf()
            %
            %   h: handle to the plot

            arguments
                obj spiky.trig.TrigFr
                cats categorical = obj.Events
                options.IdcNeurons (1, 3) double = [1 2 3]
                options.IdcEvents = 1:width(obj.Data)
                options.SubSet = unique(cats)
                options.Parent matlab.graphics.axis.Axes = gca
                options.NumFaces double {mustBePositive} = 20
                plotOps.?matlab.graphics.chart.primitive.Surface
            end

            % if ~isfield(plotOps, "FaceAlpha")
            %     plotOps.FaceAlpha = 0.5;
            % end
            if ~isfield(plotOps, "EdgeColor")
                plotOps.EdgeColor = "none";
            end
            idcEvents = options.IdcEvents;
            data = permute(obj.Data(1, idcEvents, options.IdcNeurons), [2 3 1]);
            if numel(cats)==width(obj.Data)
                cats = cats(idcEvents);
            end
            idcEvents = ismember(cats, options.SubSet);
            data = data(idcEvents, :);
            cats = cats(idcEvents);
            [idcGroups, groups] = findgroups(cats);
            nCats = numel(groups);
            h1 = gobjects(nCats, 1);
            colors = colororder(options.Parent);
            npState = options.Parent.NextPlot;
            hold(options.Parent, "on");
            for ii = 1:nCats
                data1 = data(idcGroups==ii, :);
                if size(data1, 1)<=3
                    warning("Not enough data to plot ellipsoid for group %s", string(groups(ii)));
                    continue;
                end
                mu = mean(data1, 1);
                C = cov(data1, 1);
                [V, D] = eig(C);
                se = sqrt(diag(D)./height(data1));
                [x, y, z] = ellipsoid(0, 0, 0, se(1), se(2), se(3), options.NumFaces);
                xyz = V*[x(:)'; y(:)'; z(:)'];
                x = reshape(xyz(1, :), size(x))+mu(1);
                y = reshape(xyz(2, :), size(y))+mu(2);
                z = reshape(xyz(3, :), size(z))+mu(3);
                plotOps.FaceColor = colors(mod(ii-1, height(colors))+1, :);
                plotArgs = namedargs2cell(plotOps);
                h1(ii) = surf(options.Parent, x, y, z, plotArgs{:});
            end
            if nCats>1
                legend(h1, groups);
            end
            options.Parent.NextPlot = npState;
            if nargout>0
                h = h1;
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

        function obj = xcorr(obj, obj2)
            %XCORR Cross-correlation of the firing rate
            %
            %   r = xcorr(obj, obj2)
            %
            %   obj: triggered firing rate object
            %   obj2: second triggered firing rate object
            %
            %   obj: cross-correlation of the firing rate

            arguments
                obj spiky.trig.TrigFr
                obj2 spiky.trig.TrigFr
            end
            
            assert(size(obj, 3)==size(obj2, 3), "The number of neurons must be the same");
            assert(width(obj)==1 || width(obj2)==1, "One of the objects must have only one event");
            if width(obj2)==1
                idc1 = (1:width(obj))';
                idc2 = ones(width(obj), 1);
                events = obj.Events;
            else
                idc1 = ones(width(obj2), 1);
                idc2 = (1:width(obj2))';
                events = obj2.Events;
            end
            data1 = obj.Data;
            data2 = flipud(obj2.Data);
            nT1 = height(data1);
            nT2 = height(data2);
            data0 = zeros(nT1+nT2-1, numel(idc1), size(obj, 3));
            pb = spiky.plot.ProgressBar(size(obj, 3), "Calculating cross-correlation", Parallel=true);
            parfor ii = 1:size(obj, 3)
                d = zeros(nT1+nT2-1, numel(idc1));
                for jj = 1:numel(idc1)
                    d(:, jj) = conv(data1(:, idc1(jj), ii), data2(:, idc2(jj), ii), "full");
                end
                data0(:, :, ii) = d;
                pb.step
            end
            data = zeros(nT1, numel(idc1), size(obj, 3));
            t1 = obj2.Time(1);
            t2 = obj2.Time(2);
            offset = nT2+round(t1/(t2-t1)); % First index in the full convolution to keep
            idcData0 = (1:nT1)+offset-1; % Indices in the full convolution
            isValid = idcData0>=1 & idcData0<=nT1+nT2-1;
            data(isValid, :, :) = data0(idcData0(isValid), :, :);
            obj.Data = data;
            obj.Events = events;
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
            p = spiky.core.EventsTable(obj.Time(is), p);
        end

        function [ss, proj] = getSubspaces(obj, cats, idcEvents, options)
            %GETBASES Get subspaces for the firing rate
            %
            %   ss = getSubspaces(obj, groupIndices, groups, cats, idcEvents, options)
            %
            %   obj: triggered firing rate object
            %   cats: categories of events, axes of the subspaces are the means of each category
            %   idcEvents: indices of events to use
            %   Name-value arguments:
            %       SubSet: subset of categories to use for the bases, origin is calculated over all
            %           events regardless of the subset
            %       KFold: number of folds for cross-validation
            %       PCA: number of PCA dimensions to keep, 0 means no PCA
            %       Normalize: normalize the basis vectors to unit length
            %
            %   ss: subspaces for the firing rate
            %   proj: projection of the firing rate on the subspaces
            arguments
                obj spiky.trig.TrigFr
                cats = []
                idcEvents = []
                options.Subset = []
                options.KFold double = []
                options.PCA double = 0 % number of PCA dimensions to keep, 0 means no PCA
                options.Normalize logical = false % normalize the basis vectors to unit length
            end
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            cats = cats(idcEvents);
            labelNames = unique(cats, "sorted");
            nSubspaces = numel(unique(cats));
            obj.Data = obj.Data(:, idcEvents, :);
            obj.Events = cats;
            if isempty(options.KFold)
                nFolds = 1;
                indices = {1:numel(cats)};
                cats = {cats};
            else
                nFolds = options.KFold;
                partition = cvpartition(cats, KFold=nFolds);
                indices = arrayfun(@(ii) partition.training(ii), 1:nFolds, UniformOutput=false);
                cats = cellfun(@(idc) cats(idc), indices, UniformOutput=false);
            end
            nT = height(obj);
            nNeurons = size(obj, 3);
            groupIndices = obj.Neuron.Region;
            groups = unique(groupIndices);
            groupIndices = arrayfun(@(x) find(groupIndices==x), groups, UniformOutput=false);
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
                        [v, g] = groupsummary(d, cats{kk}, @mean);
                        v = v-m;
                        if ~isempty(options.Subset)
                            v = v(ismember(labelNames, options.Subset), :);
                        end
                        if options.PCA>0
                            [coeff, ~, ~] = pca(d-m, Centered="off", NumComponents=options.PCA);
                            v = coeff(:, 1:min(nSubspaces, size(coeff, 2)))';
                            labelNames = compose("PC%d", 1:size(v, 1));
                        end
                        if options.Normalize
                            v = v./vecnorm(v, 2, 2);
                        end
                        data{ii, jj, kk} = spiky.stat.Coords(m', v', obj.Neuron(idcGroups), labelNames);
                    end
                end
            end
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
            %ANOVA Perform analysis of variance
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

            if height(obj)>1 && width(obj)==1
                % if obj is a EventsTable with multiple time points, convert it to multiple events
                obj.Data = permute(obj.Data, [2 1 3]);
                obj.Events_ = obj.Time;
                obj.Time = obj.Time(1);
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
            stats = spiky.stat.ANOVA(t, factors, data, obj.Neuron);
        end

        function mdl = fscnca(obj, labels, varargin)
            %FSCNCA Fit a feature selection and classification model
            %   mdl = fscnca(obj, labels, window, idcEvents, options)
            %
            %   obj: triggered firing rate object
            %
            %   mdl: feature selection and classification model
            arguments
                obj spiky.trig.TrigFr
                labels
            end
            arguments (Repeating)
                varargin
            end

            labels = labels(:);
            data = reshape(obj.Data, [], size(obj, 3));
            assert(size(data, 1)==numel(labels), "Number of labels must match number of events");
            mdl = fscnca(data, labels, varargin{:});
        end

        function mdls = fitcecoc(obj, labels, window, idcEvents, options)
            %FITCECOC Fit a multiclass error-correcting output codes model
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
            %       FitPosterior: fit posterior probabilities
            %       ClassNames: names of the classes
            %       GroupIndices: indices of groups of neurons to use, can be a numeric array or a
            %           cell array
            %       GroupNames: names of the groups of neurons, must be the same length as
            %           GroupIndices
            %       Conditions: conditions, must be the same length as labels. One slice of
            %           classifier will be trained for each unique condition value
            %       TimeDependent: whether to fit one model per time point
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
                options.Partition = []
                options.FitPosterior logical = false
                options.ClassNames = []
                options.GroupIndices = []
                options.GroupNames string = string.empty
                options.Conditions categorical = categorical(zeros(size(labels)))
                options.TimeDependent logical = true
            end

            if size(obj.Data, 4)>1 % Data is already partitioned
                nFolds = size(obj.Data, 4);
                assert(~isempty(options.Partition), ...
                    "Partition must be provided when data is already partitioned");
                assert(nFolds==options.Partition.NumTestSets, ...
                    "Partition size must match the fourth dimension of the data");
                mdls = cell(nFolds, 1);
                objs = arrayfun(@(ii) subsref(obj, substruct("()", {':', ':', ':', ii})), ...
                    (1:nFolds)', UniformOutput=false);
                for ii = 1:nFolds
                    options1 = options;
                    options1.Partition = cvpartition(CustomPartition=options.Partition.test(ii));
                    optionsCell = namedargs2cell(options1);
                    mdls{ii} = objs{ii}.fitcecoc(labels, window, idcEvents, ...
                        optionsCell{:});
                end
                mdls = cat(3, mdls{:});
                return
            end
            if isempty(window)
                window = obj.Time([1 end]);
            end
            is = obj.Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            t = obj.Time(is);
            if ~options.TimeDependent
                nT = 1;
                t = 0;
            end
            if isempty(idcEvents)
                idcEvents = 1:width(obj.Data);
            elseif islogical(idcEvents)
                idcEvents = find(idcEvents);
            end
            if numel(labels)>numel(idcEvents)
                labels = labels(idcEvents);
            end
            labels = removecats(categorical(labels));
            nUnits = size(obj, 3);
            if isempty(options.GroupIndices)
                [options.GroupNames, ~, idcGroups] = unique(obj.Neuron.Region);
                options.GroupIndices = arrayfun(@(x) find(idcGroups==x), unique(idcGroups), ...
                    UniformOutput=false);
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
            if isempty(options.Conditions)
                conditions = categorical(zeros(numel(idcEvents), 1));
            elseif numel(options.Conditions)>=numel(idcEvents) && ...
                max(idcEvents)<=numel(options.Conditions)
                options.Conditions = options.Conditions(idcEvents);
            elseif numel(options.Conditions)~=numel(idcEvents)
                error("Conditions must be the same length as labels or events")
            end
            options.Conditions = removecats(options.Conditions);
            conditionSet = categories(options.Conditions, OutputType="string");
            nConditions = numel(conditionSet);
            n = nT*nGroups*nConditions;
            % if isempty(options.ClassNames)
            %     options.ClassNames = unique(labels(~ismissing(labels)));
            % end
            X = permute(obj.Data(is, idcEvents, :), [3 2 1]);
            nT1 = size(X, 3);
            mdls = cell(nT, nGroups, nConditions);
            optionsFit = statset(UseParallel=true);
            pb = spiky.plot.ProgressBar(n, "Fitting models", parallel=true);
            parfor ii = 1:n
                [idxT, idxGroup, idxCondition] = ind2sub([nT, nGroups, nConditions], ii);
                idcCondition = options.Conditions==conditionSet(idxCondition);
                idcNeurons = options.GroupIndices{idxGroup};
                if options.TimeDependent
                    X1 = X(idcNeurons, idcCondition, idxT);
                    y1 = labels(idcCondition);
                else
                    X1 = reshape(X(idcNeurons, idcCondition, :), numel(idcNeurons), []);
                    y1 = repmat(labels(idcCondition), nT1, 1);
                end
                if isempty(options.Partition) && ~isempty(options.KFold)
                    if options.TimeDependent
                        cv = cvpartition(labels(idcCondition), KFold=options.KFold);
                    else
                        cv1 = cvpartition(labels(idcCondition), KFold=options.KFold);
                        idcTest = repmat(cv1.test("all"), nT1, 1);
                        cv = cvpartition(CustomPartition=idcTest);
                    end
                elseif ~isempty(options.Partition)
                    cv = options.Partition;
                else
                    cv = [];
                end
                if isempty(cv)
                    mdls{ii} = fitcecoc(X1, y1, ...
                        Coding=options.Coding, ObservationsIn="columns", Learners=options.Learners, ...
                        ClassNames=options.ClassNames, Options=optionsFit, Verbose=1, ...
                        FitPosterior=options.FitPosterior, Prior="uniform");
                elseif options.TimeDependent
                    mdls{ii} = fitcecoc(X1, y1, ...
                        Coding=options.Coding, ObservationsIn="columns", Learners=options.Learners, ...
                        ClassNames=options.ClassNames, CVPartition=cv, Options=optionsFit, ...
                        Verbose=1, FitPosterior=options.FitPosterior, Prior="uniform");
                end
                pb.step
            end
            mdls = spiky.stat.Classifier(t, mdls, categorical(options.GroupNames(:)), ...
                options.GroupIndices, conditionSet);
        end

        function [classifier, subspaces, metrics] = learnDiscriminantSubspace(obj, labels, ...
            nDims, options)
            %LEARNDISCRIMINANTSUBSPACE Learn low-dimensional subspaces U that minimize
            %   classification risk AFTER projection, jointly with classifier parameters
            %   in the projected space, with a single shared subspace over time.
            %
            %   [classifier, subspaces, metrics] = LEARNDISCRIMINANTSUBSPACE( ...
            %       obj, labels, nDims, Name=Value, ...)
            %
            %   obj: nTime x nEvents x nNeurons data (spiky.trig.TrigFr)
            %   labels: nEvents x 1 categorical labels (same for all time points)
            %   nDims:  number of dimensions for the subspace
            %
            %   Name-Value arguments for subspace learning:
            %       EventIndices: indices of events to use (default: all events)
            %       Window: time window for learning, relative to trigger (default: [-Inf Inf])
            %       Type: type of loss function, either "softmax" or "hinge"
            %           (default: "softmax")
            %       Lambda: L2 penalty on classifier weights W (default: 1e-3)
            %       LambdaBias: L2 penalty on classifier bias b (default: 0)
            %       Tau: smoothness (temperature) for smoothed hinge loss (default: 0.5)
            %       Init: initialization for U, either "pca", "lda", or "random"
            %           (default: "lda")
            %       Solver: fmincon algorithm, either "sqp" or "interior-point"
            %           (default: "sqp")
            %       MaxIter: maximum number of fmincon iterations (default: 500)
            %
            %   Name-Value arguments for classifier training:
            %       Learners: base learners for ECOC, "svm" or "logistic" (default: "svm")
            %       Coding: coding scheme for ECOC, "onevsall" or "onevsone"
            %           (default: "onevsall")
            %       KFold: number of CV folds, empty for no CV (default: [])
            %       FitPosterior: if true, fit posterior probabilities (default: false)
            %
            %   classifier: spiky.stat.Classifier trained on projected data
            %   subspaces: spiky.stat.Subspaces object, with a single U shared over time
            %       for each group (brain region)
            %   metrics: spiky.stat.GroupedStat with struct fields:
            %       .TrainLoss, .TrainAcc, .Confusion (peak over time)

            arguments
                obj spiky.trig.TrigFr % nTime x nEvents x nNeurons data
                labels (:, 1) categorical % nEvents x 1 labels
                nDims (1, 1) double
                options.EventIndices = 1:obj.NEvents
                options.Window (1, 2) double = [-Inf Inf]
                options.Type string {mustBeMember(options.Type, ["softmax" "hinge"])} = "softmax"
                options.Lambda double = 1e-3
                options.LambdaBias double = 0
                options.Tau double = 0.5
                options.Init string {mustBeMember(options.Init, ["pca" "lda" "random"])} = "lda"
                options.Solver string {mustBeMember(options.Solver, ["sqp" "interior-point"])} = "sqp"
                options.MaxIter double = 500
                options.Learners = "svm"
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} ...
                    = "onevsall"
                options.KFold double = []
                options.Partition = []
                options.FitPosterior logical = false
                options.EventDim string {mustBeMember(options.EventDim, ["rows", "columns"])} = "columns"
            end

            trigFr = subsref(obj, substruct("()", {':', options.EventIndices, ':'}));
            labels = removecats(labels);
            if options.EventDim=="columns"
                nEvents = width(trigFr);
            else
                nEvents = height(trigFr);
            end
            if nEvents < numel(labels)
                labels = labels(options.EventIndices);
            end

            %% Basic checks and grouping by brain region
            assert(nEvents == numel(labels), ...
                "The number of events in trigFr and labels must be the same");

            groupedFr = subsref(trigFr, substruct("()", { ...
                trigFr.Time >= options.Window(1) & trigFr.Time <= options.Window(2), ':', ':'}));
            nT = height(trigFr);
            if options.EventDim=="columns"
                groupedFr = groupedFr.group(Permute=[3 2 1]); % each cell: nNeurons x nEvents x nTime
            else
                groupedFr = groupedFr.group(Permute=[3 1 2]); % each cell: nNeurons x nTime x nEvents
            end
            nGroups = width(groupedFr);
            if isempty(options.KFold) && isempty(options.Partition)
                isTrain = true(size(labels));
                Xs = groupedFr.Data;
                nFolds = 1;
            else
                if isempty(options.Partition)
                    options.Partition = cvpartition(labels, KFold=options.KFold);
                else
                    options.KFold = options.Partition.NumTestSets;
                end
                isTrain = options.Partition.training("all");
                nFolds = options.KFold;
                Xs = cell(1, nGroups, nFolds);
                for ii = 1:nGroups
                    for jj = 1:nFolds
                        idcTrain = options.Partition.training(jj);
                        Xs{1, ii, jj} = groupedFr.Data{ii}(:, idcTrain, :);
                    end
                end
            end

            %% Convert labels to integer codes 1..K and one-hot matrix Y (K x nEvents)
            yNumeric = double(labels);
            classes = unique(yNumeric(:)');
            K = numel(classes);
            assert(all(classes == 1:K), ...
                "Labels must map to consecutive integer codes 1..K internally");
            nEvents = numel(labels);
            Y = zeros(K, nEvents);
            Y(sub2ind([K nEvents], yNumeric', 1:nEvents)) = 1;

            subspaces = cell(1, nGroups, nFolds);
            metrics = cell(1, nGroups, nFolds);

            pb = spiky.plot.ProgressBar(nGroups*nFolds, "Learning discriminant subspaces", ...
                Parallel=false);

            %% Learn one shared subspace per group (brain region)
            for ii = 1:nGroups*nFolds
                [~, idxFold] = ind2sub([nGroups, nFolds], ii);
                idcFold = isTrain(:, idxFold);
                X = Xs{ii}; % nNeurons x nEvents x nTime
                d = nDims;
                [p, n, Tlocal] = size(X);

                % ----- per-group shared-subspace optimization (inlined) -----
                yInt = yNumeric(idcFold);
                Ymat = Y(:, idcFold);
                Klocal = K;
                opts = options;

                pLocal = p;
                nLocal = n;

                lambda = opts.Lambda;
                lambdaBias = opts.LambdaBias;

                % Single-time case: behave like original implementation
                if Tlocal <= 1
                    timeAgg = "sum";
                else
                    % Soft-min over time to emphasize peak (best time point)
                    timeAgg = "softmin";
                end
                betaTime = 5; % larger => closer to hard min over time

                % ---------- Initialize U (p x d) ----------
                switch opts.Init
                    case "lda"
                        if Tlocal > 1
                            Xmean = mean(X, 3); % average over time: p x n
                        else
                            Xmean = X(:, :, 1);
                        end

                        % LDA initializer (regularized)
                        Xmat = Xmean;
                        [pLocalLda, nLocalLda] = size(Xmat);
                        classesLocal = unique(yInt(:)');
                        KlocalLda = numel(classesLocal);
                        mu = mean(Xmat, 2);

                        S_B = zeros(pLocalLda, pLocalLda);
                        S_W = zeros(pLocalLda, pLocalLda);

                        for kk = 1:KlocalLda
                            idx = (yInt == classesLocal(kk));
                            Xk = Xmat(:, idx);
                            nk = size(Xk, 2);
                            if nk == 0
                                continue
                            end
                            muk = mean(Xk, 2);
                            S_B = S_B + (nk / nLocalLda) * (muk - mu) * (muk - mu)';
                            Xkc = Xk - muk;
                            if nk > 1
                                S_W = S_W + (nk / nLocalLda) * (Xkc * Xkc' / (nk - 1));
                            end
                        end

                        epsSw = 1e-3 * trace(S_W) / max(pLocalLda, 1);
                        S_W = S_W + epsSw * eye(pLocalLda);

                        [Vw, Dw] = eig(S_W, "vector");
                        Dw = max(Dw, 1e-12);
                        Swm12 = Vw * diag(1 ./ sqrt(Dw)) * Vw';
                        B = Swm12 * S_B * Swm12;

                        nVec = min([d, KlocalLda - 1, pLocalLda]);
                        if nVec < 1
                            [Qtmp, ~] = qr(randn(pLocalLda, d), 0);
                            U0 = Qtmp(:, 1:d);
                        else
                            [V, ~] = eigs(B, nVec, "largestreal", ...
                                "SubSpaceDimension", min(2 * nVec + 2, pLocalLda));
                            Utmp = Swm12 * V;

                            [Q, ~] = qr(Utmp, 0);
                            U0 = Q(:, 1:min([d, size(Q, 2)]));
                            if size(U0, 2) < d
                                [Q2, ~] = qr(randn(pLocalLda, d - size(U0, 2)), 0);
                                U0 = orth([U0, Q2(:, 1:(d - size(U0, 2)))]);
                            end
                        end

                    case "pca"
                        if Tlocal > 1
                            Xcat = reshape(X, pLocal, nLocal * Tlocal);
                        else
                            Xcat = X(:, :, 1);
                        end
                        Xc = Xcat - mean(Xcat, 2);
                        [Up, ~, ~] = svd(Xc, "econ");
                        U0 = Up(:, 1:d);

                    case "random"
                        [Q, ~] = qr(randn(pLocal, d), 0);
                        U0 = Q;
                end

                % Initialize classifier parameters in projected space
                W0 = zeros(d, Klocal, Tlocal);
                b0 = zeros(Klocal, Tlocal);

                theta0 = spiky.trig.TrigFr.packThetaMulti(U0, W0, b0, pLocal, d, Klocal, Tlocal);

                % Objective across time with shared U
                switch opts.Type
                    case "softmax"
                        obj1 = @(theta) spiky.trig.TrigFr.multiTimeSoftmaxObjective(theta, X, yInt, Ymat, ...
                            pLocal, nLocal, Tlocal, d, Klocal, ...
                            lambda, lambdaBias, timeAgg, betaTime);
                    case "hinge"
                        obj1 = @(theta) spiky.trig.TrigFr.multiTimeSmoothedHingeObjective(theta, X, yInt, ...
                            Klocal, pLocal, nLocal, Tlocal, d, ...
                            lambda, lambdaBias, opts.Tau, timeAgg, betaTime);
                end

                nonlcon = @(theta) spiky.trig.TrigFr.orthoConstraintsMulti(theta, pLocal, d, Klocal, Tlocal);

                fminconOpts = optimoptions("fmincon", ...
                    "Algorithm", opts.Solver, ...
                    "SpecifyObjectiveGradient", true, ...
                    "SpecifyConstraintGradient", false, ...
                    "MaxIterations", opts.MaxIter, ...
                    "Display", "final-detailed", ...
                    "UseParallel", true, ...
                    "ConstraintTolerance", 1e-8, ...
                    "OptimalityTolerance", 1e-6, ...
                    "StepTolerance", 1e-10);

                problem = struct( ...
                    "objective", obj1, ...
                    "x0", theta0, ...
                    "nonlcon", nonlcon, ...
                    "solver", "fmincon", ...
                    "options", fminconOpts, ...
                    "Aineq", [], "bineq", [], ...
                    "Aeq", [], "beq", [], ...
                    "lb", [], "ub", []);

                [thetaOpt, ~, ~] = fmincon(problem);

                [U, W, b] = spiky.trig.TrigFr.unpackThetaMulti(thetaOpt, pLocal, d, Klocal, Tlocal);

                % ----- compute per-time training metrics and take peak time (inlined) -----
                losses = zeros(Tlocal, 1);
                accs = zeros(Tlocal, 1);
                confs = cell(Tlocal, 1);

                for tt = 1:Tlocal
                    Xtt = X(:, :, tt);
                    Z = U' * Xtt;
                    S = squeeze(W(:, :, tt))' * Z + b(:, tt); % K-by-n

                    switch opts.Type
                        case "softmax"
                            [logZ, P] = spiky.trig.TrigFr.logsumexpMat(S);
                            ce = -sum(sum(Ymat .* (S - logZ), 1)) / nLocal;
                            losses(tt) = ce;
                            [~, yhat] = max(P, [], 1);

                        case "hinge"
                            Sy = S(sub2ind([Klocal nLocal], yInt', 1:nLocal));
                            M = 1 + S - Sy;
                            mask = true(Klocal, nLocal);
                            mask(sub2ind([Klocal nLocal], yInt', 1:nLocal)) = false;
                            E = zeros(Klocal, nLocal);
                            E(mask) = exp(M(mask) / opts.Tau);
                            sumE = sum(E, 1);
                            loss = opts.Tau * sum(log(1 + sumE)) / nLocal;
                            losses(tt) = loss;
                            [~, yhat] = max(S, [], 1);
                    end

                    accs(tt) = mean(yhat(:) == yInt);
                    confs{tt} = confusionmat(yInt, yhat(:), "Order", 1:Klocal);
                end

                [trainAcc, bestIdx] = max(accs);
                trainLoss = losses(bestIdx);
                confMat = confs{bestIdx};
                % ----- end per-group inlined block -----

                subspaces{ii} = spiky.stat.Coords(zeros(p, 1), U);

                m = struct( ...
                    "TrainLoss", trainLoss, ...
                    "TrainAcc", trainAcc, ...
                    "Confusion", confMat);
                metrics{ii} = m;

                pb.step
            end

            subspaces = spiky.stat.Subspaces(0, subspaces, ...
                groupedFr.Groups, groupedFr.GroupIndices);
            subspaces.Partition = options.Partition;

            metrics = spiky.stat.GroupedStat(0, cell2mat(metrics), ...
                groupedFr.Groups, groupedFr.GroupIndices);

            trigFrProj = subspaces.project(trigFr);
            classifier = trigFrProj.fitcecoc(labels, ...
                Learners=options.Learners, Coding=options.Coding, ...
                FitPosterior=options.FitPosterior, Partition=options.Partition);
        end

        function detector = trainEventDetector(obj, labels, bases, options)
            %TRAINEVENTDETECTOR Train event detector using SVM classifiers
            %
            %   detector = trainEventDetector(obj, labels, bases, ...)
            %
            %   obj: triggered firing rate object
            %   labels: EventsTable of event labels (categorical)
            %   bases: TimeCoords object for feature extraction
            %   Name-value arguments:
            %       EventWindow: time window around each event to exclude from negative
            %           samples (default: [-0.5, 0.5] seconds)
            %       HistoryLength: length of history to consider for features (default: 0.5
            %           seconds or min basis time)
            %       NegativeSampleRatio: ratio of negative to positive samples (default: 5)
            %       Learners: type of base learners for ECOC (default: "svm")
            %       KFold: number of folds for cross-validation (default: 3)
            %       Coding: coding scheme for ECOC, "onevsall" or "onevsone" (default: "onevsall")
            %       NDims: number of dimensions for feature projection (default: 3)
            %
            arguments
                obj spiky.trig.TrigFr
                labels spiky.core.EventsTable
                bases spiky.stat.TimeCoords = spiky.stat.TimeCoords
                options.EventWindow double = [-0.5, 0.5]
                options.HistoryLength double = spiky.utils.ternary(isempty(bases), 0.5, -min(bases.Time))
                options.NegativeSampleRatio double = 5
                options.Learners = "svm"
                options.KFold double = 3
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} = "onevsall"
                options.NDims double = 3
            end

            %% Validate inputs
            if istable(labels.Data)
                labels.Data = labels.Data{:, 1};
            end
            assert(isvector(labels.Data), "Labels data must be a vector");
            assert(iscategorical(labels.Data), "Labels data must be categorical");

            %% Prepare features
            nT = height(obj);
            % groupedFr = obj.group(Permute=[1 3 2]); % 1 x nGroups of cell: nTime x nNeurons
            % nGroups = width(groupedFr);
            % if ~isempty(bases)
            %     features = cellfun(@(x) bases.expand(spiky.core.EventsTable(obj.Time, x)), ...
            %         groupedFr.Data, UniformOutput=false);
            % else
            %     features = groupedFr.Data;
            % end
            if ~isempty(bases)
                obj1 = bases.expand(obj);
            else
                obj1 = obj;
            end

            %% Prepare labels and samples
            labels = labels(labels.Time>options.HistoryLength, :);
            res = obj.Time(2)-obj.Time(1);
            idcLabelPos = min(round((labels.Time-obj.Time(1))/res)+1, height(obj));
            [~, idcExclude] = obj.inIntervals(labels.Time+options.EventWindow);
            idcInclude = setdiff((1:height(obj))', idcExclude);
            nPos = numel(idcLabelPos);
            nNeg = min(round(nPos*options.NegativeSampleRatio), numel(idcInclude));
            idcLabelNeg = randsample(idcInclude, nNeg);
            idcLabel = [idcLabelPos; idcLabelNeg];
            y = [labels.Data; repelem(categorical("none"), nNeg, 1)];
            [idcLabel, idcSort] = sort(idcLabel);
            y = y(idcSort);
            % Xs = cellfun(@(x) x.Data(idcLabel, :), features, UniformOutput=false);
            obj1 = subsref(obj1, substruct("()", {idcLabel, ':', ':'}));

            %% Prepare cross-validation partition
            tPartition = linspace(obj.Time(1), obj.Time(end), options.KFold+1);
            prdPartition = spiky.core.Intervals([tPartition(1:end-1)', tPartition(2:end)']);
            [~, ~, idcPartition] = prdPartition.haveEvents(obj.Time(idcLabel));
            partition = cvpartition(CustomPartition=idcPartition);
            
            %% Train event detector
            % optionsFit = statset(UseParallel=true);
            % mdls = cell(1, nGroups);
            % pb = spiky.plot.ProgressBar(nGroups, "Training event detectors", Parallel=true);
            % parfor ii = 1:nGroups
            %     X = Xs{ii};
            %     mdls{ii} = fitcecoc(X', y, Coding=options.Coding, ObservationsIn="columns", ...
            %         Learners=options.Learners, CVPartition=partition, Options=optionsFit, ...
            %         Verbose=1, FitPosterior=true, Prior="uniform");
            %     pb.step
            % end
            [mdl, ss] = obj1.learnDiscriminantSubspace(y, options.NDims, ...
                Learners=options.Learners, Coding=options.Coding, Partition=partition, ...
                FitPosterior=true, EventDim="rows");
            
            %% Create EventDetector object
            detector = spiky.stat.EventDetector(0, mdl, groupedFr.Groups, groupedFr.GroupIndices);
            detector.Subspaces = ss;
            detector.Bases = bases;
            detector.Partition = options.Partition;
            detector.PartitionIntervals = prdPartition;
            detector.Options = options;
        end

        function mdls = fitglm(obj, factors, modelspec, window, idcEvents, options)
            %FITGLM Fit a generalized linear model
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

        function mdl = lassoglm(obj, labels, options)
            %LASSOGLM Fit a lasso regularized generalized linear model
            %   mdl = lassoglm(obj, labels, ...)
            %
            %   obj: triggered firing rate object
            %   labels: response variables
            %   Name-value arguments:
            %       Intervals: intervals for the analysis
            %       Distribution: distribution for the GLM, one of "binomial", "poisson",
            %           "normal", "gamma", "inverse gaussian"
            %       Alpha: elastic net mixing parameter, between 0 and 1
            %       Lambda: regularization parameter
            %       Standardize: whether to standardize the predictors
            %       KFold: number of folds for cross-validation
            %       CV: cvpartition for cross-validation. If provided, KFold is ignored
            %
            %   mdl: GLMs
            arguments
                obj spiky.trig.TrigFr
                labels spiky.stat.Labels
                options.Intervals = [] % (n, 2) double or spiky.core.Intervals
                options.Distribution string {mustBeMember(options.Distribution, ...
                    ["binomial", "poisson", "normal", "gamma", "inverse gaussian"])} = "normal"
                options.Alpha double {mustBeInRange(options.Alpha, 0, 1)} = 1
                options.Lambda double = 1e-6
                options.Standardize logical = true
                options.KFold double = 1
                options.CV cvpartition = []
            end
            if width(obj.Data)>1
                obj = obj.flatten();
            end
            assert(height(labels)==height(obj), "Number of time points must match number of labels");
            names = compose("%s.%s.%d", labels.Name, labels.Class, labels.BaseIndex);
            if ~isempty(options.Intervals)
                if isnumeric(options.Intervals)
                    options.Intervals = spiky.core.Intervals(options.Intervals);
                end
                [~, idc] = options.Intervals.haveEvents(obj.Time);
            else
                idc = (1:height(obj))';
            end
            nNeurons = size(obj.Data, 3);
            if ~isempty(options.CV)
                options.KFold = options.CV.NumTestSets;
                idcTraining = options.CV.training("all");
                idcTraining = idcTraining(idc, :);
            elseif options.KFold>1
                options.CV = cvpartition(numel(idc), KFold=options.KFold);
                idcTraining = options.CV.training("all");
            else
                idcTraining = true(numel(idc), 1);
            end
            nFolds = width(idcTraining);
            data = obj.Data(idc, 1, :);
            l = labels.Data(idc, :);
            b = cell(1, nNeurons, nFolds);
            fi = cell(1, nNeurons, nFolds);
            ops = statset(UseParallel=true);
            pb = spiky.plot.ProgressBar(nNeurons*nFolds, "Fitting GLM", Parallel=true, ...
                CloseOnFinish=false);
            parfor ii = 1:nNeurons*nFolds
                [idxNeuron, idxFold] = ind2sub([nNeurons, nFolds], ii);
                x = l(idcTraining(:, idxFold), :);
                y = data(idcTraining(:, idxFold), 1, idxNeuron);
                [b{ii}, fi{ii}] = lassoglm(x, y, ...
                    options.Distribution, Alpha=options.Alpha, Lambda=options.Lambda, ...
                    Standardize=options.Standardize, Options=ops);
                pb.step
            end
            mdl = spiky.stat.GLM(cell2mat(b), spiky.utils.cellfun(@(x) x.Intercept, fi), ...
                names, obj.Neuron, options.Lambda, options.Alpha, ...
                spiky.utils.cellfun(@(x) x.Deviance, fi), options);
        end

        function varargout = subsref(obj, s)
            if strcmp(s(1).type, '()') && isscalar(s(1).subs)
                s(1).subs = [{':', ':'}, s(1).subs];
            end
            [varargout{1:nargout}] = subsref@spiky.core.EventsTable(obj, s);
        end
    end
end