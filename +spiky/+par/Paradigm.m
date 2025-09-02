classdef Paradigm < spiky.minos.Paradigm
    % PARADIGM represents a paradigm data structure for analysis

    methods
        function obj = Paradigm(par)
            % PARADIGM represents a paradigm data structure for analysis
            arguments
                par spiky.minos.Paradigm
            end
            obj.Name = par.Name;
            obj.Periods = par.Periods;
            obj.Trials = par.Trials;
            obj.TrialInfo = par.TrialInfo;
            obj.Vars = par.Vars;
        end
    end
end