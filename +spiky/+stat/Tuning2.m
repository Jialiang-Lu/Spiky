classdef Tuning2 < spiky.stat.Tuning
    % TUNING2 2D continuous tuning curve

    properties
        BinEdgesY (:, 1) double
    end

    properties (Dependent)
        BinEdgesX (:, 1) double
        NBinsX double
        BinCentersX (:, 1) double
        NBinsY double
        BinCentersY (:, 1) double
        ResX double
        ResY double
    end

    methods
        function obj = Tuning2(fr, pos, binEdgesX, binEdgesY)
            %TUNING2 Construct a 2D tuning curve
            %
            %   obj = TUNING2(fr, pos, binEdgesX, binEdgesY)
            %
            %   fr: firing rate, either a matrix with the first dimension being time or a TrigFr
            %   pos: position matrix nTime x 2
            %   binEdgesX: bin edges for the x-axis
            %   binEdgesY: bin edges for the y-axis
            %
            %   obj: tuning curve
            arguments
                fr
                pos (:, 2)
                binEdgesX (:, 1) double
                binEdgesY (:, 1) double
            end

            if isa(fr, "spiky.trig.TrigFr")
                fr = permute(fr.Data, [2 3 1]);
            elseif ~isnumeric(fr)
                error("Invalid input for firing rate");
            end
            nNeurons = width(fr);
            nBinsX = numel(binEdgesX)-1;
            nBinsY = numel(binEdgesY)-1;
            [data, ~, count] = groupsummary(fr, {pos(:, 1) pos(:, 2)}, {binEdgesX binEdgesY}, @mean, ...
                IncludeEmptyGroups=true, IncludeMissingGroups=false);
            count(isnan(count)) = 0;
            obj.Data = reshape(data, nBinsY, nBinsX, nNeurons);
            obj.BinEdgesX = binEdgesX;
            obj.BinEdgesY = binEdgesY;
            obj.Occupancy = reshape(count./sum(count), nBinsY, nBinsX);
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

        function [mi, p] = mutualInformation(obj, nShuffles)
            % MUTUALINFORMATION Compute the mutual information between firing rate and position
            %
            %   [mi, p] = MUTUALINFORMATION(obj, nShuffles)
            %
            %   obj: tuning curve object
            %   nShuffles: number of shuffles for significance testing (default: 1000)
            %
            %   mi: mutual information for each neuron
            %   p: p-value for each neuron from permutation test
            
            arguments
                obj spiky.stat.Tuning2
                nShuffles (1, 1) double = 1000
            end
            
            data = obj.Data;          % Extract firing rate data (NBinsY x NBinsX x nNeurons)
            occupancy = obj.Occupancy; % Extract occupancy map (NBinsY x NBinsX)
            nNeurons = size(data, 3); % Number of neurons
        
            mi = zeros(nNeurons, 1); % Initialize mutual information array
            p = zeros(nNeurons, 1);  % Initialize p-values array
        
            % Compute the probability distribution of occupancy
            P_pos = occupancy; % Occupancy is already normalized to sum to 1
        
            % Compute mutual information for each neuron
            pb = spiky.plot.ProgressBar(nNeurons, "Computing mutual information", Parallel=true);
            parfor ii = 1:nNeurons
                % Probability of firing given position (normalize over spatial bins)
                pRPos = data(:, :, ii) ./ sum(data(:, :, ii), "all", "omitnan");
        
                % Compute overall firing rate probability P(r)
                pR = sum(pRPos .* P_pos, "all", "omitnan");
        
                % Compute mutual information
                mi(ii) = sum(pRPos .* P_pos .* log2(pRPos ./ pR), "all", "omitnan");
        
                % Shuffle test for significance
                shuffled_mi = zeros(nShuffles, 1);
                for sh = 1:nShuffles
                    dataSh = data(:, :, ii); % Copy original data
                    dataSh = dataSh(randperm(numel(dataSh))); % Randomize firing rate bins
                    dataSh = reshape(dataSh, size(data(:, :, ii))); % Reshape to original size
                    pRPosSh = dataSh ./ sum(dataSh, "all", "omitnan");
                    shuffled_mi(sh) = sum(pRPosSh .* P_pos .* ...
                        log2(pRPosSh ./ pR), "all", "omitnan");
                end
                
                % Compute p-value
                p(ii) = mean(shuffled_mi >= mi(ii));
                pb.step
            end
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

        function binEdgesX = get.BinEdgesX(obj)
            binEdgesX = obj.BinEdges;
        end

        function obj = set.BinEdgesX(obj, binEdgesX)
            obj.BinEdges = binEdgesX;
        end

        function nBinsX = get.NBinsX(obj)
            nBinsX = obj.NBins;
        end

        function binCentersX = get.BinCentersX(obj)
            binCentersX = obj.BinCenters;
        end

        function nBinsY = get.NBinsY(obj)
            nBinsY = numel(obj.BinEdgesY) - 1;
        end

        function binCentersY = get.BinCentersY(obj)
            binCentersY = (obj.BinEdgesY(1:end-1) + obj.BinEdgesY(2:end)) / 2;
        end

        function resX = get.ResX(obj)
            resX = obj.Res;
        end

        function resY = get.ResY(obj)
            resY = obj.BinEdgesY(2) - obj.BinEdgesY(1);
        end
    end
end