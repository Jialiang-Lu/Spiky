classdef Neuron < spiky.core.ArrayTable

    properties (Dependent)
        Str string
    end

    methods (Static)
        function index = getScalarDimension()
            %GETSCALARDIMENSION Get the scalar dimension of the ArrayTable
            %
            %   index: index of the scalar dimension, 0 means no scalar dimension, 
            %       1 means obj(idx) equals obj(idx, :), 2 means obj(idx) equals obj(:, idx), etc.
            index = 1;
        end
    end

    methods
        function obj = Neuron(session, group, id, region, ch, chInGroup, label, waveform)
            arguments
                session spiky.ephys.Session = spiky.ephys.Session.empty
                group double = []
                id double = []
                region categorical = categorical.empty
                ch double = []
                chInGroup double = []
                label categorical = categorical.empty
                waveform cell = cell.empty
            end
            if numel(session)~= numel(group) || ...
               numel(session) ~= numel(id) || ...
               numel(session) ~= numel(region) || ...
               numel(session) ~= numel(ch) || ...
               numel(session) ~= numel(chInGroup) || ...
               numel(session) ~= numel(label) || ...
               (numel(session) ~= numel(waveform) && ~isempty(waveform))
                error("All input arguments must have the same number of elements.");
            end
            if ~isempty(waveform)
                amplitude = cellfun(@(w) max(w.Data) - min(w.Data), waveform);
            else
                waveform = cell(size(session));
                amplitude = zeros(size(session));
            end
            obj@spiky.core.ArrayTable(...
                table(session, group, id, region, ch, chInGroup, label, waveform, amplitude, ...
                VariableNames=["Session" "Group" "Id" "Region" "Ch" "ChInGroup" "Label" "Waveform" "Amplitude"]));
        end

        function str = get.Str(obj)
            str = compose("%s_%s_%d", obj.Session.Name, obj.Region, obj.Id);
        end

        function out = eq(obj, other)
            out = obj.Session == other.Session & obj.Group == other.Group & obj.Id == other.Id;
        end
    end
end