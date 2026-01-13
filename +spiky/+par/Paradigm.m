classdef Paradigm < spiky.minos.Paradigm
    %PARADIGM represents a paradigm data structure for analysis

    properties
        Session spiky.ephys.Session % Session object
    end

    methods
        function obj = Paradigm(minos, name)
            %PARADIGM represents a paradigm data structure for analysis
            arguments
                minos spiky.minos.MinosInfo = spiky.minos.MinosInfo
                name string = string.empty
            end
            if isempty(minos)
                return
            end
            par = minos.Paradigms.(name);
            obj.Name = par.Name;
            obj.Intervals = par.Intervals;
            obj.Trials = par.Trials;
            obj.TrialInfo = par.TrialInfo;
            obj.Vars = par.Vars;
            obj.Session = minos.Session;
            obj.Latency = par.Latency;
        end
    end
end