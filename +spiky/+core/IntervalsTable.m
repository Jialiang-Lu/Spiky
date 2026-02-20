classdef IntervalsTable < spiky.core.Intervals & spiky.core.Array
    %INTERVALSTABLE Represents data indexed by time intervals in seconds

    methods (Static)
        function dimLabelNames = getDimLabelNames()
            %GETDIMLABELNAMES Get the names of the label arrays for each dimension.
            %   Each label array has the same height as the corresponding dimension of Data.
            %   Each cell in the output is a string array of property names.
            %   This method should be overridden by subclasses if dimension label properties is added.
            %
            %   dimLabelNames: dimension label names
            arguments (Output)
                dimLabelNames (:, 1) cell
            end
            dimLabelNames = {"Time"};
        end

        function dataNames = getDataNames()
            %GETDATANAMES Get the names of all data properties.
            %   These properties must all have the same size. The first one is assumed to be the 
            %   main Data property.
            %
            %   dataNames: data property names
            arguments (Output)
                dataNames (:, 1) string
            end
            dataNames = "Data";
        end
    end

    methods
        function obj = IntervalsTable(intervals, data)
            %INTERVALSTABLE Create a new instance of IntervalsTable
            %
            %   IntervalsTable(intervals, data) creates a new instance of IntervalsTable
            %
            %   intervals: Nx2 matrix of start and end times
            %   data: data associated with each interval
            arguments
                intervals (:, 2) double = double.empty(0, 2)
                data = []
            end
            assert(height(intervals)==height(data), ...
                "The number of intervals and the number of rows in data must be the same")
            obj.Time = intervals;
            obj.Data = data;
        end

        function tt = toEventsTable(obj, mode)
            %TOTIMETABLE Convert to EventsTable
            %   tt = TOTIMETABLE(obj)
            %
            %   obj: IntervalsTable, which data must be categorial or logical
            %
            %   tt: EventsTable
            arguments
                obj spiky.core.IntervalsTable
                mode string {mustBeMember(mode, ["change" "start" "end"])} = "change"
            end
            switch mode
                case "start"
                    tt = spiky.core.EventsTable(obj.Time(:, 1), obj.Data);
                case "end"
                    tt = spiky.core.EventsTable(obj.Time(:, 2), obj.Data);
                case "change"
                    data = obj.Data;
                    isTable = istable(data);
                    if ~isTable
                        data = table(data, VariableNames="Data");
                    end
                    per = obj.Time;
                    n = height(per);
                    t = per(:);
                    [t, idcT] = sort(t);
                    names = data.Properties.VariableNames;
                    data2 = table.empty(numel(t), 0);
                    for ii = 1:numel(names)
                        data1 = data.(names{ii});
                        isLogical = islogical(data1);
                        [flags, valueset] = spiky.utils.flagsencode(data1);
                        flags = [flags; -flags];
                        flags = flags(idcT, :);
                        flags = cumsum(flags, 1);
                        flags(flags>1) = 1;
                        if isLogical
                            values = flags(:, 2)>0;
                        else
                            values = spiky.utils.flagsdecode(flags, valueset);
                        end
                        data2.(names{ii}) = values;
                    end
                    if ~isTable
                        data2 = data2.Data;
                    end
                    tt = spiky.core.EventsTable(t, data2);
                otherwise
                    error("Invalid mode");
            end
        end

        function out = interp(obj, t, options)
            %INTERP Interpolate the data at specific time points
            %
            %   out = interp(obj, t, options)
            %
            %   obj: IntervalsTable
            %   t: time points
            %   options: Name-Value pairs for additional options
            %
            %   out: interpolated data
            arguments
                obj spiky.core.IntervalsTable
                t double
                options.AsEventsTable (1, 1) logical = false
            end
            optionArgs = namedargs2cell(options);
            out = obj.toEventsTable().interp(t, "previous", "extrap", optionArgs{:});
        end

        function [h, hText] = plotStates(obj, idxVar, plotOps)
            %PLOTSTATES Plot the states over time
            %   [h, hText] = PLOTSTATES(obj, idxVar, options)
            %
            %   obj: IntervalsTable, which data must be categorial or logical or string
            %   idxVar: index of the variable to plot (or name if data is a table)
            %
            %   h: line handle
            %   hText: text handle
            arguments
                obj spiky.core.IntervalsTable
                idxVar (1, 1) = 1
                plotOps.?matlab.graphics.chart.primitive.Line
            end
            if istable(obj.Data)
                data = categorical(obj.Data{:, idxVar});
            else
                data = categorical(obj.Data(:, idxVar));
            end
            data(ismissing(data)) = "_";
            plotArgs = namedargs2cell(plotOps);
            labels = categories(data, OutputType="categorical");
            [~, idc] = ismember(data, labels);
            nLabels = numel(labels);
            x = obj.Time(:, [1 1 2 2])';
            y = zeros(4, width(x));
            y([2 3], :) = [idc'; idc'];
            h1 = plot(x(:), y(:), plotArgs{:});
            yticks(1:nLabels);
            yticklabels(labels);
            ylim([0 nLabels+1])
            if nargout>0
                h = h1;
            end
        end
    end
end