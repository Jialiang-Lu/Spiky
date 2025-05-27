classdef Subspaces < spiky.stat.GroupedStat
    %Subspaces Class representing a set of subspaces

    methods
        function obj = Subspaces(time, data, groups, groupIndices)
            %Subspaces Create a new instance of Subspaces
            %
            %   Subspaces(time, data, groups) creates a new instance of Subspaces
            %
            %   time: time points
            %   data: coordinates
            %   groups: groups
            %   groupIndices: indices of the groups
            %
            %   obj: Subspaces object
            arguments
                time double = []
                data spiky.stat.Coords = spiky.stat.Coords.empty
                groups = []
                groupIndices cell = {}
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices);
        end

        function data = project(obj, data, idcDim)
            %PROJECT Project the data onto the coordinates
            %
            %   data = PROJECT(obj, data)
            %
            %   obj: Subspaces
            %   data: data to project, nT x nEvents x nNeurons
            %   idcDim: indices of the dimensions to project
            %
            %   data: projected data
            arguments
                obj spiky.stat.Subspaces
                data
                idcDim double = []
            end
            if isa(data, "spiky.core.TimeTable")
                V = data.Data;
            elseif isnumeric(data)
                V = data;
            else
                error("Data must be a numeric array or a spiky.core.TimeTable")
            end
            nT = size(V, 1);
            nEvents = size(V, 2);
            nNeurons = size(V, 3);
            nBases = obj.Data(1).NBases;
            if ~isempty(idcDim)
                nBases = numel(idcDim);
            end
            nGroups = obj.NGroups;
            nSamples = size(obj, 3);
            if nT~=height(obj)
                if height(obj)>1
                    error("The number of time points must be the same as the number of time points in the Subspaces")
                end
                idcT = ones(height(V), 1);
            else
                idcT = 1:height(V);
            end
            if nNeurons~=sum(cellfun(@numel, obj.GroupIndices))
                error("The number of neurons must be the same as the number of neurons in the Subspaces")
            end
            C = zeros(nT, nEvents, nBases, nGroups, nSamples);
            for ii = 1:nT
                idxT = idcT(ii);
                for jj = 1:nGroups
                    for kk = 1:nSamples
                        V1 = permute(V(ii, :, obj.GroupIndices{jj}), [3 2 1]);
                        C1 = obj.Data(idxT, jj, kk).project(V1, idcDim);
                        C(ii, :, :, jj, kk) = permute(C1, [3 2 1]);
                    end
                end
            end
            if isa(data, "spiky.core.TimeTable")
                data.Data = C;
                if isa(data, "spiky.core.Spikes")
                    data.Neuron = repmat(spiky.core.Neuron, nBases, 1);
                end
            else
                data = C;
            end
        end
    end
end