classdef Labels < spiky.core.EventsTable
    %LABELS Class for behavior and stimulus labels for training classifiers and linear models

    properties
        Name (:, 1) categorical % Name of each label
        IsEvent (:, 1) logical % If the label is an event (not a state)
        Class (:, 1) categorical % Class of each label after one-hot encoding
        BaseIndex (:, 1) double % BaseIndex of each label after basis expansion
        Bases spiky.stat.TimeCoords % Basis functions
        Trial (:, 1) double % Trial indices for each time point
        Offset (:, 1) double % Time offset for each time point
    end

    properties (Dependent)
        VarName (:, 1) string % Name.Class.BaseIndex
        Expanded (1, 1) logical % If the labels have been expanded with basis functions
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the EventsTable
            %
            %   dimNames: dimension names
            dimNames = ["Time,Trial,Offset" "Name,IsEvent,Class,BaseIndex"];
        end

        function [data, isEvent] = preprocess(tt, t, mode)
            %PREPROCESS Preprocess the input EventsTable for adding as labels
            %
            %   [data, isEvent] = PREPROCESS(tt, t, mode)
            %
            %   tt: input EventsTable or IntervalsTable or numeric array
            %   t: time vector
            %   mode:
            %       "event": tt is a EventsTable with event labels (default)
            %       "state": tt is a EventsTable or IntervalsTable with state labels
            %       "trigger": tt is a EventsTable where only the time points are taken as events
            %
            %   data: preprocessed data
            %   isEvent: if the data represents events
            arguments
                tt % EventsTable or IntervalsTable or numeric array
                t (:, 1) double
                mode (1, 1) string {mustBeMember(mode, ["event" "state" "trigger"])} = "event"
            end
            if isa(tt, "spiky.core.IntervalsTable")
                mode = "state";
                data = tt.interp(t);
                isEvent = false;
            elseif isa(tt, "spiky.core.EventsTable") && mode=="state"
                data = tt.interp(t, "previous");
                isEvent = false;
            elseif isa(tt, "spiky.core.EventsTable") && mode=="event"
                data = tt.densify(t);
                isEvent = true;
            elseif isa(tt, "spiky.core.EventsTable") && mode=="trigger"
                tt.Data = true(height(tt), 1);
                data = tt.densify(t);
                isEvent = true;
            elseif isnumeric(tt)
                tt = spiky.core.EventsTable(tt, true(height(tt), 1));
                mode = "trigger";
                data = tt.densify(t);
                isEvent = true;
            else
                error("Input must be a EventsTable or IntervalsTable.");
            end
            if istable(data)
                data = data{:, 1};
            end
            assert(isnumeric(data) || islogical(data) || isstring(data) || iscategorical(data), ...
                "Unsupported data type %s for labels.", class(data));
        end
    end

    methods
        function obj = Labels(time, window, options)
            %LABELS Constructor for Labels class
            %   obj = Labels(time, window)
            %
            %   time: time vector
            %   [window]: optional time window for each trial. If not empty, the object represents
            %       labels over multiple trials with the same time window.
            %   Name-Value pairs:
            %       Expanded: if true, the labels have been expanded with basis functions (default: false)
            arguments
                time (:, 1) double = double.empty(0, 1)
                window (:, 1) double = []
                options.Expanded logical = false
            end
            if isempty(time)
                return
            end
            obj.Time = time;
            if options.Expanded
                obj.Data = double.empty(height(time), 0);
            else
                obj.Data = table(Size=[numel(time), 0], VariableNames=string.empty);
            end
            if ~isempty(window)
                nTrials = numel(time)/numel(window);
                assert(mod(nTrials, 1)==0, "Time length must be multiple of window length.");
                obj.Trial = repelem((1:nTrials).', numel(window));
                obj.Offset = repmat(window, nTrials, 1);
            else
                obj.Trial = ones(numel(time), 1);
                obj.Offset = time;
            end
        end

        function obj = addLabels(obj, varargin)
            %ADDLABELS Add labels to the Labels object
            %   obj = ADDLABELS(obj, tt1, tt2, ...)
            %
            %   tt1, tt2, ...: EventsTables with labels
            arguments
                obj spiky.stat.Labels
            end
            arguments (Repeating)
                varargin
            end
            for ii = 1:numel(varargin)
                obj = obj.addLabel(varargin{ii});
            end
        end

        function obj = addLabel(obj, tt, options)
            %ADDLABEL Add a single label to the Labels object
            %   obj = ADDLABEL(obj, tt, options)
            %
            %   tt: EventsTable or IntervalsTable with labels
            %   Name-Value pairs:
            %       Name: name of the label (default: "LabelN" where N is the next available index)
            %       Mode:
            %           "event": tt is a EventsTable with event labels (default)
            %           "state": tt is a EventsTable or IntervalsTable with state labels
            %           "trigger": tt is a EventsTable where only the time points are taken as events
            %       Categorize: if true, convert the label data to categorical (default: false)
            arguments
                obj spiky.stat.Labels
                tt % spiky.core.EventsTable or spiky.core.IntervalsTable
                options.Name string = string.empty
                options.Mode (1, 1) string {mustBeMember(options.Mode, ["event" "state" "trigger"])} = "event"
                options.Categorize (1, 1) logical = false
            end
            [data, isEvent] = spiky.stat.Labels.preprocess(tt, obj.Time, options.Mode);
            if isempty(options.Name)
                options.Name = sprintf("Label%d", width(obj.Data)+1);
            end
            data = table(data, VariableNames=[options.Name]);
            if options.Categorize
                data.(options.Name) = categorical(data.(options.Name));
            end
            obj.Data = [obj.Data, data];
            obj.Name = [obj.Name; categorical(options.Name)];
            obj.IsEvent = [obj.IsEvent; isEvent];
            obj.Class = [obj.Class; categorical("")];
            obj.BaseIndex = [obj.BaseIndex; 0];
        end

        function obj = addExpandedLabel(obj, tt, bases, options)
            %ADDEXPANDEDLABEL Add an expanded label to the Labels object
            %   obj = ADDEXPANDEDLABEL(obj, tt, bases)
            %
            %   tt: EventsTable or IntervalsTable with labels
            %   bases: TimeCoords with basis functions
            %   Name-Value pairs:
            %       Name: name of the label
            %       Mode:
            %           "event": tt is a EventsTable with event labels (default)
            %           "state": tt is a EventsTable or IntervalsTable with state labels
            %           "trigger": tt is a EventsTable where only the time points are taken as events
            arguments
                obj spiky.stat.Labels
                tt % spiky.core.EventsTable or spiky.core.IntervalsTable
                bases spiky.stat.TimeCoords = spiky.stat.TimeCoords
                options.Name string
                options.Mode (1, 1) string {mustBeMember(options.Mode, ["event" "state" "trigger"])} = "event"
            end
            [data, isEvent] = spiky.stat.Labels.preprocess(tt, obj.Time, options.Mode);
            [data, classes] = spiky.utils.flagsencode(data);
            n = width(data);
            if isEvent && ~isempty(bases)
                data = bases.expand(spiky.core.EventsTable(obj.Time, data));
                data = data.Data;
                basesIdc = repmat((1:bases.NBases).', n, 1);
                classes = repelem(classes, bases.NBases, 1);
                n = width(data);
            else
                basesIdc = zeros(n, 1);
            end
            obj.Data = [obj.Data, data];
            obj.Name = [obj.Name; repmat(categorical(options.Name), n, 1)];
            obj.IsEvent = [obj.IsEvent; repmat(isEvent, n, 1)];
            obj.Class = [obj.Class; classes];
            obj.BaseIndex = [obj.BaseIndex; basesIdc];
        end

        function obj = expand(obj, bases, options)
            %EXPAND Expand the labels with basis functions
            %   obj = EXPAND(obj, ...)
            %
            %   Name-Value pairs:
            arguments
                obj spiky.stat.Labels
                bases spiky.stat.TimeCoords = spiky.stat.TimeCoords
                options.ExcludeFromOneHot (1, :) string = string.empty
            end

            %% One-hot encode tabular data and expand event labels
            varNames = string(obj.Data.Properties.VariableNames);
            nVars = numel(varNames);
            % names = categorical.empty(0, 1);
            % isEvents = logical.empty(0, 1);
            % classes = categorical.empty(0, 1);
            % basesIdc = double.empty(0, 1);
            % data = double.empty(height(obj.Data), 0);
            names = cell(nVars, 1);
            isEvents = cell(nVars, 1);
            classes = cell(nVars, 1);
            basesIdc = cell(nVars, 1);
            data = cell(1, nVars);
            parfor ii = 1:nVars
                varName = varNames(ii);
                data1 = obj.Data.(varName);
                if ismember(varName, options.ExcludeFromOneHot)
                    if ~isnumeric(data1)
                        error("Cannot exclude non-numeric variable %s from one-hot encoding.", varName);
                    end
                    classes1 = categorical(NaN(width(data1), 1));
                else
                    [data1, classes1] = spiky.utils.flagsencode(data1);
                end
                n1 = width(data1);
                if obj.IsEvent(ii) && ~isempty(bases)
                    % if n1>1
                    %     data1 = [any(data1, 2), data1]; % add a column for "any event type"
                    %     classes1 = [categorical("*"); classes1];
                    %     n1 = n1+1;
                    % end
                    data1 = bases.expand(spiky.core.EventsTable(obj.Time, data1));
                    data1 = data1.Data;
                    basesIdc1 = repmat((1:bases.NBases).', n, 1);
                    classes1 = repelem(classes1, bases.NBases, 1);
                    n1 = width(data1);
                else
                    basesIdc1 = zeros(n1, 1);
                end
                names{ii} = repmat(varName, n1, 1);
                isEvents{ii} = repmat(obj.IsEvent(ii), n1, 1);
                classes{ii} = classes1;
                basesIdc{ii} = basesIdc1;
                data{ii} = data1;
            end
            obj.Data = cell2mat(data);
            obj.Name = cell2mat(names);
            obj.IsEvent = cell2mat(isEvents);
            obj.Class = cell2mat(classes);
            obj.BaseIndex = cell2mat(basesIdc);
            obj.Bases = bases;
        end

        function obj = reduce(obj)
            %REDUCE Reduce the Labels object by combining base-expanded labels
            %   obj = REDUCE(obj)
            assert(obj.Expanded, "Labels must be expanded to be reduced.");
            [data, groups] = groupsummary(obj.Data', {obj.Name, obj.IsEvent, obj.Class}, "sum");
            obj.Data = data';
            obj.Name = groups{1};
            obj.IsEvent = groups{2};
            obj.Class = groups{3};
            obj.BaseIndex = zeros(size(obj.Name));
        end

        function varName = get.VarName(obj)
            %GET.VARNAME Get the variable names in the format Name.Class.BaseIndex
            varName = compose("%s.%s.%d", obj.Name, obj.Class, obj.BaseIndex);
        end

        function expanded = get.Expanded(obj)
            %GET.EXPANDED Get if the labels have been expanded with basis functions
            expanded = isnumeric(obj.Data);
        end

        function image(obj)
            %IMAGE Visualize the labels as an image
            assert(obj.Expanded, "Labels must be expanded to be visualized as an image.");
            imagesc(obj.Time, 1:width(obj.Data), obj.Data.');
            xlabel("Time (s)");
            yticks(1:width(obj.Data));
            yticklabels(obj.VarName);
        end
    end
end