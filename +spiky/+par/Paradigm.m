classdef Paradigm < spiky.minos.Paradigm
    %PARADIGM represents a paradigm data structure for analysis

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
            obj.Data.Name = name;
            obj.Data.Intervals = par.Intervals;
            obj.Data.Trials = par.Trials;
            obj.Data.TrialInfo = par.TrialInfo;
            obj.Data.Vars = par.Vars;
            obj.Data.Latency = par.Latency;
            obj.Data.Session = minos.Session;
        end
    end
end