classdef Labels < spiky.core.TimeTable
    % LABELS Class for behavior and stimulus labels for training classifiers and linear models

    properties
        Name (:, 1) categorical = categorical.empty(0, 1); % Name of each label
        Class (:, 1) categorical = categorical.empty(0, 1); % Class of each label after one-hot encoding
        BaseIndex (:, 1) double = double.empty(0, 1); % BaseIndex of each label after basis expansion
        Bases spiky.stat.Coords = spiky.stat.Coords.empty; % Basis functions
    end

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = ["Time" "Name,Class,BaseIndex"];
        end
    end

    methods
        function obj = Labels(time, varargin)
            % LABELS Constructor for Labels class
            %   obj = Labels(time, tt1, tt2, ...)
            %
            %   time: time vector
            %   tt1, tt2, ...: TimeTables with labels
            arguments
                time (:, 1) double = double.empty(0, 1);
            end
            arguments (Repeating)
                varargin
            end
            if isempty(time)
                return
            end
            obj.Time = time;
            obj.Data = table(Size=[numel(time), 0], VariableNames=string.empty);
            if ~isempty(varargin)
                obj = obj.addLabels(varargin{:});
            end
        end

        function obj = addLabels(obj, varargin)
            % ADDLABELS Add labels to the Labels object
            %   obj = ADDLABELS(obj, tt1, tt2, ...)
            %
            %   tt1, tt2, ...: TimeTables with labels
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
            % ADDLABEL Add a single label to the Labels object
            %   obj = ADDLABEL(obj, tt, options)
            %
            %   tt: TimeTable with labels
            %   options: Name-Value pairs for additional options
            arguments
                obj spiky.stat.Labels
                tt spiky.core.TimeTable
                options.Name string = string.empty
            end
            if ~isa(tt, "spiky.core.TimeTable")
                error("Input must be a TimeTable.");
            end
            data = tt.densify(obj.Time);
            if isnumeric(data) || islogical(data) || isstring(data) || iscategorical(data)
                if isempty(options.Name)
                    options.Name = sprintf("Label%d", width(obj.Data)+1);
                end
                data = table(data, VariableNames=[options.Name]);
            elseif istable(data) && ~isempty(options.Name)
                n = min(width(data), numel(options.Name));
                data = renamevars(data, data.Properties.VariableNames(1:n), options.Name(1:n));
            else
                error("Unsupported data type %s for labels.", class(data));
            end
            obj.Data = [obj.Data, data];
            obj.Name = [obj.Name; categorical(options.Name)];
            obj.Class = [obj.Class; categorical("")];
            obj.BaseIndex = [obj.BaseIndex; 1];
            obj.Bases = [obj.Bases; 1];
        end

        function obj = expand(obj, options)
            % EXPAND Expand the labels with basis functions
            %   obj = EXPAND(obj, ...)
            %
            %   Name-Value pairs:
            arguments
                obj spiky.stat.Labels
                options.ExcludeFromOneHot (1, :) string = string.empty
                options.BaseType (1, 1) string {mustBeMember(options.BaseType, ["RaisedCosine"])} = "RaisedCosine"
                options.NBases (1, 1) double {mustBeInteger, mustBePositive} = 1
                options.PeakRange (1, 2) double = [0 0]
                options.TimeRange (1, 2) double = [NaN, NaN]
                options.Spacing (1, 1) string {mustBeMember(options.Spacing, ["Log","Linear"])} = "Log"
            end

            %% One-hot encode tabular data
            if istable(obj.Data)
                varNames = string(obj.Data.Properties.VariableNames);
                names = categorical.empty(0, 1);
                classes = categorical.empty(0, 1);
                latencies = double.empty(0, 1);
                bases = double.empty(0, 1);
                data = double.empty(height(obj.Data), 0);
                for ii = 1:numel(varNames)
                    varName = varNames(ii);
                    data1 = obj.Data.(varName);
                    if ismember(varName, options.ExcludeFromOneHot)
                        if ~isnumeric(data1)
                            error("Cannot exclude non-numeric variable %s from one-hot encoding.", varName);
                        end
                        n1 = width(data1);
                        classes1 = categorical(strings(n1, 1));
                    else
                        classes1 = unique(data1(~ismissing(data1)));
                        if iscategorical(classes1)
                            classes1 = string(classes1);
                        end
                        data1 = onehotencode(data1, 2, ClassNames=classes1);
                        data1(isnan(data1)) = 0;
                        n1 = width(data1);
                    end
                    data = [data, data1];
                    names = [names; categorical(repmat(varName, n1, 1))];
                    classes = [classes; categorical(classes1)];
                    latencies = [latencies; ones(n1, 1)];
                    bases = [bases; ones(n1, 1)];
                end
                obj.Data = data;
                obj.Name = names;
                obj.Class = classes;
                obj.BaseIndex = latencies;
                obj.Bases = bases;
            end

            %% Expand the labels with basis functions
            if width(obj.Bases)>1 || options.NBases==1 % already expanded or no expansion needed
                return
            end
            coords = spiky.stat.Coords.makeRaisedCosine(...
                obj.Time(2)-obj.Time(1), ...
                options.NBases, ...
                options.PeakRange, ...
                TimeRange=options.TimeRange, ...
                Spacing=options.Spacing);
            data = zeros(height(obj), options.NBases*width(obj.Data));
            for ii = 1:options.NBases
                data(:, (ii-1)*width(obj.Data)+1:ii*width(obj.Data)) = ...
                    convn(obj.Data, coords.Bases(:, ii), "same");
            end
            obj.Name = repmat(obj.Name, options.NBases, 1);
            obj.Class = repmat(obj.Class, options.NBases, 1);
            obj.BaseIndex = reshape(repmat(1:options.NBases, width(obj.Data), 1), [], 1);
            obj.Bases = reshape(repmat(permute(coords.Bases, [1 3 2]), 1, width(obj.Data)), [], width(data), 1).';
            obj.Data = data;
        end
    end
end