classdef TrigSpikes < spiky.trig.Trig & spiky.core.Spikes
    %TRIGSPIKES Spikes triggered by events
    %   The data is stored in a cell array, where the rows correspond to the events and the columns
    %   to the neurons.

    properties (Dependent)
        Fr
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
            dimLabelNames = {"Time"; "Neuron"};
        end
    end

    methods
        function obj = TrigSpikes(events, data, window, neuron)
            %TRIGSPIKES Create a new instance of TrigSpikes

            arguments
                events (:, 1) double
                data cell = cell(height(events), 0)
                window (:, 2) double = double.empty(0, 2)
                neuron spiky.core.Neuron = spiky.core.Neuron.empty
            end
            obj@spiky.trig.Trig(events, data, EventDim=1);
            obj.Window = window;
            obj.Neuron = neuron;
        end

        function fr = get.Fr(obj)
            fr = cellfun(@(x) numel(x)./diff(obj.Window), obj.Data);
        end

        function fr = getFr(obj, window, cats, options)
            %GETFR Get firing rate in a window
            %
            %   fr = getFr(obj, window)
            %
            %   obj: triggered spikes object
            %   window: window for the analysis
            %   cats: categories for the events
            %   options: additional arguments
            %       Normalize: normalize the firing rate
            %
            %   fr: [nCats, nNeurons] firing rate

            arguments
                obj spiky.trig.TrigSpikes
                window double = []
                cats (:, 1) categorical = categorical.empty
                options.Normalize logical = false
            end
            if isempty(obj.Data)
                fr = [];
                return
            end
            if isempty(window)
                window = obj.Window;
            end
            if isempty(cats)
                cats = obj.Events;
                nCats = numel(cats);
                events = cats;
            elseif isscalar(cats)
                cats = zeros(height(obj.Data), 1);
                nCats = 1;
                events = 0;
            else
                events = categories(cats);
                nCats = numel(events);
            end
            if numel(cats)~=height(obj.Data)
                error("Number of categories must match the number of events");
            end
            w = diff(window);
            % fr1 = cellfun(@(x) sum(x>=window(1) & x<window(2))/w, obj.Data);
            % fr2 = groupsummary(fr1, cats, @mean, IncludeEmptyGroups=true);
            fr2 = zeros(nCats, width(obj));
            data = obj.Data;
            parfor ii = 1:nCats
                fr1 = cellfun(@(x) sum(x>=window(1) & x<window(2))/w, data(cats==events(ii), :));
                % fr2(ii, :) = mean(fr1(cats==events(ii), :), 1);
                fr2(ii, :) = mean(fr1, 1);
            end
            if options.Normalize
                frMean = mean(cellfun(@numel, obj.Data), 1)./diff(obj.Window);
                fr2 = (fr2-frMean)./sqrt(frMean./w);
            end
            fr = spiky.trig.TrigFr(window(1), w, permute(fr2, [3 1 2]), events, window, obj.Neuron);
            fr.Options = options;
        end

        function mdl = fitcecoc(obj, labels, window, idcEvents, options)
            %FITCECOC Fit a multiclass error-correcting output codes model
            %
            %   mdl = fitcecoc(obj, window, labels)
            %
            %   obj: triggered firing rate object
            %   labels: labels for the classes
            %   window: window for the analysis
            %   options: additional arguments passed to fitcecoc
            %       Coding: coding design for multiclass classification
            %       KFold: number of folds for cross-validation
            %       ClassNames: class names
            %       Normalize: normalize the data to unit vector
            %
            %   mdl: trained model
            arguments
                obj spiky.trig.TrigSpikes
                labels
                window double = []
                idcEvents = []
                options.Coding string {mustBeMember(options.Coding, ["onevsall", "onevsone"])} = "onevsall"
                options.CVPartition = []
                options.KFold double = []
                options.ClassNames = []
                options.Normalize = false
            end

            if isempty(window)
                window = obj.Window;
            end
            labels = labels(:);
            if isempty(idcEvents)
                idcEvents = true(obj.NEvents, 1);
            end
            labels = labels(idcEvents);
            fr = obj.getFr(window);
            fr = fr(idcEvents, :)';
            if options.Normalize
                fr = fr./vecnorm(fr, 2, 1);
            end
            if isempty(options.KFold)
                mdl = fitcecoc(fr, labels, Coding=options.Coding, ObservationsIn="columns", ...
                    CVPartition=options.CVPartition);
            else
                mdl = fitcecoc(fr, labels, Coding=options.Coding, ObservationsIn="columns", ...
                    KFold=options.KFold);
            end
        end

        function [h, hLine] = plotRaster(obj, sz, c, cats, rowDim, plotOps, options)
            %PLOTRASTER Plot raster of triggered spikes
            %
            %   h = plotRaster(obj, ...)
            %
            %   obj: triggered spikes object
            %   sz: size of the markers
            %   c: color of the markers
            %   cats: categories for the events or neurons (if rowDim is "neuron")
            %   rowDim: dimension to plot, can be "neuron" or "event"
            %   Name-Value pairs:
            %       IdcEvents: indices of events to plot
            %       SubSet: subset of categories to plot
            %       Parent: parent axes for the plot
            %       MarkerEdgeColor, ...: options passed to scatter()
            %
            %   h: handle to the plot
            %   hLine: handle to the horizontal lines

            arguments
                obj spiky.trig.TrigSpikes
                sz double {mustBePositive} = 5
                c = "k"
                cats categorical = categorical.empty
                rowDim {mustBeMember(rowDim, ["neuron", "event"])} = "event"
                plotOps.?matlab.graphics.chart.primitive.Scatter
                options.IdcEvents = []
                options.SubSet = []
                options.Parent matlab.graphics.axis.Axes = matlab.graphics.axis.Axes.empty
            end
            if isempty(options.Parent)
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
            obj.Data = obj.Data(idcEvents, :);
            if ~isempty(cats) && rowDim=="event"
                cats = cats(:);
                if numel(cats)==n
                    cats = cats(idcEvents);
                elseif numel(cats)~=numel(idcEvents)
                    error("Wrong size of categories")
                end
                if ~isempty(options.SubSet)
                    idcEvents = ismember(cats, options.SubSet);
                    obj.Data = obj.Data(idcEvents, :);
                    cats = cats(idcEvents);
                end
            end
            plotArgs = namedargs2cell(plotOps);
            [t, r, edges, catNames] = obj.getRaster(cats, rowDim);
            n = edges(end)-0.5;
            centers = (edges(1:end-1)+edges(2:end))./2;
            h1 = scatter(options.Parent, t, r, sz, c, "filled", plotArgs{:});
            xlim(options.Parent, obj.Window);
            ylim(options.Parent, [0.5 n+0.5]);
            set(options.Parent, "YDir", "reverse");
            xlabel(options.Parent, "Time (s)");
            if ~isempty(cats)
                cats = removecats(cats);
                yticks(options.Parent, centers);
                yticklabels(options.Parent, catNames);
                options.Parent.YAxis.FontSize = 10;
                h2 = yline(options.Parent, edges, LineWidth=0.5);
            else
                h2 = gobjects(1);
            end
            if nargout>0
                h = h1;
            end
            if nargout>1
                hLine = h2;
            end
        end

        function [t, r, edges, cats] = getRaster(obj, cats, rowDim)
            arguments
                obj spiky.trig.TrigSpikes
                cats categorical = categorical.empty
                rowDim {mustBeMember(rowDim, ["neuron", "event"])} = "event"
            end

            switch rowDim
                case "neuron"
                    if height(obj)>1
                        error("Only one event supported if multiple neurons");
                    end
                    if isempty(cats)
                        cats = ones(width(obj.Data), 1);
                    else
                        cats = cats(:);
                    end
                    [cats, idc] = sort(cats);
                    n = numel(cats);
                    t = cell2mat(obj.Data(1, idc)');
                    nSpikes = cellfun(@length, obj.Data(1, idc)');
                    r = zeros(numel(t), 1);
                case "event"
                    if width(obj)>1
                        error("Only one neuron supported if multiple events");
                    end
                    if isempty(cats)
                        cats = ones(height(obj.Data), 1);
                    else
                        cats = cats(:);
                    end
                    [cats, idc] = sort(cats);
                    n = numel(cats);
                    t = cell2mat(obj.Data(idc, 1));
                    nSpikes = cellfun(@length, obj.Data(idc, 1));
                    r = zeros(numel(t), 1);
            end
            count = 0;
            for ii = 1:n
                if nSpikes(ii)==0
                    continue
                end
                r(count+(1:nSpikes(ii))) = ii;
                count = count+nSpikes(ii);
            end
            counts = groupcounts(cats);
            cats = unique(cats);
            cats = cats(1:numel(counts));
            edges = [0; cumsum(counts)]+0.5;
        end

        function varargout = subsref(obj, s)
            if strcmp(s(1).type, '()') && isscalar(s(1).subs)
                s(1).subs = [{':'}, s(1).subs];
            end
            [varargout{1:nargout}] = subsref@spiky.core.EventsTable(obj, s);
        end
    end
end