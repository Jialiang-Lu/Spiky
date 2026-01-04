classdef PassiveFixation < spiky.par.Paradigm
    %PASSIVEFIXATION Class representing a passive fixation paradigm

    properties
        Stimuli struct % struct of spiky.minos.Stimuli
    end

    methods
        function obj = PassiveFixation(minos)
            %PASSIVEFIXATION Construct a PassiveFixation object
            arguments
                minos spiky.minos.MinosInfo
            end
            obj@spiky.par.Paradigm(minos, "PassiveFixation");
            stimulusSets = cell2mat(obj.Vars.StimulusSets.get(0));
            stimulusSets = unique(extractBefore(stimulusSets, " ("|textBoundary("end")));
            obj.Stimuli = struct();
            for ii = 1:length(stimulusSets)
                setName = stimulusSets(ii);
                obj.Stimuli.(setName) = minos.loadStimuli(setName);
            end
        end

        function trigFr = getResponseMatrix(obj, stimulusSet, spikes, latency)
            arguments
                obj spiky.par.PassiveFixation
                stimulusSet (1, 1) string
                spikes (:, 1) spiky.core.Spikes
                latency (1, 1) double = 0.05
            end
            assert(isfield(obj.Stimuli, stimulusSet), ...
                "Stimulus set '%s' not found in the paradigm", stimulusSet);
            stim = obj.Stimuli.(stimulusSet);
            trials = obj.getTrials("StimulusSets", stimulusSet);
            trials = trials(~isnan(trials.End_Correct), :);
            nTrials = trials.Length;
            % trialClass = stim.Label(trials.Stimulus+1);
            t1 = trials.Start_Align(1);
            stimOn = obj.Vars.StimulusOnMs.get(t1)/1000;
            stimOff = obj.Vars.StimulusOffMs.get(t1)/1000;
            trigSpikesOn = spikes.trig(trials.Start_Align, [0 stimOn]+latency);
            trigSpikesOff = spikes.trig(trials.Start_Align, [-stimOff 0]+latency);
            frOn = trigSpikesOn.getFr([], trials.Stimulus+1);
            frOff = trigSpikesOff.getFr([], 0);
            isValidUnit = frOff.Data>-Inf;
            isValidUnit = isValidUnit(:);
            frOn = frOn(:, :, isValidUnit);
            frOff = frOff(:, :, isValidUnit);
            trigFr = frOn;
            trigFr.Data = (frOn.Data-frOff.Data)./frOff.Data;
            trigFr.Events = stim.Label;
        end
    end
end