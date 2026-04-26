classdef PooledSession < spiky.core.Array
    %PooledSession Class representing a pooled session across multiple recording sessions

    properties (Dependent)
        Neuron (:, 1) spiky.core.Neuron
    end

    methods (Static)
        function obj = load(fn, options)
            %LOAD Load a PooledSession object from a session
            arguments
                fn (1, 1) string
                options.RegionSubset (:, 1) string = string.empty
            end
            fprintf("Loading session from %s\n", fn);
            ses = spiky.ephys.Session(fn);
            fprintf("Loading session info...\n");
            info = ses.getInfo;
            fprintf("Loading minos...\n");
            minos = ses.getMinos;
            fprintf("Loading transform...\n");
            tr = ses.getTransform;
            fprintf("Loading spikes...\n");
            spikes = ses.getSpikes(RegionSubset=options.RegionSubset);
            obj = spiky.par.PooledSession(ses, info, minos, tr, spikes);
            fprintf("Session loaded for %s\n", fn);
        end
    end

    methods
        function obj = PooledSession(ses, info, minos, tr, spikes, par)
            %PooledSession Create a new instance of PooledSession
            arguments
                ses spiky.ephys.Session = spiky.ephys.Session.empty
                info spiky.ephys.SessionInfo = spiky.ephys.SessionInfo.empty
                minos spiky.minos.MinosInfo = spiky.minos.MinosInfo.empty
                tr spiky.minos.Transform = spiky.minos.Transform.empty
                spikes spiky.core.Spikes = spiky.core.Spikes.empty
                par spiky.par.Paradigm = spiky.par.Paradigm.empty
            end
            obj.Data = struct;
            obj.Data.Session = ses;
            obj.Data.Info = info;
            obj.Data.Minos = minos;
            obj.Data.Tr = tr;
            obj.Data.Spikes = spikes;
            obj.Data.Par = par;
        end

        function neuron = get.Neuron(obj)
            spikes = vertcat(obj.Data.Spikes);
            neuron = spikes.Neuron;
        end
    end
end