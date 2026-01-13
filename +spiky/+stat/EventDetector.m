classdef EventDetector < spiky.stat.Classifier

    properties
        Bases spiky.stat.TimeCoords % Kernel bases
        Subspaces spiky.stat.Subspaces % Subspaces used for classification
        Partition % Cross-validation partition
        PartitionIntervals spiky.core.Intervals % Intervals for each partition
        Options struct % Options used for training the event detector
    end

    methods
        function obj = EventDetector(time, data, groups, groupIndices, conditions)
            arguments
                time double = []
                data cell = {}
                groups string = ""
                groupIndices cell = {}
                conditions categorical = categorical(zeros(size(data, 3), 1))
            end
            obj@spiky.stat.Classifier(time, data, groups, groupIndices, conditions);
        end
    end
end