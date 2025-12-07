classdef Neuron < spiky.core.ArrayTable

    methods (Static)
        function index = getScalarDimension()
            %GETSCALARDIMENSION Get the scalar dimension of the ArrayTable
            %
            %   index: index of the scalar dimension, 0 means no scalar dimension, 
            %       1 means obj(idx) equals obj(idx, :), 2 means obj(idx) equals obj(:, idx), etc.
            index = 1;
        end

        function b = isScalarRow()
            %ISSCALARROW if each row contains heterogeneous data and should be treated as a scalar
            %   This is useful if the Data is a table or a cell array and the number of columns is fixed.
            %
            %   b: true if each row is a scalar, false otherwise
            b = true;
        end

        function obj = zeros(n)
            %ZEROS Create an array of Neuron objects with all fields set to zero or empty
            %
            %   n: number of Neuron objects
            %
            %   obj: array of Neuron objects
            obj = repmat(spiky.core.Neuron(spiky.ephys.Session, 0, 0, 0, 0, 0, 0, {}), n, 1);
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

        function str = string(obj)
            str = compose("%s_%s_%d", [obj.Data.Session.Name]', obj.Data.Region, obj.Data.Id);
        end

        function out = eq(obj, other)
            out = obj.Session == other.Session & obj.Group == other.Group & obj.Id == other.Id;
        end
    end
end