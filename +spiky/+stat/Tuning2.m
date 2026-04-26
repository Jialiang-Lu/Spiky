classdef Tuning2 < spiky.stat.Tuning
    %TUNING2 2D continuous tuning curve
    %   First dimension: y-axis bins
    %   Second dimension: x-axis bins
    %   Third dimension: neurons
    %   Fourth dimension: conditions (optional)

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
            dimLabelNames = {"BinEdgesY"; "BinEdgesX"; ["Neuron"; "Fr"; "P"]; "Conditions"};
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
                options.Fr (:, 1) double = squeeze(mean(fr, [1 2], Weights=occupancy))
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
    end
end