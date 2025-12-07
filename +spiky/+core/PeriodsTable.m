classdef PeriodsTable < spiky.core.Periods & spiky.core.ArrayTable
    %PERIODSTABLE Represents data indexed by time intervals in seconds

    methods (Static)
        function dimNames = getDimNames()
            %GETDIMNAMES Get the dimension names of the TimeTable
            %
            %   dimNames: dimension names
            dimNames = "Time";
        end
    end

    methods
        function obj = PeriodsTable(periods, data)
            %PERIODSTABLE Create a new instance of PeriodsTable
            %
            %   PeriodsTable(periods, data) creates a new instance of PeriodsTable
            %
            %   periods: Nx2 matrix of start and end times
            %   data: data associated with each period
            arguments
                periods (:, 2) double = double.empty(0, 2)
                data = []
            end
            if isempty(periods) && isempty(data)
                return
            end
            if height(periods) ~= height(data)
                error("The number of periods and the number of rows in data must be the same")
            end
            obj.Time = periods;
            obj.Data = data;
        end

        function periods = and(obj, periods)
            %AND Intersect with another periods object
            periods = and@spiky.core.Periods(obj, periods);
        end

        function periods = or(obj, periods)
            %OR Union with another periods object
            periods = or@spiky.core.Periods(obj, periods);
        end

        function periods = minus(obj, periods)
            %MINUS Subtract another periods object
            periods = minus@spiky.core.Periods(obj, periods);
        end

        function [obj, idc] = sort(obj, direction)
            %SORT Sort data by time
            %
            %   direction: 'ascend' or 'descend'
            %
            %   obj: sorted PeriodsTable
            %   idc: indices of the sorted data
            arguments
                obj spiky.core.PeriodsTable
                direction string {mustBeMember(direction, ["ascend" "descend"])} = "ascend"
            end

            [obj, idc] = sort@spiky.core.Periods(obj, direction);
            obj.Data = obj.Data(idc, :);
        end

        function tt = toTimeTable(obj, mode)
            %TOTIMETABLE Convert to TimeTable
            %   tt = TOTIMETABLE(obj)
            %
            %   obj: PeriodsTable, which data must be categorial or logical
            %
            %   tt: TimeTable
            arguments
                obj spiky.core.PeriodsTable
                mode string {mustBeMember(mode, ["change" "start" "end"])} = "change"
            end
            switch mode
                case "start"
                    tt = spiky.core.TimeTable(obj.Time(:, 1), obj.Data);
                case "end"
                    tt = spiky.core.TimeTable(obj.Time(:, 2), obj.Data);
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
                    tt = spiky.core.TimeTable(t, data2);
                otherwise
                    error("Invalid mode");
            end
        end

        function out = interp(obj, t, options)
            %INTERP Interpolate the data at specific time points
            %
            %   out = interp(obj, t, options)
            %
            %   obj: PeriodsTable
            %   t: time points
            %   options: Name-Value pairs for additional options
            %
            %   out: interpolated data
            arguments
                obj spiky.core.PeriodsTable
                t double
                options.AsTimeTable (1, 1) logical = false
            end
            optionArgs = namedargs2cell(options);
            out = obj.toTimeTable().interp(t, "previous", "extrap", optionArgs{:});
        end

        function [h, hText] = plotStates(obj, plotOps)
            %PLOTSTATES Plot the states over time
            %   [h, hText] = PLOTSTATES(obj, options)
            %
            %   obj: PeriodsTable, which data must be categorial or logical or string
            %
            %   h: line handle
            %   hText: text handle
            arguments
                obj spiky.core.PeriodsTable
                plotOps.?matlab.graphics.chart.primitive.Line
            end
            if istable(obj.Data)
                data = string(obj.Data{:, 1});
            else
                data = string(obj.Data(:, 1));
            end
            plotArgs = namedargs2cell(plotOps);
            [labels, ~, idc] = unique(data);
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