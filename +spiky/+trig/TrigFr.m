classdef TrigFr < spiky.trig.Trig & spiky.core.Spikes
    % TRIGFR Firing rate triggered by events

    properties
        Options struct
    end

    methods
        function obj = TrigFr(spikes, events, window, options)
            arguments
                spikes spiky.core.Spikes = spiky.core.Spikes.empty
                events = [] % (n, 1) double or spiky.core.Events
                window double {mustBeVector} = [0, 1]
                options.halfWidth double {mustBePositive} = 0.1
                options.kernel string {mustBeMember(options.kernel, ["gaussian", "box"])} = "gaussian"
            end
            if nargin==0 || isempty(spikes)
                return
            end
            if isa(events, "spiky.core.Events")
                events = events.Time;
            end
            events = events(:);
            t = window(:)';
            nEvents = numel(events);
            nT = numel(t);
            res = t(2)-t(1);
            wAdd = round(options.halfWidth*3/res);
            idcAdd = wAdd+1:wAdd+nT;
            tWide = t(1)-wAdd*res:res:t(end)+wAdd*res+eps;
            windowWide = tWide([1 end]);
            edges = [tWide-res/2, tWide(end)+res/2];
            switch options.kernel
                case "gaussian"
                    kernel = exp(-0.5.*(tWide-(tWide(1)+tWide(end))/2).^2./options.halfWidth.^2)./...
                        (sqrt(2*pi)*options.halfWidth);
                case "box"
                    kernel = zeros(size(tWide));
                    idx = find(tWide-(tWide(1)+tWide(end))/2>=options.halfWidth, 1, "first");
                    idc = idx:idx+options.halfWidth*2/res-1;
                    kernel(idc) = 1/options.halfWidth/2;
                otherwise
                    error("Unknown kernel %s", options.kernel);
            end
            nNeurons = numel(spikes);
            fr = cell(1, nEvents, nNeurons);
            tr = spikes.trig(events, windowWide);
            tr = tr.Data;
            % pb = spiky.plot.ProgressBar(nEvents*nNeurons, "Analyzing fr", parallel=true);
            parfor kk = 1:nEvents*nNeurons
                sp = tr{kk};
                spWide = histcounts(sp, edges);
                spWide = conv(spWide, kernel, "same");
                fr{kk} = spWide(idcAdd)';
                % pb.step
            end
            fr = cell2mat(fr);
            obj.Start_ = t(1);
            obj.Step_ = res;
            obj.N_ = nT;
            obj.Data = fr;
            obj.EventDim = 2;
            obj.Events_ = events;
            obj.Window = window;
            obj.Neuron = [spikes.Neuron]';
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

        function p = ttest(obj, baseline, window)
            % TTEST Perform t-test on the firing rate in a window
            arguments
                obj spiky.trig.TrigFr
                baseline double = []
                window double = []
            end

            nUnits = size(obj, 3);
            if isempty(obj.Data)
                baseline = obj.Window([1 end]);
            end
            if isequal(size(baseline), [1, 2])
                % baseline is a window
                m = mean(obj.getFr(baseline), 2);
            elseif ~isequal(size(baseline), nUnits)
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

            if isempty(window)
                window = obj.Time([1 end]);
            end
            is = obj.Time>=window(1) & obj(1).Time<=window(2);
            nT = sum(is);
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            labels = labels(idcEvents);
            n = numel(labels);
            X = permute(obj.Data(is, idcEvents, :), [3 2 1]);
            % if isempty(options.ClassNames)
            %     options.ClassNames = unique(labels);
            % end
            mdls = cell(nT, 1);
            pb = spiky.plot.ProgressBar(nT, "Fitting models", parallel=true);
            parfor ii = 1:nT
                if isempty(options.KFold)
                    mdls{ii} = fitcecoc(X(:, :, ii), labels, Coding=options.Coding, ObservationsIn="columns", ...
                        ClassNames=options.ClassNames, Options=statset(UseParallel=true));
                else
                    mdls{ii} = fitcecoc(X(:, :, ii), labels, Coding=options.Coding, ObservationsIn="columns", ...
                        ClassNames=options.ClassNames, KFold=options.KFold, Options=statset(UseParallel=true));
                end
                pb.step
            end
        end

        function varargout = subsref(obj, s)
            if strcmp(s(1).type, '()')
                s1 = s(1);
                s2 = s(1);
                switch length(s1.subs)
                    case 1
                        s(1).subs = [{':', ':'}, s1.subs];
                        s2.subs = {':'};
                    case 2
                        s1.subs = {1};
                        s2.subs = s2.subs(2);
                    case 3
                        s1.subs = s1.subs(3);
                        s2.subs = s2.subs(2);
                    otherwise
                        error("Too many indices")
                end
                obj.Neuron = builtin("subsref", obj.Neuron, s1);
                obj.Events_ = builtin("subsref", obj.Events_, s2);
            end
            [varargout{1:nargout}] = subsref@spiky.core.TimeTable(obj, s);
        end
    end
end