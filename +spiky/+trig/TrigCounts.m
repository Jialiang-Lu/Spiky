classdef TrigCounts < spiky.trig.TrigFr
    %TRIGCOUNTS Class for counting spikes triggered by events

    properties
        Bernoulli logical = false % If true, counts are binary (0 or 1)
    end

    methods
        function obj = TrigCounts(start, step, fr, events, window, neuron, samples, options)
            arguments
                start double = NaN
                step double = NaN
                fr double = double.empty(0, 0, 0)
                events (:, 1) = NaN(width(fr), 1)
                window double {mustBeVector} = [0, 1]
                neuron spiky.core.Neuron = spiky.core.Neuron
                samples (:, 1) = NaN(size(fr, 4), 1)
                options.Bernoulli logical = false % If true, counts are binary (0 or 1)
            end
            obj@spiky.trig.TrigFr(start, step, fr, events, window, neuron, samples);
            obj.Bernoulli = options.Bernoulli;
        end

        function mdl = fitGlm(obj, labels, options)
            %FITGLM Fit a GLM to the counts
            %
            %   mdl = fitGlm(obj, options)
            %
            %   obj: TrigCounts
            %   options: Name-Value pairs for additional options
            %
            %   mdl: fitted GLM model
            arguments
                obj spiky.trig.TrigCounts
                labels spiky.stat.Labels
                options.Intervals = [] % (n, 2) double or spiky.core.Intervals
            end
            names = compose("%s.%s.%d", labels.Name, labels.Class, labels.BaseIndex);
            if obj.Bernoulli
                distr = "binomial";
            else
                distr = "poisson";
            end
            if ~isempty(options.Intervals)
                if isnumeric(options.Intervals)
                    options.Intervals = spiky.core.Intervals(options.Intervals);
                end
                [~, idc] = options.Intervals.haveEvents(obj.Time);
            else
                idc = true(height(obj.Time), 1);
            end
            dataRaw = obj.Data(idc, 1, :);
            data = cell(1, size(obj.Data, 3));
            pb = spiky.plot.ProgressBar(size(obj.Data, 3), "Fitting GLM", ...
                CloseOnFinish=false);
            parfor ii = 1:size(obj.Data, 3)
                data{ii} = fitglm(labels.Data(idc, :), dataRaw(:, :, ii), "linear", ...
                    Distribution=distr, VarNames=[names; "spikes"]);
                pb.step
            end
            mdl = spiky.stat.GLM(0, data, obj.Neuron);
        end
    end
end