classdef StimHMM
% Class: GLM-HMM for spikes with dense stimulus on a single time axis.

    properties
        % ---- Model meta ----
        NumStates (1, 1) double {mustBeInteger,mustBePositive} = 2
        EmissionModel (1, 1) string {mustBeMember(EmissionModel, ["Bernoulli","Poisson"])} = "Bernoulli"
        Time (:, 1) double {mustBeNonnegative} = []
        Dt (1, 1) double {mustBePositive} = 0.05
        StimLags (1, :) double {mustBeNonnegative} = 0
        AddBias (1, 1) logical = true

        % ---- Spike history ----
        HistoryDuration (1, 1) double {mustBeNonnegative} = 0.200
        NumHistoryBases (1, 1) double {mustBeInteger,mustBeNonnegative} = 3
        HistoryTauMinMax (1, 2) double {mustBePositive} = [0.002 0.050]

        % ---- Optimization ----
        Regularization (1, 1) string {mustBeMember(Regularization,["none","l2"])} = "none"
        Lambda (1, 1) double {mustBeNonnegative} = 0
        MaxIter (1, 1) double {mustBeInteger,mustBePositive} = 100
        TolFun (1, 1) double {mustBePositive} = 1e-5
        Verbose (1, 1) logical = true
        UseParallel (1, 1) logical = false

        % ---- Learned, per cell ----
        C (1, 1) double {mustBeInteger,mustBeNonnegative} = 0 % Number of cells
        D (1, 1) double {mustBeInteger,mustBeNonnegative} = 0 % Number of stimulus features
        T (1, 1) double {mustBeInteger,mustBeNonnegative} = 0 % Number of time points

        % Per-cell parameter sets (arrays, not cells):
        %   Kspk : Pspk x N x C   spiking filter for cell c, state n
        %   Ktr  : P0   x N x N x C transition filter for origin n -> dest m (m!=n)
        %   Pi   : N    x C       initial state distribution (filtering prior)
        Kspk double = []    % Pspk x N x C
        Ktr  double = []    % P0   x N x N x C
        Pi   double = []    % N    x C
        LL double = [] % Log-likelihood per cell

        % Shared design caches (built during fit)
        P0 (1, 1) double {mustBeInteger,mustBeNonnegative} = 0 % Number of stimulus features after lags
        Pspk (1, 1) double {mustBeInteger,mustBeNonnegative} = 0 % Number of spiking features (P0 + H)
        StimDesign double = []   % P0 x T
        HBasis double = []       % H x L
        Ybinned double = []      % C x T
    end

    methods
        function obj = spiky.stat.StimHMM(options)
        % Constructor: set model/options properties.
        arguments
            options.NumStates (1, 1) double {mustBeInteger,mustBePositive} = 2
            options.EmissionModel (1, 1) string {mustBeMember(options.EmissionModel, ["Bernoulli","Poisson"])} = "Bernoulli"
            options.StimLags (1, :) double {mustBeNonnegative} = 0
            options.AddBias (1, 1) logical = true
            options.HistoryDuration (1, 1) double {mustBeNonnegative} = 0.200
            options.NumHistoryBases (1, 1) double {mustBeInteger,mustBeNonnegative} = 3
            options.HistoryTauMinMax (1, 2) double {mustBePositive} = [0.002 0.050]
            options.Regularization (1, 1) string {mustBeMember(options.Regularization,["none","l2"])} = "none"
            options.Lambda (1, 1) double {mustBeNonnegative} = 0
            options.MaxIter (1, 1) double {mustBeInteger,mustBePositive} = 100
            options.TolFun (1, 1) double {mustBePositive} = 1e-5
            options.Verbose (1, 1) logical = true
            options.UseParallel (1, 1) logical = false
        end
            obj.NumStates       = options.NumStates;
            obj.EmissionModel   = options.EmissionModel;
            obj.StimLags        = options.StimLags;
            obj.AddBias         = options.AddBias;
            obj.HistoryDuration = options.HistoryDuration;
            obj.NumHistoryBases = options.NumHistoryBases;
            obj.HistoryTauMinMax= options.HistoryTauMinMax;
            obj.Regularization  = options.Regularization;
            obj.Lambda          = options.Lambda;
            obj.MaxIter         = options.MaxIter;
            obj.TolFun          = options.TolFun;
            obj.Verbose         = options.Verbose;
            obj.UseParallel     = options.UseParallel;
        end

        function obj = fit(obj, spikes, t, stim, options)
        % Train per-cell GLM-HMMs on a continuous time axis with dense stimulus.
        arguments
            obj
            spikes (:, 1) spiky.core.Spikes
            t (:, 1) double
            stim {mustBeNumeric}
            options.Pi double = []  % N x C
            options.Kspk double = []  % Pspk x N x C
            options.Ktr double = []  % P0 x N x N x C
            options.EmissionModel (1, 1) string {mustBeMember(options.EmissionModel, ["Bernoulli","Poisson"])} = obj.EmissionModel
            options.MaxIter (1, 1) double {mustBeInteger,mustBePositive} = obj.MaxIter
            options.TolFun (1, 1) double {mustBePositive} = obj.TolFun
            options.Regularization (1, 1) string {mustBeMember(options.Regularization,["none","l2"])} = obj.Regularization
            options.Lambda (1, 1) double {mustBeNonnegative} = obj.Lambda
            options.Verbose (1, 1) logical = obj.Verbose
        end
            %% Shapes and dt
            T = numel(t);
            if ~isuniform(t) || t(2)<t(1)
                error("Time vector t must be strictly increasing and uniformly spaced.")
            end
            dt = t(2) - t(1);
            obj.Dt = dt;
            D = size(stim, 2);
            obj.T = T;
            obj.D = D;

            %% Bin spikes into Y (C x T)
            C = height(spikes);
            obj.C = C;
            Y = zeros(C, T);
            edges = [t - dt/2; t(end) + dt/2];
            parfor ii = 1:C
                Y(ii, :) = histcounts(spikes(ii).Time, edges);
            end
            if options.EmissionModel=="Bernoulli"
                Y(Y>1) = 1;
            end
            obj.Ybinned = Y;

            %% Build stimulus design X0 (P0 x T)
            X0 = obj.buildStimDesign(stim);

            %% Build spike-history basis (H x L) and Gamma per cell (H x T)
            [HBasis, ~] = obj.makeHistoryBasis(obj.Dt, obj.NumHistoryBases, obj.HistoryTauMinMax, obj.HistoryDuration);
            obj.HBasis = HBasis;
            H = size(HBasis, 1);
            obj.P0 = size(X0, 1);
            obj.Pspk = obj.P0 + H;

            Gamma = zeros(C, H, T);
            if H > 0
                parfor ii = 1:C
                    yc = Y(ii, :);
                    Gc = zeros(H, T);
                    for jj = 1:H
                        Gc(jj, :) = conv(yc, fliplr(HBasis(jj, :)), "same");
                    end
                    Gamma(ii, :, :) = Gc;
                end
            end

            %% Initialize parameter containers
            N  = obj.NumStates;
            P0 = obj.P0;
            Pspk = obj.Pspk;

            Kspk = zeros(Pspk, N, C);
            Ktr  = zeros(P0, N, N, C);
            Pi   = zeros(N, C);
            LL = zeros(C, 1);
            %% Prepare optional initialization (accept arrays; fall back to random)
            if ~isempty(options.Pi) && isequal(size(options.Pi), [N C])
                Pi1 = options.Pi;
            else
                Pi1 = ones(N, C) / N;  % Uniform initial distribution
            end
            if ~isempty(options.Kspk) && isequal(size(options.Kspk), [Pspk N C])
                Kspk1 = options.Kspk;
            else
                Kspk1 = 0.01 * randn(Pspk, N, C);  % Small random initialization
            end
            if ~isempty(options.Ktr) && isequal(size(options.Ktr), [P0 N N C])
                Ktr1 = options.Ktr;
            else
                Ktr1 = 0.01 * randn(P0, N, N, C);  % Small random initialization
                [~, idc2, idc3, ~] = ind2sub(size(Ktr1), 1:numel(Ktr1));
                Ktr1(idc2==idc3) = 0;  % Zero diagonal
            end

            %% Per-cell fitting (no nested functions; use static helpers)
            emissionModel = options.EmissionModel;
            regularization = options.Regularization;
            lambda = options.Lambda;
            for ii = 1:C
                % Per-cell designs
                if H>0
                    Xspk = [ X0; squeeze(Gamma(ii,:,:)) ];
                else
                    Xspk = X0;
                end

                % Inits for this cell
                pi_c = Pi1(:, ii);
                Kspk_c = Kspk1(:, :, ii);
                Ktr_c = Ktr1(:, :, :, ii);

                % Fit one cell via EM
                [pi_c, Kspk_c, Ktr_c, LL_c] = spiky.stat.StimHMM.fitOneCell( ...
                    Y(ii,:), X0, Xspk, Kspk_c, Ktr_c, pi_c, ...
                    emissionModel, regularization, lambda, ...
                    dt, T, N, P0, options.MaxIter, options.TolFun, options.Verbose);

                % Write back
                Pi(:,ii)       = pi_c;
                Kspk(:,:,ii)   = Kspk_c;
                Ktr(:,:,:,ii)  = Ktr_c;
                LL(ii) = LL_c;
            end
            obj.Pi = Pi;
            obj.Kspk = Kspk;
            obj.Ktr = Ktr;
            obj.LL = LL;

            if options.Verbose
                fprintf("Fit complete. Median per-cell LL/T: %.4f\n", median(obj.LL)/T);
            end
        end

        function out = decodeSingle(obj, c, t, stim, options)
        % Filtering posteriors for one cell on continuous time.
            arguments
                obj
                c (1, 1) double {mustBeInteger}
                t (:, 1) double
                stim {mustBeNumeric}
                options = struct()
            end
            %% Rebuild designs
            assert(c>=1 && c<=obj.C, "Cell index out of range.");
            T = numel(t);
            if T ~= obj.T
                error('Time vector length T must match the trained model T (%d).', obj.T);
            end
            if size(stim, 1) ~= T, stim = stim.'; end
            X0 = obj.buildStimDesign(stim);
            H  = size(obj.HBasis,1);
            if H>0
                G = zeros(H, T);
                y = obj.Ybinned(c, :);
                for jj = 1:H, G(jj, :) = conv(y, fliplr(obj.HBasis(jj, :)), "same"); end
                Xspk = [X0; G];
            else
                y = obj.Ybinned(c, :); %#ok<NASGU>
                Xspk = X0;
            end

            %% Emission log-likelihoods
            N = obj.NumStates; dt = obj.Dt; y = obj.Ybinned(c, :);
            logL = zeros(N, T);
            for n = 1:N
                u   = (obj.Kspk(:,n,c))' * Xspk;
                lam = spiky.stat.StimHMM.piecewiseF(u);
                switch obj.EmissionModel
                    case "Poisson"
                        logL(n, :) = y .* log(lam*dt + eps) - lam*dt - gammaln(y+1);
                    case "Bernoulli"
                        y01 = y>0;
                        p1 = 1 - exp(-lam*dt);
                        logL(n, :) = y01.*log(max(p1, eps)) + (~y01).*log(max(1-p1,eps));
                end
            end

            %% Transitions from this cell
            P0 = obj.P0;
            A = zeros(N,N,T-1);
            for n = 1:N
                idx = setdiff(1:N, n);
                Kmat = zeros(P0, numel(idx));
                for jj = 1:numel(idx), Kmat(:, jj) = obj.Ktr(:, n, idx(jj), c); end
                U = (Kmat.' * X0); R = exp(U); denom = 1 + dt*sum(R, 1);
                for jj = 1:numel(idx)
                    m = idx(jj); A(n,m,2:T) = (R(jj, 2:T).*dt)./denom(1, 2:T);
                end
                A(n,n,2:T) = 1 ./ denom(1, 2:T);
            end

            %% Forward recursion
            pi_c = obj.Pi(:,c);
            alpha = zeros(N, T); csc = zeros(1, T);
            alpha(:, 1) = pi_c .* exp(logL(:, 1) - max(logL(:, 1)));
            csc(1) = sum(alpha(:, 1)) + eps; alpha(:, 1) = alpha(:, 1)/csc(1);
            for tt = 2:T
                alpha(:, tt) = (A(:,:,tt-1).'*alpha(:,tt-1)) .* exp(logL(:, tt)-max(logL(:, tt)));
                csc(tt) = sum(alpha(:, tt)) + eps; alpha(:, tt) = alpha(:, tt)/csc(tt);
            end
            out.Post = alpha; out.LogL = logL;
        end

        function out = decodePopulation(obj, t, stim, options)
        % Fuse cells by multiplying emission likelihoods; pooled transitions.
        arguments
            obj
            t (:, 1) double
            stim {mustBeNumeric}
            options.EventStates (1, :) double {mustBeInteger} = []
            options.TransitionPool (1, 1) string {mustBeMember(options.TransitionPool,["mean","median","first","custom"])} = "mean"
            options.CustomKtr double = []  % P0 x N x N
        end
            %% Design
            if size(stim, 1) ~= obj.T, stim = stim.'; end
            X0 = obj.buildStimDesign(stim);
            dt = obj.Dt; N = obj.NumStates; T = obj.T; P0 = obj.P0;

            %% Per-cell emission log-likelihoods
            logLsum = zeros(N, T);
            if obj.UseParallel && obj.C>1
                logLparts = cell(obj.C,1);
                parfor ii = 1:obj.C
                    H = size(obj.HBasis,1);
                    if H>0
                        G = zeros(H, T); y = obj.Ybinned(ii, :);
                        for jj = 1:H, G(jj, :) = conv(y, fliplr(obj.HBasis(jj, :)), "same"); end
                        Xspk = [X0; G];
                    else
                        y = obj.Ybinned(ii, :); Xspk = X0;
                    end
                    logLc = zeros(N, T);
                    for n = 1:N
                        u = (obj.Kspk(:,n,ii))' * Xspk; lam = spiky.stat.StimHMM.piecewiseF(u);
                        switch obj.EmissionModel
                            case "Poisson"
                                logLc(n, :) = y .* log(lam*dt + eps) - lam*dt - gammaln(y+1);
                            case "Bernoulli"
                                y01 = y>0; p1 = 1 - exp(-lam*dt);
                                logLc(n, :) = y01.*log(max(p1, eps)) + (~y01).*log(max(1-p1,eps));
                        end
                    end
                    logLparts{ii} = logLc;
                end
                for ii = 1:obj.C, logLsum = logLsum + logLparts{ii}; end
            else
                for ii = 1:obj.C
                    H = size(obj.HBasis,1);
                    if H>0
                        G = zeros(H, T); y = obj.Ybinned(ii, :);
                        for jj = 1:H, G(jj, :) = conv(y, fliplr(obj.HBasis(jj, :)), "same"); end
                        Xspk = [X0; G];
                    else
                        y = obj.Ybinned(ii, :); Xspk = X0;
                    end
                    for n = 1:N
                        u = (obj.Kspk(:,n,ii))' * Xspk; lam = spiky.stat.StimHMM.piecewiseF(u);
                        switch obj.EmissionModel
                            case "Poisson"
                                logLsum(n, :) = logLsum(n, :) + (y .* log(lam*dt + eps) - lam*dt - gammaln(y+1));
                            case "Bernoulli"
                                y01 = y>0; p1 = 1 - exp(-lam*dt);
                                logLsum(n, :) = logLsum(n, :) + (y01.*log(max(p1, eps)) + (~y01).*log(max(1-p1,eps)));
                        end
                    end
                end
            end

            %% Pooled transitions (shared across cells for decoding)
            KtrShared = zeros(P0, N, N);
            switch options.TransitionPool
                case "custom"
                    assert(~isempty(options.CustomKtr),'CustomKtr must be provided (P0 x N x N).');
                    KtrShared = options.CustomKtr;
                case "first"
                    KtrShared = obj.Ktr(:,:,:,1);
                otherwise % mean or median over 4th dim
                    if options.TransitionPool=="mean"
                        KtrShared = mean(obj.Ktr, 4);
                    else
                        KtrShared = median(obj.Ktr, 4);
                    end
            end

            %% Time-varying transitions A with KtrShared
            A = zeros(N,N,T-1);
            for n = 1:N
                idx = setdiff(1:N, n);
                Kmat = zeros(P0, numel(idx));
                for jj = 1:numel(idx), Kmat(:, jj) = KtrShared(:, n, idx(jj)); end
                U = (Kmat.' * X0); R = exp(U); denom = 1 + dt*sum(R, 1);
                for jj = 1:numel(idx)
                    m = idx(jj); A(n,m,2:T) = (R(jj, 2:T).*dt)./denom(1, 2:T);
                end
                A(n,n,2:T) = 1 ./ denom(1, 2:T);
            end

            %% Prior: average of per-cell initial distributions
            PiBar = mean(obj.Pi, 2);

            %% Forward filter with combined emissions
            alpha = zeros(N, T); csc = zeros(1, T);
            alpha(:, 1) = PiBar .* exp(logLsum(:, 1) - max(logLsum(:, 1)));
            csc(1)=sum(alpha(:, 1))+eps; alpha(:, 1)=alpha(:, 1)/csc(1);
            for tt = 2:T
                alpha(:, tt) = (A(:,:,tt-1).'*alpha(:,tt-1)) .* exp(logLsum(:, tt)-max(logLsum(:, tt)));
                csc(tt) = sum(alpha(:, tt))+eps; alpha(:, tt) = alpha(:, tt)/csc(tt);
            end

            out.Post = alpha;
            out.LogL = logLsum;
            if ~isempty(options.EventStates)
                ev = false(N, 1); ev(options.EventStates) = true;
                out.PEvent = sum(alpha(ev,:,:),1);
            end
        end

        function X0 = buildStimDesign(obj, stim)
        % Build design [bias; lagged stim] as P0 x T matrix.
            T = size(stim, 1);
            D = size(stim, 2);
            dt = obj.Dt;
            lags_s = obj.StimLags;
            lag_bins = round(lags_s/dt);
            Lg = numel(lag_bins);

            P0 = (obj.AddBias) + D*Lg;
            X0 = zeros(P0, T, "like", full(stim));
            rr = 1;
            if obj.AddBias
                X0(1, :) = 1;
                rr = rr+1;
            end
            for kk = 1:Lg
                lb = lag_bins(kk);
                Xk = [zeros(lb, D); stim(1:end-lb, :)];
                X0(rr:rr+D-1, :) = Xk.';   % (D x T)
                rr = rr + D;
            end
            obj.P0 = size(X0, 1);
            obj.StimDesign = X0;
        end

        function [HB, L] = makeHistoryBasis(~, dt, H, tauMinMax, dur)
        % Construct exponential history basis (rows normalized).
            if H==0 || dur<=0
                HB = zeros(0, 1); L=0; return;
            end
            taus = logspace(log10(tauMinMax(1)), log10(tauMinMax(2)), H);
            L = ceil(dur/dt);
            HB = zeros(H, L);
            tvec = (1:L)*dt;
            for jj = 1:H
                hb = exp(-tvec/taus(jj));
                HB(jj, :) = hb / norm(hb);
            end
        end
    end

    methods (Static)
        function [pi_c, Kspk_c, Ktr_c, LL_final] = fitOneCell(y, X0, Xspk, Kspk_c, Ktr_c, pi_c, Emiss, Reg, Lambda, dt, T, N, P0, MaxIter, TolFun, Verbose)
        %EM for a single cell
            %% EM loop
            LL_prev = -inf;
            for it = 1:MaxIter
                % E-step
                [LL, gamma, xi] = spiky.stat.StimHMM.forwardBackward(y, X0, Xspk, Kspk_c, Ktr_c, pi_c, Emiss, dt, T, N, P0);

                % M-step: initial prob
                pi_c = gamma(:, 1);

                %   spiking filters (per state)
                for n = 1:N
                    theta0 = Kspk_c(:,n);
                    objfun = @(th) spiky.stat.StimHMM.spkObjectiveVecStatic(th, Xspk, y, gamma(n, :), Emiss, dt, Reg, Lambda);
                    theta = fminunc(objfun, theta0, optimoptions("fminunc","Display","off","Algorithm","quasi-newton","SpecifyObjectiveGradient",true,"MaxFunctionEvaluations",5e3));
                    Kspk_c(:,n) = theta;
                end

                %   transitions (per origin n), pack (N-1)*P0 vector
                for n = 1:N
                    idx = setdiff(1:N, n);
                    theta0 = [];
                    for m = idx, theta0 = [theta0; Ktr_c(:,n,m)]; end %#ok<AGROW>
                    objfun = @(th) spiky.stat.StimHMM.trObjectiveVecStatic(th, X0, squeeze(xi(n,idx,:)), gamma(n,1:end-1), dt, T, P0, Reg, Lambda);
                    theta = fminunc(objfun, theta0, optimoptions("fminunc","Display","off","Algorithm","quasi-newton","SpecifyObjectiveGradient",true,"MaxFunctionEvaluations",5e3));
                    kk=0;
                    for m = idx
                        Ktr_c(:,n,m) = theta(kk+(1:P0)); kk=kk+P0;
                    end
                end

                if Verbose && mod(it, 10)==0
                    fprintf("EM | iter %d | LL=%.6f\n", it, LL);
                end
                if abs(LL - LL_prev) < TolFun, break; end
                LL_prev = LL;
            end
            [LL_final, ~, ~] = spiky.stat.StimHMM.forwardBackward(y, X0, Xspk, Kspk_c, Ktr_c, pi_c, Emiss, dt, T, N, P0);
        end

        function [loglik, gamma, xi] = forwardBackward(y, X0, Xspk, Kspk_c, Ktr_c, pi_c, Emiss, dt, T, N, P0)
        % Static helper: vectorized forward-backward for one cell.
            %% Emission log-likelihood per state/time
            logL = zeros(N, T);
            for n = 1:N
                u = (Kspk_c(:,n))' * Xspk;
                lam = spiky.stat.StimHMM.piecewiseF(u);
                switch Emiss
                    case "Poisson"
                        logL(n, :) = y .* log(lam*dt + eps) - lam*dt - gammaln(y+1);
                    case "Bernoulli"
                        y01 = y>0;
                        p1 = 1 - exp(-lam*dt);
                        logL(n, :) = y01.*log(max(p1, eps)) + (~y01).*log(max(1-p1,eps));
                end
            end

            %% Time-varying transitions A(:,:,t)
            A = zeros(N,N,T-1);
            for n = 1:N
                idx = setdiff(1:N, n);
                Kmat = zeros(P0, numel(idx));
                for jj = 1:numel(idx)
                    Kmat(:, jj) = Ktr_c(:, n, idx(jj));
                end
                U = (Kmat.' * X0);
                R = exp(U);
                denom = 1 + dt*sum(R, 1);
                for jj = 1:numel(idx)
                    m = idx(jj);
                    A(n,m,2:T) = (R(jj, 2:T).*dt) ./ denom(1, 2:T);
                end
                A(n,n,2:T) = 1 ./ denom(1, 2:T);
            end

            %% Forward-backward with scaling
            alpha = zeros(N, T);
            csc   = zeros(1, T);
            alpha(:, 1) = pi_c .* exp(logL(:, 1) - max(logL(:, 1)));
            csc(1) = sum(alpha(:, 1)) + eps; alpha(:, 1) = alpha(:, 1)/csc(1);
            for tt = 2:T
                alpha(:, tt) = (A(:,:,tt-1).'*alpha(:,tt-1)) .* exp(logL(:, tt) - max(logL(:, tt)));
                csc(tt) = sum(alpha(:, tt)) + eps;
                alpha(:, tt) = alpha(:,  tt)/csc(tt);
            end

            beta = zeros(N, T); beta(:, T)=1;
            for tt = T-1:-1:1
                beta(:, tt) = A(:,:,tt) * (beta(:,tt+1) .* exp(logL(:,tt+1) - max(logL(:,tt+1))));
                beta(:, tt) = beta(:, tt) / (sum(beta(:, tt)) + eps);
            end

            gamma = alpha .* beta;
            gamma = gamma ./ (sum(gamma, 1) + eps);

            xi = zeros(N,N,T-1);
            for tt = 1:T-1
                Z = (alpha(:, tt) .* A(:,:,tt)) .* (beta(:,tt+1).'.*ones(1, N)) .* ...
                    (exp(logL(:,tt+1) - max(logL(:,tt+1)))');
                Zsum = sum(Z,"all") + eps;
                xi(:,:,tt) = Z / Zsum;
            end

            loglik = sum(log(csc + eps));
        end

        function [nll, grad] = spkObjectiveVecStatic(theta, Xspk, y, w, Emiss, dt, Reg, Lambda)
        % Static helper: spiking objective (negative ECLL) and gradient.
            u   = theta' * Xspk;
            lam = spiky.stat.StimHMM.piecewiseF(u);
            flp = spiky.stat.StimHMM.piecewiseFprime(u);
            switch Emiss
                case "Poisson"
                    nll = -sum( w .* ( y .* log(lam*dt + eps) - lam*dt ) );
                    term = w .* ( y .* (flp./(lam+eps)) - flp*dt );
                    grad = Xspk * term.';
                case "Bernoulli"
                    y01 = y>0;
                    p1  = 1 - exp(-lam*dt);
                    nll = -sum( w .* ( y01.*log(max(p1, eps)) + (~y01).*log(max(1-p1,eps)) ) );
                    g_t = w .* ( y01 .* ((exp(-lam*dt).*dt.*flp)./(max(1 - exp(-lam*dt),eps))) ...
                               - (~y01) .* (dt.*flp) );
                    grad = Xspk * g_t.';
            end
            if Reg == "l2" && Lambda > 0
                nll = nll + 0.5*Lambda*sum(theta.^2);
                grad = grad + Lambda*theta;
            end
            grad = real(grad);
        end

        function [nll, grad] = trObjectiveVecStatic(theta, X0, xi_nm, gam_prev, dt, T, P0, Reg, Lambda)
        % Static helper: transition objective for a given origin state (packed).
            M  = size(xi_nm, 1);     % N-1
            U = zeros(M, T);
            off = 0;
            for jj = 1:M
                kj = theta(off+(1:P0)); off=off+P0;
                U(jj, :) = kj' * X0;
            end
            R = exp(U);
            denom = 1 + dt*sum(R, 1);
            nll = 0;
            for t2 = 2:T
                jvec = xi_nm(:,t2-1);
                nll = nll + ( - jvec.' * U(:, t2) + gam_prev(t2-1) * log(denom(t2)) );
            end
            grad = zeros(size(theta));
            off=0;
            for jj = 1:M
                coeff = zeros(1,T);
                coeff(2:end) = -xi_nm(jj, :) + gam_prev .* ((dt*R(jj, 2:end))./denom(2:end));
                grad(off+(1:P0)) = X0 * coeff.';
                off = off+P0;
            end
            if Reg == "l2" && Lambda > 0
                nll  = nll  + 0.5*Lambda*sum(theta.^2);
                grad = grad + Lambda*theta;
            end
            nll  = real(nll); grad = real(grad);
        end

        function y = piecewiseF(u)
        % Static nonlinearity f(u): Escola et al. Eq. 3.1.
            y = zeros(size(u));
            idx = (u<=0);
            y(idx) = exp(u(idx));
            y(~idx) = 1 + u(~idx) + 0.5*u(~idx).^2;
        end

        function y = piecewiseFprime(u)
        % Static derivative f'(u) for piecewiseF.
            y = zeros(size(u));
            idx = (u<=0);
            y(idx) = exp(u(idx));
            y(~idx) = 1 + u(~idx);
        end
    end
end
