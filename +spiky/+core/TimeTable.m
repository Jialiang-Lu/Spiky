classdef TimeTable < matlab.mixin.indexing.RedefinesParen & ...
    matlab.mixin.indexing.RedefinesBrace
    % TIMETABLE Represents data indexed by time points in seconds

    properties
        Time (:, 1) double
        Data (:, :)
    end

    methods (Static)
        function obj = empty(varargin)
            % EMPTY Create an empty instance of TimeTable
            obj = spiky.core.TimeTable();
        end
    end

    methods
        function obj = TimeTable(time, data)
            arguments
                time = []
                data = []
            end
            if isempty(data) && ~isempty(time)
                data = time;
                if isvector(data)
                    data = data(:);
                end
                time = 1:size(data, 1);
            end
            obj.Time = time(:);
            obj.Data = data;
            if length(obj.Time)~=size(obj.Data, 1)
                error("The number of time points and values must be the same")
            end
        end

        function periods = findPeriods(obj, thr, mingap, minperiod, extrapolate)
            %FINDPERIODS finds period intervals of the input crossing the threshold
            %
            %   x: input vector, or a cell {time, input vector}
            %   thr: threshold
            %   mingap: minimum distance to be considered a different period. 
            %       Otherwise it gets concatenated
            %   minperiod: minimum duration of a period to be considered
            %   extrapolate: if true, periods end at the first value below the
            %       threshold, not the last value above
            %
            %   periods: Period object
            arguments
                obj spiky.core.TimeTable
                thr (1, 1) double = 0
                mingap (1, 1) double = NaN
                minperiod (1, 1) double = 0
                extrapolate (1, 1) logical = false
            end
            if ~isvector(obj.Data) || ~isnumeric(obj.Data)
                error("Data must be a numeric vector")
            end
            if isnan(mingap)
                mingap = max(diff(obj.Time));
            end
            if isinf(mingap)
                mingap = realmax;
            end
            t = obj.Time;
            x = obj.Data;
            isCross = x>thr;
            if isscalar(t) && isscalar(isCross)
                if isCross
                    periods = [t Inf];
                else
                    periods = double.empty(0, 2);
                end
                return
            end
            if extrapolate
                isCross = [false; isCross(1:end-1)]|isCross;
            end
            tCross = t(isCross);
            tDiff = abs(diff([-Inf ; tCross ; Inf]));
            jumps = find(tDiff>mingap);
            periods = [tCross(jumps(1:end-1)) tCross(jumps(2:end)-1)];
            periods(diff(periods, [], 2)<minperiod, :)=[];
            periods = spiky.core.Periods(periods);
        end

        function varargout = size(obj, varargin)
            % SIZE Size of the TimeTable
            [varargout{1:nargout}] = size(obj.Data, varargin{:});
        end

        function out = cat(dim, varargin)
            % CAT Concatenate TimeTables
            if any(cellfun(@(x) ~isa(x, "spiky.core.TimeTable"), varargin))
                error("All inputs must be TimeTable objects")
            end
            time = cellfun(@(x) x.Time, varargin, UniformOutput=false);
            data = cellfun(@(x) x.Data, varargin, UniformOutput=false);
            if dim==1
                len = cellfun(@(x) size(x, 2), data);
                if any(len~=len(1))
                    error("The number of columns must be the same")
                end
                time = vertcat(time{:});
                [time, idc] = sort(time);
                data = vertcat(data{:});
                out = spiky.core.TimeTable(time, data(idc, :));
            elseif dim==2
                areSame = cellfun(@(x) isequal(x.Time, time{1}), time);
                if ~all(areSame)
                    error("The time points must be the same")
                end
                time = time{1};
                data = horzcat(data{:});
                out = spiky.core.TimeTable(time, data);
            else
                error("Invalid dimension")
            end
        end
    end

    methods (Access = protected)
        function checkIndexOp(obj, indexOp)
            if isscalar(indexOp.Indices) && size(obj.Data, 2)>1
                error("Indexing into non-vector data requires two indices");
            end
        end

        function varargout = parenReference(obj, indexOp)
            obj.checkIndexOp(indexOp(1));
            obj.Time = subsref(obj.Time, substruct('()', indexOp(1).Indices(1)));
            obj.Data = obj.Data.(indexOp(1));
            if isscalar(indexOp)
                varargout{1} = obj;
                return
            end
            [varargout{1:nargout}] = obj.(indexOp(2:end));
        end

        function obj = parenAssign(obj, indexOp, varargin)
            obj.checkIndexOp(indexOp(1));
            if isempty(obj)
                error("Cannot assign to an empty TimeTable")
            end
            if isscalar(indexOp)
                assert(nargin==3);
                rhs = varargin{1};
                if ~isa(rhs, "spiky.core.TimeTable")
                    error("Invalid assignment with class %s", class(rhs))
                end
                obj.Data.(indexOp) = rhs.Data;
                return
            end
            [obj.(indexOp(2:end))] = varargin{:};
        end

        function n = parenListLength(obj, indexOp, indexContext)
            obj.checkIndexOp(indexOp(1));
            if numel(indexOp) <= 2
                n = 1;
                return
            end
            containedObj = obj.(indexOp(1:2));
            n = listLength(containedObj, indexOp(3:end), indexContext);
        end

        function obj = parenDelete(obj, indexOp)
            obj.checkIndexOp(indexOp(1));
            if ~isscalar(indexOp.Indices) && indexOp.Indices{2}~=':'
                error("Deletion of non-vector data must delete the entire row");
            end
            obj.Time = subsasgn(obj.Time, substruct('()', indexOp(1).Indices(1)), []);
            obj.Data.(indexOp) = [];
        end

        function varargout = braceReference(obj, indexOp)
            obj.checkIndexOp(indexOp(1));
            out = subsref(obj.Data, substruct('()', indexOp(1).Indices));
            if isscalar(indexOp)
                varargout{1} = out;
                return
            end
            [varargout{1:nargout}] = subsref(out, spiky.utils.indexOp2substruct(indexOp(2:end)));
        end

        function obj = braceAssign(obj, indexOp, varargin)
            obj.checkIndexOp(indexOp(1));
            if isscalar(indexOp)
                obj.Data = subsasgn(obj.Data, substruct('()', indexOp.Indices), varargin{:});
                return
            end
            data = subsref(obj.Data, substruct('()', indexOp(1).Indices));
            data = braceAssign(data, indexOp(2:end), varargin{:});
            obj.Data = subsasgn(obj.Data, substruct('()', indexOp(1).Indices), data);
        end

        function n = braceListLength(obj, indexOp, indexContext)
            obj.checkIndexOp(indexOp(1));
            if numel(indexOp) <= 1
                n = 1;
                return
            end
            containedObj = obj.(indexOp(1));
            n = listLength(containedObj, indexOp(2:end), indexContext);
        end
    end
end