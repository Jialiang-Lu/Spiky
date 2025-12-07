classdef ANOVA < spiky.stat.GroupedStat
    %ANOVA Class representing analysis of variance (ANOVA) models
    %
    % The first dimension is time and the second dimension is the neurons.

    properties (Dependent)
        P double
    end

    methods
        function obj = ANOVA(time, factors, response, groups)
            %ANOVA performs analysis of variance
            %
            %   obj = ANOVA(time, factors, response, groups)
            %
            %   time: time points
            %   factors: factor vector
            %   response: response matrix nTime x nEvents x nNeurons
            %   groups: group labels
            arguments
                time double = []
                factors (:, 1) = []
                response (:, :, :) double = []
                groups (:, 1) = []
            end
            if isempty(time) || isempty(factors) || isempty(response)
                return
            end
            nT = numel(time);
            if size(response, 1)~=nT
                error("The number of time points and factors must be the same")
            end
            nEvents = numel(factors);
            if size(response, 2)~=nEvents
                error("The number of events must be the same as the number of factors")
            end
            nNeurons = numel(groups);
            if size(response, 3)~=nNeurons
                error("The number of neurons must be the same as the number of groups")
            end
            data = cell(nT, nNeurons);
            n = nT*nNeurons;
            parfor ii = 1:n
                [idxT, idxN] = ind2sub([nT, nNeurons], ii);
                data{ii} = anova(factors, permute(response(idxT, :, idxN), [2 1 3]));
            end
            obj.Time = time;
            obj.Data = data;
            obj.Groups = groups;
        end

        function p = get.P(obj)
            p = cellfun(@(x) x.stats.pValue(1), obj.Data);
        end
    end
end