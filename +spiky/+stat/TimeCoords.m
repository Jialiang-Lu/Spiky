classdef TimeCoords < spiky.stat.Coords & spiky.core.EventsTable
    %TIMECOORDS Class representing coordinate system whos dimensions are time

    methods (Static)
        function obj = makeDirac(t)
            %MAKEDIRAC Create a Coords with Dirac basis over time
            %   obj = makeDirac(t)
            %
            %   t: time vector

            arguments
                t (:, 1) double
            end
            nT = numel(t);
            B = eye(nT);
            obj = spiky.stat.TimeCoords(t, zeros(nT, 1), B);
        end

        function obj = makeDpss(t, nBases, fMax)
            %MAKEDPSS Create a Coords with DPSS basis over time
            %   obj = makeDpss(t, nBases, fMax)
            %
            %   t: time vector
            %   nBases: number of basis functions
            %   fMax: maximum frequency (Hz) for the basis functions

            arguments
                t (:, 1) double
                nBases (1, 1) double {mustBeInteger, mustBePositive} = numel(t)
                fMax (1, 1) double {mustBePositive} = 1/(t(2)-t(1))/2
            end
            res = t(2)-t(1);
            fs = 1/res; % sampling frequency
            if abs(fMax-fs/2)<1e-6
                fMax = fs/2-1e-6; % avoid numerical issues
            end
            assert(fMax<=fs/2, "fMax must be less or equal to Nyquist frequency");
            N = numel(t);
            NW = fMax*N*res; % time-bandwidth product
            assert(nBases<=round(2*NW), sprintf("nBases must be less than or equal to 2*NW, which is %.1f", 2*NW));
            [B, ~] = dpss(numel(t), NW, nBases);
            obj = spiky.stat.TimeCoords(t, zeros(numel(t), 1), B);
        end

        function obj = makeRaisedCosine(res, nBases, peakRange, options)
            %MAKERAISEDCOSINE Create a Coords with raised-cosine basis over time
            %   obj = makeRaisedCosine(res, nBases, peakRange, options)
            %
            %   res: time step
            %   nBases: number of basis functions
            %   peakRange: [tFirst, tLast] range for the peaks
            %   Name-Value pairs
            %     - TimeRange: [tStart, tEnd] for the time vector (default: covers peakRange)
            %     - Spacing: 'log' or 'linear' for peak spacing (default: 'log')
            %     - LogOffset: offset for log spacing (default: 1)
            %     - TwoSided: if true, create two-sided basis (default: false)
            %     - TimeOffset: offset for time vector, bases starts/centers are shifted by this 
            %           amount (default: 0)

            arguments
                res (1, 1) double {mustBePositive}
                nBases (1, 1) double {mustBeInteger, mustBePositive}
                peakRange double % [minPeak, maxPeak] or maxPeak
                options.TimeRange double = NaN % [tStart, tEnd] or tEnd
                options.Spacing (1, 1) string {mustBeMember(options.Spacing, ["log","linear"])} = "log"
                options.LogOffset (1, 1) double {mustBePositive} = 1 % offset for log spacing
                options.TwoSided logical = false % if true, the basis is two-sided
                options.TimeOffset double = 0 % offset for time vector
            end

            if isscalar(peakRange)
                peakRange = [0, peakRange];
            end
            timeRange = options.TimeRange;
            if isscalar(timeRange)
                timeRange = [0, timeRange];
            end
            if options.TwoSided
                peakRange(1) = 0;
                timeRange(1) = 0;
            end
            pr = sort(peakRange(:).'); % ensure ascending
            if any(~isfinite(pr)) || pr(1) < 0
                error("peakRange must be finite, nonnegative");
            end
            switch options.Spacing
                case "linear"
                    centers = linspace(pr(1), pr(2), nBases);
                    centersOp = centers;
                    width = centers(2)-centers(1);
                    if any(isnan(timeRange))
                        timeRange = [0, centers(end)+width];
                    end
                    t = (timeRange(1):res:timeRange(2)).';
                    if options.TwoSided
                        t = [-flipud(t(2:end)); t];
                        centersOp = [-fliplr(centers(2:end)) centers];
                    end
                    tOp = t;
                case "log"
                    c = options.LogOffset;
                    centersOp = linspace(log1p(pr(1)-1+c), log1p(pr(2)-1+c), nBases);
                    centers = exp(centersOp)-c;
                    width = centersOp(2)-centersOp(1);
                    if any(isnan(timeRange))
                        timeRange = [0, expm1(centersOp(end)+width*2+1-c)];
                    end
                    t = (timeRange(1):res:timeRange(2)).';
                    if options.TwoSided
                        t = [-flipud(t(2:end)); t];
                        tOp = NaN(numel(t), 1);
                        tOp(t+c>0) = log1p(t(t+c>0)-1+c);
                        d = (tOp-centersOp)*pi/width/2;
                        B = (cos(d)+1)/2;
                        B(d<=-pi | d>=pi) = 0;
                        B1 = B;
                        B = zeros(height(t), nBases*2-1);
                        B(:, 1:nBases-1) = flipud(B1(:, end:-1:2));
                        B(:, nBases:end) = B1;
                        B(t<0, nBases) = flipud(B(t>0, nBases));
                        B(isnan(B)) = 0;
                        D = 2-sum(B, 2);
                        D(t<-centers(2) | t>centers(2)) = 0;
                        B(:, nBases) = B(:, nBases)+D;
                        obj = spiky.stat.TimeCoords(t, zeros(numel(t), 1), B);
                        return
                    else
                        tOp = log1p(t-1+c);
                    end
            end
            d = (tOp-centersOp)*pi/width/2;
            B = (cos(d)+1)/2;
            B(d<=-pi | d>=pi) = 0;
            if timeRange(1)==0
                D = 2-sum(B, 2);
                D(t<-centers(2) | t>centers(2)) = 0;
                idx = abs(centers)<1e-10;
                B(:, idx) = B(:, idx)+D;
            end
            obj = spiky.stat.TimeCoords(t+options.TimeOffset, zeros(numel(t), 1), B);
        end

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
            dimLabelNames = {["Time"; "Dims"]};
        end
    end

    methods
        function obj = TimeCoords(time, origin, bases)
            %TIMECOORDS Create a new instance of TimeCoords
            %
            %   TimeCoords(time, origin, bases) creates a new instance of TimeCoords
            %
            %   time: time vector
            %   origin: origin of the coordinate system
            %   bases: basis vectors
            %
            %   obj: TimeCoords object
            arguments
                time (:, 1) double = double.empty(0, 1)
                origin (:, 1) double = double.empty(0, 1)
                bases (:, :) double = double.empty(0, 0)
            end
            obj@spiky.stat.Coords(origin, bases, time);
        end

        function obj = flip(obj)
            %FLIP Flip the time axis and basis functions
            %
            %   obj = FLIP(obj)
            %
            %   obj: TimeCoords object

            obj.Time = -flipud(obj.Time);
            obj.Bases = flipud(obj.Bases);
        end

        function tt = expand(obj, tt, idcBases)
            %EXPAND Expand the EventsTable using the coordinate system
            %
            %   tt = EXPAND(obj, tt)
            %
            %   obj: TimeCoords object
            %   tt: EventsTable to expand, with numeric data nT x nObs and same temporal resolution
            %   idcBases: indices of the bases to use for expansion (default: all bases)
            %
            %   tt: expanded EventsTable, with numeric data nT x (nBases*nObs)
            arguments
                obj spiky.stat.TimeCoords
                tt spiky.core.EventsTable
                idcBases double = 1:obj.NBases
            end
            if islogical(tt.Data)
                tt.Data = double(tt.Data);
            end
            if isa(tt, "spiky.trig.TrigFr")
                tt.Data = permute(tt.Data, [1 3 2]); % nT x nNeurons x nEvents
            end
            assert(isnumeric(tt.Data), "Data in tt must be numeric");
            assert(abs(obj.Time(2)-obj.Time(1)-tt.Time(2)+tt.Time(1))<1e-10, ...
                "The temporal resolution of the EventsTable must be the same as that of the TimeCoords");
            idx0 = find(abs(obj.Time)<1e-10, 1);
            if isempty(idx0)
                error("The TimeCoords must include time 0");
            end
            nObs = width(tt);
            nT = height(tt);
            data = zeros(nT, nObs*obj.NBases, size(tt.Data, 3));
            for ii = 1:numel(idcBases)
                data1 = convn(tt.Data, obj.Bases(:, idcBases(ii)), "full");
                % data(:, (ii-1)*nObs+(1:nObs)) = data1(idx0:idx0+nT-1, :);
                data(:, ii:obj.NBases:end, :) = data1(idx0:idx0+nT-1, :, :); % bases varies fastest
            end
            tt.Data = data;
            if isa(tt, "spiky.trig.TrigFr")
                tt.Data = permute(tt.Data, [1 3 2]); % nT x nEvents x (nBases*nNeurons)
                tt.Neuron = repelem(tt.Neuron, obj.NBases, 1);
            end
        end

        function h = plot(obj)
            %PLOT Plot the basis functions
            %
            %   obj: TimeCoords object

            figure;
            h1 = plot(obj.Time, obj.Bases);
            xlim([min(obj.Time) max(obj.Time)]);
            xlabel("Time (s)");
            ylabel("Basis functions");
            if nargout>0
                h = h1;
            end
        end

        function h = image(obj)
            %IMAGE Plot the basis functions as an image
            %
            %   obj: TimeCoords object

            figure;
            h1 = imagesc(obj.Time, 1:obj.NBases, obj.Bases.');
            xlabel("Time (s)");
            ylabel("Basis functions");
            colorbar
            if nargout>0
                h = h1;
            end
        end
    end
end