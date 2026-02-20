classdef Neuron < spiky.core.Array
    %NEURON Represents a neuron recorded in an electrophysiology session
    %
    %   Fields:
    %       Session: spiky.ephys.Session object representing the recording session
    %       Group: probe number
    %       Id: unique identifier within the session and probe
    %       Region: brain region
    %       Ch: channel number within the session
    %       ChInGroup: channel number within the probe
    %       Label: unit label (e.g., "good", "mua", "noise")
    %       Amplitude: spike amplitude in microvolts

    methods (Static)
        function obj = zeros(n)
            %ZEROS Create an array of Neuron objects with all fields set to zero or empty
            %
            %   n: number of Neuron objects
            %
            %   obj: array of Neuron objects
            obj = repmat(spiky.core.Neuron(spiky.ephys.Session(""), 0, 0, 0, 0, 0, 0, 0), n, 1);
        end

        function obj = create(session, regions, nNeuronsPerRegion)
            %CREATE Create an array of Neuron objects with specified session, regions, and 
            %   number of neurons per region
            %
            %   session: spiky.ephys.Session object representing the recording session
            %   regions: array of brain regions
            %   nNeuronsPerRegion: number of neurons to create for each region
            %
            %   obj: array of Neuron objects
            arguments
                session spiky.ephys.Session
                regions (:, 1) categorical
                nNeuronsPerRegion (:, 1) double
            end
            if numel(nNeuronsPerRegion)==1
                nNeuronsPerRegion = repmat(nNeuronsPerRegion, numel(regions), 1);
            end
            nNeurons = sum(nNeuronsPerRegion);
            obj = spiky.core.Neuron.zeros(nNeurons);
            obj.Data.Session = repmat(session, nNeurons, 1);
            obj.Data.Region = repelem(regions, nNeuronsPerRegion);
            obj.Data.Group = repelem((1:numel(regions))', nNeuronsPerRegion);
            obj.Data.Id = grouptransform(obj.Data.Group, obj.Data.Group, @(x) (1:numel(x))');
        end
    end

    methods
        function obj = Neuron(session, group, id, region, ch, chInGroup, label, amplitude)
            arguments
                session (:, 1) spiky.ephys.Session = spiky.ephys.Session
                group (:, 1) double = []
                id (:, 1) double = []
                region (:, 1) categorical = categorical.empty
                ch (:, 1) double = []
                chInGroup (:, 1) double = []
                label (:, 1) categorical = categorical.empty
                amplitude (:, 1) double = []
            end
            obj = obj.initTable(Session=session, Group=group, Id=id, Region=region, Ch=ch, ...
                ChInGroup=chInGroup, Label=label, Amplitude=amplitude);
        end

        function str = string(obj)
            str = compose("%s_%s_%d", obj.Data.Session.Name, obj.Data.Region, obj.Data.Id);
        end

        function out = eq(obj, other)
            out = obj.Session == other.Session & obj.Group == other.Group & obj.Id == other.Id;
        end
    end
end