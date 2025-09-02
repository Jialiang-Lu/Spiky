classdef Coords
    % COORDS Class representing a coordinate system in a N-D space

    properties
        Origin (:, 1) double % NDim x 1 vector representing the origin of the coordinate system
        Bases (:, :) double % NDim x NBases matrix representing the basis vectors
        Props (1, 1) struct
    end

    properties (Dependent)
        NDim double
        NBases double
    end

methods (Static)
    function obj = makeRaisedCosine(dt, nBases, peakRange, options)
        % MAKERAISEDCOSINE Create a Coords with raised-cosine basis over time
        %   obj = Coords.makeRaisedCosine(dt, nBases, peakRange, options)
        %
        %   dt: time step
        %   nBases: number of basis functions
        %   peakRange: [tFirst, tLast] range for the peaks
        %   Name-Value pairs
        %     - TimeRange: [tStart, tEnd] for the time vector (default: covers peakRange)
        %     - Spacing: 'Log' or 'Linear' for peak spacing (default: 'Log')

        arguments
            dt (1,1) double {mustBePositive}
            nBases (1,1) double {mustBeInteger, mustBePositive}
            peakRange (1,2) double
            options.TimeRange (1,2) double = [NaN, NaN]
            options.Spacing (1,1) string {mustBeMember(options.Spacing, ["Log","Linear"])} = "Log"
        end

        pr = sort(peakRange(:).'); % ensure ascending
        if any(~isfinite(pr)) || pr(1) < 0
            error("peakRange must be finite, nonnegative");
        end
        timeRange = options.TimeRange;
        switch options.Spacing
            case "Linear"
                centers = linspace(pr(1), pr(2), nBases);
                centersOp = centers;
                width = centers(2)-centers(1);
                if any(isnan(timeRange))
                    timeRange = [0, centers(end) + width];
                end
                t = (timeRange(1):dt:timeRange(2)).';
                tOp = t;
            case "Log"
                centersOp = linspace(log1p(pr(1)), log1p(pr(2)), nBases);
                centers = expm1(centersOp);
                width = centersOp(2)-centersOp(1);
                if any(isnan(timeRange))
                    timeRange = [0, expm1(centersOp(end)+width*2)];
                end
                t = (timeRange(1):dt:timeRange(2)).';
                tOp = log1p(t);
        end
        nT = numel(t);
        if nT < 3
            error("TimeRange and dt produce too few time points.");
        end
        % B = ((cos(max(-pi, min(pi, tOp-centersOp))*pi/width/2)+1)/2);
        B = (cos(max(-pi, min(pi, (tOp-centersOp)*pi/width/2)))+1)/2;
        obj = spiky.stat.Coords();
        obj.Origin = zeros(nT, 1);
        obj.Bases  = B;
        obj.Props  = struct( ...
            "Type", "raisedCosine", ...
            "T", t, ...
            "Dt", dt, ...
            "PeakRange", pr, ...
            "TimeRange", timeRange, ...
            "Spacing", options.Spacing, ...
            "Centers", centers);
    end
end

    methods
        function obj = Coords(origin, bases, varargin)
            % COORDS Create a new instance of Coords
            %
            %   Coords(origin, bases, ...) creates a new instance of Coords
            %
            %   origin: origin of the coordinate system
            %   bases: basis vectors
            %   Name-Value pairs: additional properties
            %
            %   obj: Coords object
            arguments
                origin double = []
                bases double = []
            end
            arguments (Repeating)
                varargin
            end
            obj.Origin = origin;
            obj.Bases = bases;
            obj.Props = struct();
            for ii = 1:2:length(varargin)
                obj.Props.(varargin{ii}) = varargin{ii + 1};
            end
        end

        function n = get.NDim(obj)
            n = size(obj.Bases, 1);
        end

        function n = get.NBases(obj)
            n = size(obj.Bases, 2);
        end

        function data = project(obj, data, idcDim)
            %PROJECT Project the data onto the coordinate system
            %
            %   data = PROJECT(obj, data)
            %
            %   obj: coordinate system
            %   data: data to project, nDim x nObs
            %   idcDim: indices of the dimensions to project
            %
            %   data: projected data, length(idcDim) x nObs
            arguments
                obj spiky.stat.Coords
                data double
                idcDim double = []
            end
            if size(data, 1) ~= obj.NDim
                error("The number of dimensions must be the same as the number of dimensions in the coordinate system")
            end
            if isempty(idcDim)
                idcDim = 1:obj.NBases;
            end
            B = obj.Bases(:, idcDim);
            data = (B'*B)\(B'*(data - obj.Origin));
        end

        function varargout = subsref(obj, s)
            if isempty(obj)
                [varargout{1:nargout}] = builtin("subsref", obj, s);
                return
            end
            switch s(1).type
                case '.'
                    if isfield(obj.Props, s(1).subs)
                        s1 = substruct(".", "Props");
                        s = [s1, s];
                    end
            end
            [varargout{1:nargout}] = builtin("subsref", obj, s);
        end
    end
end