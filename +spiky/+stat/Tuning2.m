classdef Tuning2 < spiky.stat.Tuning
    %TUNING2 2D continuous tuning curve
    %   First dimension: y-axis bins
    %   Second dimension: x-axis bins
    %   Third dimension: neurons
    %   Fourth dimension: conditions (optional)
    %
    %   Stats: table containing the following possible columns:
    %       GaussianFit: parameters of the fitted Gaussian 
    %           [Baseline, Amplitude, CenterX, CenterY, SigmaX, SigmaY]
    %       Peak: parameters of the fitted peak
    %           [PeakX, PeakY, PeakH, Prominence, Area]

    properties
        BinEdgesX (:, 1) double
    end

    properties (Dependent)
        BinEdgesY (:, 1) double
        NBinsX double
        BinCentersX (:, 1) double
        NBinsY double
        BinCentersY (:, 1) double
        ResX double
        ResY double
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
            dimLabelNames = {"BinEdgesY"; "BinEdgesX"; ["Neuron"; "Fr"; "P"; "Stats"]; "Conditions"};
        end
    end

    methods
        function obj = Tuning2(fr, binEdgesX, binEdgesY, occupancy, options)
            arguments
                fr (:, :, :, :) double = []
                binEdgesX (:, 1) double = 0
                binEdgesY (:, 1) double = 0
                occupancy (:, :, :) double = ones(height(fr), width(fr))
                options.Neuron (:, 1) spiky.core.Neuron = spiky.core.Neuron.zeros(size(fr, 3))
                options.Conditions (:, 1) = (1:size(fr, 4))'
                options.Fr (:, 1) double = squeeze(sum(fr, [1 2], "omitmissing")./sum(occupancy, [1 2], "omitmissing"))
                options.P (:, 1) double = NaN(size(fr, 3), 1)
            end
            assert(isequal(height(fr), height(occupancy), numel(binEdgesY)-1), ...
                "The number of rows in fr, occupancy, and binEdgesY must be consistent.");
            assert(isequal(width(fr), width(occupancy), numel(binEdgesX)-1), ...
                "The number of columns in fr, occupancy, and binEdgesX must be consistent.");
            obj.Data = fr;
            obj.BinEdgesX = binEdgesX;
            obj.BinEdgesY = binEdgesY;
            obj.Occupancy = occupancy;
            obj.Neuron = options.Neuron;
            obj.Conditions = options.Conditions;
            obj.Fr = options.Fr;
            obj.P = options.P;
            obj.Type = "Tuning2";
            obj.Stats = table(Size=[length(options.Neuron) 0]);
        end

        function binEdgesY = get.BinEdgesY(obj)
            binEdgesY = obj.BinEdges;
        end

        function obj = set.BinEdgesY(obj, binEdgesY)
            obj.BinEdges = binEdgesY;
        end

        function nBinsY = get.NBinsY(obj)
            nBinsY = obj.NBins;
        end

        function binCentersY = get.BinCentersY(obj)
            binCentersY = obj.BinCenters;
        end

        function nBinsX = get.NBinsX(obj)
            nBinsX = numel(obj.BinEdgesX)-1;
        end

        function binCentersX = get.BinCentersX(obj)
            binCentersX = (obj.BinEdgesX(1:end-1)+obj.BinEdgesX(2:end))/2;
        end

        function resY = get.ResY(obj)
            resY = obj.Res;
        end

        function resX = get.ResX(obj)
            resX = obj.BinEdgesX(2)-obj.BinEdgesX(1);
        end

        function obj = smooth(obj, sigma)
            %SMOOTH Smooth the tuning curve
            %
            %   obj = SMOOTH(obj, sigma)
            %
            %   obj: tuning curve
            %   sigma: standard deviation of the Gaussian kernel in raw units
            arguments
                obj spiky.stat.Tuning2
                sigma double
            end
            sigma = sigma(:)';
            if isscalar(sigma)
                sigma = [sigma sigma];
            end
            sigma = sigma./[obj.ResY obj.ResX];
            obj.Data = spiky.utils.imgaussfilt(obj.Data, sigma);
            obj.Occupancy = spiky.utils.imgaussfilt(obj.Occupancy, sigma);
        end

        function mi = mutualInfo(obj)
            %MUTUALINFO Compute the mutual information between firing rate and position            
            arguments
                obj spiky.stat.Tuning2
            end
            data = obj.Data; % nBinsY x nBinsX x nNeurons x nConditions firing rate map
            pP = obj.Occupancy./sum(obj.Occupancy, [1 2], "omitnan"); % nBinsY x nBinsX x nNeurons spatial probability
            nNeurons = size(data, 3);
            meanRate = sum(data.*pP, [1 2], "omitnan"); % 1 x 1 x nNeurons x nConditions mean firing rate
            ratio = data./meanRate; % nBinsY x nBinsX x nNeurons x nConditions firing rate relative to mean
            term = pP.*ratio.*log2(ratio); % nBinsY x nBinsX x nNeurons x nConditions contribution to mutual information
            term(~isfinite(term)) = 0; % Handle 0*log(0) and Inf*log(Inf) cases
            mi = squeeze(sum(term, [1 2], "omitnan")); % nNeurons x nConditions mutual information in bits/spike
        end
        
        function pos = predict(obj, fr)
            %PREDICT Estimates position based on firing rate using Bayesian decoding
            %
            %   pos = PREpredictDICT(obj, fr)
            %
            %   obj: Tuning2 object containing the 2D place tuning map
            %   fr: observed firing rates
            %
            %   pos: (nTime, 2) matrix of estimated positions
            
            arguments
                obj spiky.stat.Tuning2
                fr % nTime x nNeurons or spiky.trig.TrigFr
            end
        
            % Extract data
            if isa(fr, "spiky.trig.TrigFr")
                fr = permute(fr.Data, [2 3 1]);
            elseif ~isnumeric(fr)
                error("Invalid input for firing rate");
            end
            tuningMap = obj.Data;   % nBinsY x nBinsX x nNeurons
            occupancy = obj.Occupancy; % nBinsY x nBinsX
            nTime = size(fr, 1); % Number of time points
            nNeurons = size(fr, 2); % Number of neurons
            assert(nNeurons == size(tuningMap, 3), "Mismatch in neuron count");
        
            % Compute log prior (spatial prior P(x))
            logPPos = log(occupancy); 
            logPPos(isinf(logPPos)) = -inf; % Handle log(0) case
        
            % Define bin centers for mapping indices to coordinates
            binCentersX = obj.BinCentersX;
            binCentersY = obj.BinCentersY;
        
            % Initialize estimated positions
            pos = nan(nTime, 2);
        
            % Loop over time points and decode position
            parfor t = 1:nTime
                % Get current firing rate sample
                r = reshape(fr(t, :), [1, 1, nNeurons]); % Reshape for broadcasting
        
                % Mean firing rate from tuning map (Poisson expected rate)
                lambda = tuningMap; % nBinsY x nBinsX x nNeurons
                
                % Compute log-likelihood log P(r | x) using Poisson probability:
                % log P(r | x) = sum_over_neurons [r log(lambda) - lambda]
                logPRGivenX = sum(r .* log(lambda) - lambda, 3, 'omitnan');
        
                % Compute log posterior: log P(x | r) = log P(r | x) + log P(x)
                logPosterior = logPRGivenX + logPPos;
        
                % Find the maximum log posterior probability (most likely position)
                [maxIdx] = find(logPosterior == max(logPosterior, [], 'all'), 1);
                [row, col] = ind2sub(size(logPosterior), maxIdx);
        
                % Map bin indices back to spatial coordinates
                pos(t, :) = [binCentersX(col), binCentersY(row)];
            end
        end
        
        function [m, sd] = accuracy(obj, fr, pos)
            %ACCURACY Computes the accuracy of the Bayesian decoder in terms of Euclidean distance.
            %
            %   [m, sd] = accuracy(obj, fr, pos)
            %
            %   obj: Tuning2 object containing the 2D place tuning map
            %   fr: observed firing rates
            %   pos: (nTime, 2) matrix of true positions
            %
            %   m: Mean Euclidean distance between predicted and actual positions
            %   sd: Standard deviation of Euclidean distances
            
            arguments
                obj spiky.stat.Tuning2
                fr % nTime x nNeurons or spiky.trig.TrigFr
                pos (:, 2) double % nTime x 2 (true positions)
            end
        
            if isa(fr, "spiky.trig.TrigFr")
                fr = permute(fr.Data, [2 3 1]);
            elseif ~isnumeric(fr)
                error("Invalid input for firing rate");
            end

            % Predict positions using the Bayesian decoder
            predictedPos = obj.predict(fr);
            
            % Compute Euclidean distances between true and predicted positions
            errors = sqrt(sum((predictedPos - pos).^2, 2)); 
            
            % Compute mean and standard deviation of errors
            m = mean(errors, 'omitnan');
            sd = std(errors, 'omitnan');
        end

        function obj = fit(obj, options)
            %FIT Fit the peak of the tuning map parametrically
            %   obj = FIT(obj, ...)
            %
            %   obj: Tuning2 object
            %   Name-value arguments:
            %       Type: fitting method (default: "gaussian")
            %           "gaussian": fit a 2D Gaussian function to the tuning map
            %           "peak": find the peak of the tuning map and estimate the area
            %       CenterBoundsX: bounds for the x-coordinate of the center
            %       CenterBoundsY: bounds for the y-coordinate of the center
            %       SigmaBounds: bounds for the standard deviation of the Gaussian fit
            %       PeakThresholdRatio: threshold ratio to determine the area of the peak for the
            %           "peak" method, relative to the peak firing rate (default: 0.5)
            %       MaxIter: maximum number of iterations for the fitting algorithm
            arguments
                obj spiky.stat.Tuning2
                options.Type {mustBeMember(options.Type, ["gaussian" "peak"])} = "gaussian"
                options.CenterBoundsX (1, 2) double = [min(obj.BinEdgesX) max(obj.BinEdgesX)]
                options.CenterBoundsY (1, 2) double = [min(obj.BinEdgesY) max(obj.BinEdgesY)]
                options.SigmaBounds (1, 2) double = [0 inf]
                options.PeakThresholdRatio double = 0.5
                options.MaxIter double = 1000
            end
            data = obj.Data;
            [nY, nX, nNeurons] = size(data);
            switch options.Type
                case "gaussian"
                    [gridX, gridY] = meshgrid(obj.BinCentersX, obj.BinCentersY);
                    % beta = NaN(nNeurons, 6); % [Baseline, Amplitude, CenterX, CenterY, SigmaX, SigmaY]
                    beta = cell(nNeurons, 1);
                    lb = [-inf 0 options.CenterBoundsX(1) options.CenterBoundsY(1) ...
                        options.SigmaBounds(1) options.SigmaBounds(1)];
                    ub = [inf inf options.CenterBoundsX(2) options.CenterBoundsY(2) ...
                        options.SigmaBounds(2) options.SigmaBounds(2)];
                    % beta0 = [squeeze(min(data, [], [1 2]))' ... % Baseline
                    %     squeeze(max(data, [], [1 2]) - min(data, [], [1 2]))' ... % Amplitude
                    %     repmat(mean(obj.BinEdgesX), nNeurons, 1) ... % CenterX
                    %     repmat(mean(obj.BinEdgesY), nNeurons, 1) ... % CenterY
                    %     repmat((obj.ResX+obj.ResY), nNeurons, 1) ... % SigmaX
                    %     repmat((obj.ResX+obj.ResY), nNeurons, 1)]; % SigmaY
                    solverOps = optimoptions("lsqcurvefit", Display="none", MaxIterations=options.MaxIter);
                    mdl = @(b, xy) b(1)+b(2)*exp(-0.5.*(((xy(:, 1)-b(3))/b(5)).^2+((xy(:, 2)-b(4))/b(6)).^2));
                    idcValid = find(~isnan(obj.Occupancy));
                    xy = [gridX(idcValid) gridY(idcValid)];
                    for ii = 1:nNeurons
                        r = data(:, :, ii);
                        r = r(idcValid);
                        [~, idxPeak] = max(r);
                        beta0 = [min(r) ...
                            max(r)-min(r) ...
                            xy(idxPeak, 1) ...
                            xy(idxPeak, 2) ...
                            obj.ResX+obj.ResY ...
                            obj.ResX+obj.ResY];
                        beta0 = min(max(beta0, lb), ub);
                        try
                            beta{ii} = reshape(lsqcurvefit(mdl, beta0, xy, r, lb, ub, solverOps), [1 6]);
                        catch ME
                            warning("Fitting failed for neuron %d\n%s", ii, ME.message);
                            beta{ii} = NaN(1, 6);
                        end
                    end
                    beta = cell2mat(beta);
                    obj.Stats.GaussianFit = array2table(beta, ...
                        VariableNames=["Baseline" "Amplitude" "CenterX" "CenterY" "SigmaX" "SigmaY"]);
                case "peak"
                    peakX = NaN(nNeurons, 1);
                    peakY = NaN(nNeurons, 1);
                    peakH = NaN(nNeurons, 1);
                    prominence = NaN(nNeurons, 1);
                    area = NaN(nNeurons, 1);
                    [isPeak, promPeak] = islocalmax2(obj.Data);
                    mask = obj.BinCentersX'>=options.CenterBoundsX(1) & obj.BinCentersX'<=options.CenterBoundsX(2) & ...
                        obj.BinCentersY>=options.CenterBoundsY(1) & obj.BinCentersY<=options.CenterBoundsY(2);
                    resArea = obj.ResX*obj.ResY;
                    for ii = 1:nNeurons
                        prom = promPeak(:, :, ii);
                        idcPeak1 = find(isPeak(:, :, ii) & mask);
                        if isempty(idcPeak1)
                            continue
                        end
                        [idcY1, idcX1] = ind2sub([nY nX], idcPeak1);
                        p1 = prom(idcPeak1);
                        [~, idxMax] = max(p1);
                        idxY = idcY1(idxMax);
                        idxX = idcX1(idxMax);
                        h = data(idxY, idxX, ii);
                        p = p1(idxMax);
                        thr = h-p*options.PeakThresholdRatio;
                        peakX(ii) = obj.BinCentersX(idxX);
                        peakY(ii) = obj.BinCentersY(idxY);
                        peakH(ii) = h;
                        prominence(ii) = p;
                        area(ii) = sum(data(:, :, ii)>thr, "all")*resArea;
                    end
                    obj.Stats.Peak = table(peakX, peakY, peakH, prominence, area, ...
                        VariableNames=["PeakX" "PeakY" "PeakH" "Prominence" "Area"]);
            end
        end

        function obj = pickConditions(obj, idcConditions)
            %PICKCONDITIONS Select specific conditions for each neuron
            arguments
                obj spiky.stat.Tuning2
                idcConditions (:, 1) double
            end
            func = @(x, idc) arrayfun(@(ii, jj) x(ii, jj), (1:height(x))', idc);
            obj = obj.gatheralong(3, 4, idcConditions);
            obj.Occupancy = obj.Occupancy(:, :, 1);
            obj.P = func(obj.P, idcConditions);
            for ii = 1:numel(obj.Stats.Properties.VariableNames)
                varName = obj.Stats.Properties.VariableNames{ii};
                v = obj.Stats.(varName);
                if isnumeric(v) && width(v)==size(obj.Data, 4)
                    obj.Stats.(varName) = func(v, idcConditions);
                end
            end
        end

        function h = imagesc(obj, options, plotOps)
            %IMAGESC Plot the tuning map using imagesc
            %   h = IMAGESC(obj, ...)
            arguments
                obj spiky.stat.Tuning2
                options.Parent matlab.graphics.axis.Axes = gca
                plotOps.?matlab.graphics.primitive.Image
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = imagesc(options.Parent, obj.BinCentersX, obj.BinCentersY, ...
                obj.Data(:, :, 1, 1), plotArgs{:});
            set(gca, "YDir", "normal");
            xlabel("X");
            ylabel("Y");
            if nargout>0
                h = h1;
            end
        end

        function h = plotFit(obj, options, plotOps)
            %PLOTFIT Plot the fitted Gaussian ellipse
            arguments
                obj spiky.stat.Tuning2
                options.Level double = 1
                options.Parent matlab.graphics.axis.Axes = gca
                plotOps.?matlab.graphics.primitive.Line
            end
            beta = obj.Stats.GaussianFit;
            theta = linspace(0, 2*pi, 100);
            xEllipse = beta.CenterX+options.Level*beta.SigmaX.*cos(theta);
            yEllipse = beta.CenterY+options.Level*beta.SigmaY.*sin(theta);
            plotArgs = namedargs2cell(plotOps);
            h1 = gobjects(height(beta), 1);
            np = options.Parent.NextPlot;
            hold(options.Parent, "on");
            for ii = 1:height(beta)
                h1(ii) = plot(options.Parent, xEllipse(ii, :), yEllipse(ii, :), plotArgs{:});
            end
            options.Parent.NextPlot = np;
            if nargout>0
                h = h1;
            end
        end

        function h = plotPeaks(obj, maxSize, options, plotOps)
            %PLOTPEAKS Plot the peaks of the tuning map
            arguments
                obj spiky.stat.Tuning2
                maxSize double = 100
                options.Parent matlab.graphics.axis.Axes = gca
                plotOps.?matlab.graphics.chart.primitive.Scatter
            end
            isValid = ~isnan(obj.Stats.Peak.PeakX) & ~isnan(obj.Stats.Peak.PeakY);
            plotArgs = namedargs2cell(plotOps);
            sz = obj.Stats.Peak.Area(isValid)./max(obj.Stats.Peak.Area, [], "omitmissing")*maxSize;
            h1 = scatter(options.Parent, obj.Stats.Peak.PeakX(isValid), ...
                obj.Stats.Peak.PeakY(isValid), sz, plotArgs{:});
            if nargout>0
                h = h1;
            end
        end

        function h = plotDistribution(obj, options, plotOps)
            arguments
                obj spiky.stat.Tuning2
                options.Type {mustBeMember(options.Type, ["gaussian" "peak"])} = "peak"
                options.BinCentersX (:, 1) double = spiky.utils.edge2center(obj.BinEdgesX)
                options.BinCentersY (:, 1) double = spiky.utils.edge2center(obj.BinEdgesY)
                options.Smooth double = 0
                options.Offset double = [0 0]
                options.Parent matlab.graphics.axis.Axes = gca
                plotOps.?matlab.graphics.primitive.Image
            end
            switch options.Type
                case "gaussian"
                    x = obj.Stats.GaussianFit.CenterX;
                    y = obj.Stats.GaussianFit.CenterY;
                case "peak"
                    x = obj.Stats.Peak.PeakX;
                    y = obj.Stats.Peak.PeakY;
            end
            x = x+options.Offset(1);
            y = y+options.Offset(2);
            edgesX = spiky.utils.center2edge(options.BinCentersX);
            edgesY = spiky.utils.center2edge(options.BinCentersY);
            centersX = options.BinCentersX;
            centersY = options.BinCentersY;
            counts = histcounts2(y, x, edgesY, edgesX);
            if options.Smooth>0
                resX = mean(diff(centersX));
                counts = imgaussfilt(counts, options.Smooth/resX);
            end
            plotArgs = namedargs2cell(plotOps);
            h1 = imagesc(options.Parent, centersX, centersY, counts, plotArgs{:});
            set(gca, "YDir", "normal");
            if nargout>0
                h = h1;
            end
        end
    end
end