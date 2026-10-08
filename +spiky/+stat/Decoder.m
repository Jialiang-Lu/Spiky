classdef Decoder < spiky.stat.GroupedStat
    %DECODER class for decoder models and related statistics.
    %   Decoder object represents the results of decoder analysis
    %
    %   Properties:
    %       Data: cell array of decoder models for each time point, group, partition, and condition
    %       DataTest: cell array of test decoder models for each time point, group, partition, and condition
    %       X: cell array of data, nT x nGroups x 1 x nConditions cell of nNeurons x nTrials
    %       Y: cell array of labels, nConditions x 1 cell of nTrials x 1 categorical,
    %           or nConditions x nT cell if different labels for each time point
    %       Partitions: nConditions x 1 cell of nPartitions x nTrials logical arrays for cross-validation splits,
    %           or nConditions x nT cell if different splits for each time point
    %       Proj: nT x nGroups x 1 x nConditions cell of spiky.stat.Coords objects
    %       Type: type of decoder

    properties
        DataTest
        Proj
    end

    properties (Dependent)
        Type (1, 1) string
    end

    properties (Hidden)
        Type_ (1, 1) string
    end

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
            dimLabelNames = {"Time", ["Groups"; "GroupIndices"], string.empty, ...
                ["Conditions"; "Partitions"; "Y"]};
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
            dataNames = ["Data" "X" "Proj" "DataTest" "P" "Shuffle"]';
        end

        function [stat, transform, d] = varExplained(mdl, X, y, options)
            arguments
                mdl spiky.stat.Coords
                X double
                y categorical
                options.Type string {mustBeMember(options.Type, ["trace", "max", "pillai", "wilks"])} = "trace"
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 0
                options.Proj double = []
                options.Procrustes logical = false
            end
            [isValid, idcY] = ismember(y, mdl.BasisNames);
            idcY = idcY(isValid);
            X = X(:, isValid); % nNeurons x nTrials
            y = y(isValid); % nTrials x 1 categorical
            nNeurons = height(X);
            nTrials = width(X);
            nCats = mdl.NBases;
            XHat = mdl.Origin+mdl.Bases(:, idcY); % nNeurons x nTrials predicted response
            if ~isempty(options.Proj) && ~isequal(options.Proj, NaN)
                X = options.Proj\X; % proj the data by the Mahalanobis weights
                XHat = options.Proj\XHat; % proj the predicted response
                basesUsed = options.Proj\mdl.Bases; % proj the decoder bases
            else
                basesUsed = mdl.Bases;
            end
            muTest = mean(X, 2, "omitnan"); % nNeurons x 1
            Xc = X-muTest; % nNeurons x nTrials
            if options.Procrustes
                mTest = NaN(nNeurons, nCats);
                for k = 1:nCats
                    mTest(:, k) = mean(X(:, idcY==k), 2, "omitnan")-muTest;
                end
                [d, ~, transform] = procrustes(mTest', basesUsed', Scaling=false, Reflection="best");
                Yaligned = basesUsed'*transform.T+transform.c; % nCats x nNeurons aligned class means
                basesUsed = Yaligned'; % nNeurons x nCats aligned class means
                XHat = muTest+basesUsed(:, idcY); % nNeurons x nTrials predicted response after procrustes alignment
            end
            % res = X-XHat; % nNeurons x nTrials residuals
            % totalSSE = sum(Xc.^2, "all", "omitnan"); % total sum of squares
            % switch options.Type
            %     case "trace"
            %         resSSE = sum(res.^2, "all", "omitnan"); % residual sum of squares
            %         stat = 1-resSSE/totalSSE;
            %         return
            % end
            Bctr = basesUsed-mean(basesUsed, 2, "omitnan"); % nNeurons x nCats centered decoder bases
            % Orthonormal basis of coding subspace via SVD (stable, K small)
            [U, S, ~] = svd(Bctr, "econ");
            sing = diag(S);
            tol = max(size(Bctr))*eps(max(sing));
            d = nnz(sing>tol); % effective dimensionality of the coding subspace
            d = min(d, nCats-1); % cannot have more than nCats-1 dimensions of between-class variance
            if d<1
                stat = NaN;
                return
            end
            Q = U(:, 1:d); % nNeurons x d orthonormal basis for coding subspace
            X = Q'*X; % d x nTrials project data onto coding subspace
            XHat = Q'*XHat; % d x nTrials project predicted response onto coding subspace
            muTest = mean(X, 2, "omitnan"); % d x 1 mean of projected data
            Xc = X-muTest; % d x nTrials centered projected data
            totalSSE = sum(Xc.^2, "all", "omitnan"); % total sum of squares in coding subspace
            res = X-XHat; % d x nTrials residuals in coding subspace
            switch options.Type
                case "trace"
                    resSSE = sum(res.^2, "all", "omitnan"); % residual sum of squares in coding subspace
                    stat = 1-resSSE/totalSSE;
                    return
            end
            Stot = Xc*Xc'; % d x d total covariance in coding subspace
            Sres = res*res'; % d x d residual covariance in coding subspace
            epsVal = options.RidgeFraction*(totalSSE/d);
            epsVal = max(epsVal, 0);
            G = Stot+epsVal*eye(d); % d x d total covariance with ridge regularization
            % Generalized eigenvalues gamma of Sres w = gamma G w
            % Explained fractions per axis: lambda = 1 - gamma
            gamma = eig((Sres + Sres')/2, (G + G')/2);
            gamma = max(real(gamma), 0); % ensure nonnegative real parts
            lambda = 1-gamma; % explained variance fractions per axis
            lambda = sort(lambda, "descend");
            lambda = lambda(1:min(d, numel(lambda))); % keep only the top d eigenvalues
            switch options.Type
                case "max"
                    stat = max(lambda);
                case "pillai"
                    stat = mean(lambda);
                case "wilks"
                    % Determinant-ratio form in coding subspace:
                    %   1 - det(Sres + epsI) / det(Stot + epsI)
                    if epsVal<=0
                        % tiny ridge to make determinants well-defined
                        epsVal = 1e-12*(totalSSE/d);
                    end
                    A = (Stot+epsVal*eye(d));
                    B = (Sres+epsVal*eye(d));
                    A = (A+A') / 2;
                    B = (B+B') / 2;
                    LA = chol(A, "lower");
                    LB = chol(B, "lower");
                    logDetA = 2*sum(log(diag(LA)));
                    logDetB = 2*sum(log(diag(LB)));
                    ratio = exp(min(max(logDetB-logDetA, -700), 700));
                    stat = 1-ratio;
            end
        end

        function [stat, transform, d] = procrustes(mdl, X, y, options)
            arguments
                mdl spiky.stat.Coords
                X double
                y categorical
                options.Type string {mustBeMember(options.Type, ["sim" "nse" "r2" "varRatio" "cosine" "rdm" "corr"])} = "varRatio"
                options.Proj double = []
                options.AllowRotation logical = true
                options.AllowScaling logical = false
                options.AllowReflection logical = false
                options.AllowTranslation logical = true
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 1e-6
                options.NDims (1, 1) double {mustBePositive} = Inf
            end
            catsTrain = mdl.BasisNames;
            isValid = ismember(y, catsTrain);
            X = X(:, isValid); % nNeurons x nTrials
            y = y(isValid); % nTrials x 1 categorical
            [cats, ~, idcY] = unique(y);
            [~, idcCatInTrain] = ismember(cats, catsTrain);
            mTrain = mdl.Origin+mdl.Bases(:, idcCatInTrain); % nNeurons x nCats class means in training data
            mTest = groupsummary(X', y, "mean")'; % nNeurons x nCats class means in test data
            nCats = numel(cats);
            nNeurons = height(X);
            if options.Type=="sim"
                nLoop = 1; % fit between all classes in the training and test data together
            else
                nLoop = nCats; % fit each class in the test data using the other classes in the training and test data as reference
            end
            stat = NaN(nLoop, 1);
            transform = cell(nLoop, 1);
            d = NaN(nLoop, 1);
            for ii = 1:nLoop
                if options.Type=="sim"
                    XThis = X; % nNeurons x nTrials all data
                    idcOthers = 1:nCats;
                else
                    XThis = X(:, idcY==ii); % nNeurons x nTrials in this class
                    idcOthers = setdiff(1:nCats, ii);
                end
                idcTrialOthers = ismember(idcY, idcOthers);
                if isempty(options.Proj)
                    XOther = X(:, idcTrialOthers); % nNeurons x nTrials in other classes
                    resOther = XOther-mTest(:, idcY(idcTrialOthers)); % nNeurons x nTrials residuals for other classes
                    WOther = resOther*resOther'/(width(XOther)-nCats+1); % nNeurons x nNeurons covariance of other classes
                    WOther = WOther + options.RidgeFraction*trace(WOther)/width(WOther)*eye(size(WOther)); 
                        % add ridge regularization
                    W = chol(WOther, "lower"); % nNeurons x nNeurons whitening matrix based on other classes
                    mwTrain = W\mTrain; % nNeurons x nCats whitened class means in training data
                    mwTest = W\mTest; % nNeurons x nCats whitened class means in test data
                    XWThis = W\XThis; % nNeurons x nTrials whitened data for this class
                elseif ~isequal(options.Proj, NaN)
                    W = options.Proj; % nNeurons x nNeurons whitening matrix provided
                    mwTrain = W\mTrain; % nNeurons x nCats whitened class means in training data
                    mwTest = W\mTest; % nNeurons x nCats whitened class
                    XWThis = W\XThis; % nNeurons x nTrials whitened data for this class
                else
                    mwTrain = mTrain; % nNeurons x nCats class means in training data
                    mwTest = mTest; % nNeurons x nCats class means in test data
                    XWThis = XThis; % nNeurons x nTrials data for this class
                end
                mTrainOther = mwTrain(:, idcOthers); % nNeurons x nCats-1 class means of other classes in training data
                mTestOther = mwTest(:, idcOthers); % nNeurons x nCats-1 class means of other classes in test data
                mTestThis = mwTest(:, ii); % nNeurons x 1 class mean of this class in test data
                muTrainOther = mean(mTrainOther, 2); % nNeurons x 1 mean of other class means in training data
                muTestOther = mean(mTestOther, 2); % nNeurons x 1 mean of other class means in test data
                mcTrainOther = mTrainOther-muTrainOther; % nNeurons x nCats-1 centered other class means in training data
                mcTestOther = mTestOther-muTestOther; % nNeurons x nCats-1 centered other class means in test data
                mcTrainThis = mwTrain(:, ii)-muTrainOther; % nNeurons x 1 centered class mean for this class in training data
                if options.AllowTranslation
                    muTrainFit = muTrainOther;
                    muTestFit = muTestOther;
                else
                    muTrainFit = zeros(nNeurons, 1);
                    muTestFit = zeros(nNeurons, 1);
                end
                trainFit = mTrainOther-muTrainFit; % nNeurons x nCats-1 translation-fit other class means in training data
                testFit = mTestOther-muTestFit; % nNeurons x nCats-1 translation-fit other class means in test data
                [u, s, ~] = svd(trainFit, "econ");
                s = diag(s);
                if isempty(s) || all(s==0)
                    u = eye(nNeurons, 1);
                    rUse = 1;
                else
                    tol = max(size(trainFit))*eps(max(s));
                    rEff = sum(s>tol); % effective rank of translation-fit other class means in training data
                    rUse = max(1, min([rEff, max(1, nCats-2), width(u)]));
                    rUse = min(rUse, options.NDims);
                    u = u(:, 1:rUse); % nNeurons x rUse orthonormal basis for translation-fit other class means in training data
                end
                DTrain = u'*trainFit; % rUse x nCats-1 coordinates of centered other class means in training data
                DTest = u'*testFit; % rUse x nCats-1 coordinates of centered other class means in test data
                if false
                    if options.AllowRotation
                        mD = DTest*DTrain'; % rUse x rUse covariance between test and training centered other class means
                        [uD, ~, vD] = svd(mD, "econ");
                        rD = uD*vD'; % rUse x rUse optimal rotation from training to test centered other class means
                        if ~options.AllowReflection && det(rD)<0
                            uD(:, end) = -uD(:, end);
                            rD = uD*vD';
                        end
                    else
                        rD = eye(rUse);
                    end
                    if options.AllowScaling
                        denom = sum(DTrain(:).^2);
                        if denom<=0
                            b = 1;
                        else
                            b = sum((rD*DTrain).*DTest, "all")/denom;
                        end
                    else
                        b = 1;
                    end
                    d(ii) = spiky.utils.rotationMetric(rD); % rotation metric
                    pU = u*u'; % projection onto subspace of translation-fit other class means in training data
                    rFull = u*rD*u'+(eye(nNeurons)-pU); 
                        % full rotation matrix that aligns translation-fit other class means in training data to those in test data
                    tr = struct("T", rFull', "b", b, "c", (muTestFit-b*rFull*muTrainFit)');
                        % struct containing the Procrustes transformation from training to test data for this class
                else
                    if options.AllowReflection
                        options.AllowReflection = "best";
                    end
                    if ~options.AllowRotation
                        % linear regression aligned to neural axes
                        denom = sum(mcTrainOther.^2, 2)+options.RidgeFraction*trace(mcTrainOther'*mcTrainOther)/size(mcTrainOther, 1); 
                            % nNeurons x 1 ridge-regularized variance of other class means in training data along each neural axis
                        if options.AllowScaling
                            gain = sum(mcTrainOther.*mcTestOther, 2)./denom; % nNeurons x 1 regression gain along each neural axis
                        else
                            gain = ones(nNeurons, 1);
                        end
                        if options.AllowTranslation
                            bias = muTestOther-gain.*muTrainOther; % nNeurons x 1 regression bias along each neural axis
                        else
                            bias = zeros(nNeurons, 1);
                        end
                        tr.T = diag(gain); % nNeurons x nNeurons diagonal regression transformation matrix
                        tr.b = 1;
                        tr.c = bias'; % 1 x nNeurons regression translation vector
                        d(ii) = 0; % no rotation, so rotation metric is 0
                    else
                        [stat(ii), ~, tr] = procrustes(DTest', DTrain', ...
                            Scaling=options.AllowScaling, ...
                            Reflection=options.AllowReflection);
                        tr.c = mean(tr.c, 1);
                        d(ii) = spiky.utils.rotationMetric(tr.T); % rotation metric
                        % d(ii) = norm(tr.T-eye(size(tr.T)), "fro")/2/sqrt(rUse); % rotation metric based on Frobenius norm
                        % project back to full space
                        tr.T = u*tr.T*u'+(eye(nNeurons)-u*u'); % full-space transformation matrix
                        if options.AllowTranslation
                            tr.c = (u*tr.c'+muTestFit-tr.b*tr.T'*muTrainFit)'; % full-space translation vector
                        else
                            tr.c = zeros(1, nNeurons);
                        end
                    end
                end
                transform{ii} = tr;
                mcTestPred = tr.b.*tr.T'*mcTrainThis+tr.c'; % nNeurons x 1 predicted class mean for this class in test data
                mTestPred = mcTestPred+muTestOther; % nNeurons x 1 predicted class mean for this class in test data
                switch options.Type
                    case "sim"
                        if isnan(stat(ii))
                            scaleTrain = sum((mcTrainOther-mean(mcTrainOther, 2)).^2, "all");
                            mcPredOther = tr.b*tr.T'*mcTrainOther+tr.c'; % nNeurons x nCats
                            dTestPred = mean(vecnorm(mcTestOther-mcPredOther, 2, 1).^2/scaleTrain);
                            stat(ii) = dTestPred;
                        end
                        stat(ii) = 1-stat(ii); % convert from procrustes distance to similarity
                    case "nse"
                        stat(ii) = sum((mTestThis-mTestPred).^2, "all", "omitnan")/...
                            sum((mTestThis-muTestOther).^2, "all", "omitnan"); % normalized squared error for this class
                    case "r2"
                        stat(ii) = 1 - sum((mTestThis-mTestPred).^2, "all", "omitnan")/...
                            sum((mTestThis-muTestOther).^2, "all", "omitnan"); % R^2 for this class
                    case "varRatio"
                        trueSSE = sum((XWThis-mTestThis).^2, "all", "omitnan"); % sum of squares of true residuals for this class
                        predSSE = sum((XWThis-mTestPred).^2, "all", "omitnan"); % sum of squares of predicted residuals for this class
                        stat(ii) = trueSSE/predSSE; % ratio of true to predicted residual variance for this class
                    case "cosine"
                        vTrue = mTestThis-muTestOther; % nNeurons x 1 vector from mean of other classes to this class in test data
                        vPred = mTestPred-muTestOther; % nNeurons x 1 vector from mean of other classes to predicted class mean for this class in test data
                        denom = norm(vTrue)*norm(vPred);
                        if denom<=0
                            stat(ii) = NaN;
                        else
                            stat(ii) = (vTrue'*vPred)/denom; % cosine similarity between true and predicted vectors
                        end
                    case "rdm"
                        dTrue = vecnorm(mTestThis-mTestOther, 2, 1); % distance from this class to other classes in test data
                        dPred = vecnorm(mTestPred-mTestOther, 2, 1); % distance from predicted class mean other classes in test data
                        stat(ii) = corr(dTrue', dPred', Type="spearman", Rows="complete"); % correlation between true and predicted representational dissimilarity
                    case "corr"
                        vTrue = mTestThis-muTestOther; % vector from mean of other classes to this class in test data
                        vPred = mTestPred-muTestOther; % vector from mean of other classes to predicted class mean for this class in test data
                        stat(ii) = corr(vTrue', vPred', Rows="complete"); % correlation between true and predicted vectors
                end
            end
            stat = mean(stat); % average mean squared error across classes
            transform = cell2mat(transform); % convert cell array of structs to struct array
            d = mean(d); % average rotation metric across classes
        end

        function logDet = logDetLowRank(X, epsVal)
            % log det(epsI + X X') for X in R^{p x n} using determinant lemma:
            % det(epsI + X X') = eps^p det(I + (1/eps) X'X)

            [p, n] = size(X);
            if n == 0
                logDet = p * log(epsVal);
                return;
            end

            A = eye(n) + (1 / epsVal) * (X' * X);
            A = (A + A') / 2;

            % Cholesky for numerical stability
            [L, flag] = chol(A, "lower");
            if flag ~= 0
                jitter = 1e-6 * trace(A) / max(size(A, 1), 1);
                A = A + jitter * eye(n);
                L = chol(A, "lower");
            end

            logDet = p * log(epsVal) + 2 * sum(log(diag(L)));
        end

        function p = calcP(data, shuf, options)
            %CALCP Calculate p-values for decoder performance based on empirical or normal null distribution.
            %   p = calcP(data, shuf, ...)
            %
            %   data: nT x nGroups x nPartitions x nConditions array of decoder performance statistics
            %   shuf: nT x nGroups x nShuffles x nConditions array of decoder performance statistics 
            %       for shuffled data, or empty if using normal distribution
            %   Name-value arguments:
            %       Mu: nT x nGroups x 1 x nConditions array of means
            %       Sigma: nT x nGroups x 1 x nConditions array of standard errors
            %       Type: "empirical" or "normal" (default: "empirical")
            %       Side: "low", "high", or "two" (default: "two")
            arguments
                data double
                shuf double = []
                options.Mu double = mean(shuf, 3)
                options.Sigma double = std(shuf, 0, 3)./sqrt(size(data, 3))
                options.Type string {mustBeMember(options.Type, ["empirical" "normal"])} = "empirical"
                options.Side string {mustBeMember(options.Side, ["low" "high" "two"])} = "two"
            end
            m = mean(data, 3);
            switch options.Type
                case "empirical"
                    cLow = sum(shuf<m, 3);
                    cHigh = sum(shuf>m, 3);
                    switch options.Side
                        case "low"
                            c = cLow;
                        case "high"
                            c = cHigh;
                        case "two"
                            mShuf = mean(shuf, 3);
                            c = zeros(size(m));
                            c(mShuf>=m) = cLow(mShuf>=m);
                            c(mShuf<m) = cHigh(mShuf<m);
                    end
                    p = (c+1)./(size(shuf, 3)+1);
                        % add 1 to numerator and denominator for continuity correction
                case "normal"
                    mu = options.Mu;
                    sigma = options.Sigma;
                    switch options.Side
                        case "low"
                            p = min(normcdf(m, mu, sigma), 0.5); 
                        case "high"
                            p = min(normcdf(m, mu, sigma, "upper"), 0.5);
                        case "two"
                            p = min(normcdf(m, mu, sigma), normcdf(m, mu, sigma, "upper"))*2;
                    end
            end
        end
    end

    methods
        function obj = Decoder(time, data, x, y, ...
                groups, groupIndices, partitions, conditions, proj, options)
            %DECODER Create a new instance of Decoder
            arguments
                time double = []
                data = []
                x cell = {}
                y cell = {}
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                proj cell = cell(size(data, 1), size(data, 2), 1, size(data, 4))
                options.Type (1, 1) string = "mean"
                options.DataTest = cell(size(data))
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices, partitions, conditions)
            obj.X = x;
            obj.Y = y;
            obj.Proj = proj;
            obj.Type_ = options.Type;
            obj.DataTest = options.DataTest;
        end

        function type = get.Type(obj)
            type = obj.Type_;
        end

        function obj = cat(dim, varargin)
            obj = cat@spiky.core.ArrayBase(dim, varargin{:});
            if dim==1
                y = spiky.utils.cellfun(@(d) d.Y, varargin);
                partitions = spiky.utils.cellfun(@(d) d.Partitions, varargin);
                obj.Y = y;
                obj.Partitions = partitions;
            end
        end

        function obj = splitConditions(obj, conditions, cats)
            arguments
                obj spiky.stat.Decoder
                conditions (:, 1) categorical
                cats (:, 1) categorical
            end
            assert(isa(obj.Data{1}, "spiky.stat.Coords"), "Data must be spiky.stat.Coords")
            assert(isequal(numel(conditions), numel(cats), obj.Data{1}.NBases), ...
                "conditions, cats, and number of decoder bases must match")
            [conds, ~, idcCond] = unique(conditions, "stable");
            nConds = numel(conds);
            objs = cell(nConds, 1);
            for ii = 1:nConds
                idc1 = idcCond==ii;
                cats1 = cats(idc1);
                objs{ii} = obj;
                objs{ii}.Data = cellfun(@(d) spiky.stat.Coords(d.Origin, d.Bases(:, idc1), d.DimNames, cats1), ...
                    obj.Data, UniformOutput=false);
                if ~isempty(obj.DataTest{1})
                    objs{ii}.DataTest = cellfun(@(d) spiky.stat.Coords(d.Origin, d.Bases(:, idc1), d.DimNames, cats1), ...
                        obj.DataTest, UniformOutput=false);
                else
                    objs{ii}.DataTest = cell(size(obj.Data));
                end
                objs{ii}.Y{1} = obj.Y{1}(:, idc1); 
            end
            obj = cat(4, objs{:});
            obj.Conditions = conds;
        end

        function ss = getSubspaces(obj, nDims, options)
            arguments
                obj spiky.stat.Decoder
                nDims (1, 1) double = 0
                options.Window (1, 2) double = obj.Time([1 end])'
                options.TimeDependent logical = true
            end
            assert(obj.Type=="svm");
            [nT, nGroups, nPartitions, nConditions] = size(obj.Data);
            hasTestData = ~isempty(obj.DataTest{1});
            idcInWindow = obj.Time>=options.Window(1) & obj.Time<=options.Window(2);
            nDims0 = numel(obj.Data{1}.ClassNames);
            if nDims==0
                nDims = nDims0;
            else
                nDims = min(nDims, nDims0);
            end
            t = obj.Time(idcInWindow);
            nT1 = numel(t);
            data = obj.Data(idcInWindow, :, :, :, :);
            if hasTestData
                data = cat(6, data, obj.DataTest(idcInWindow, :, :, :, :)); % concatenate train and test data along 5th dimension
            end
            data = cellfun(@(mdl) spiky.utils.cellfun(@(l) l.Beta, mdl.BinaryLearners'), data, ...
                UniformOutput=false); % Each cell is now nNeurons x nClasses beta weights
            if ~options.TimeDependent
                data = num2cell(data, 1);
                data = cellfun(@(c) horzcat(c{:}), data, UniformOutput=false); 
                % Each cell is now nNeurons x nClasses*nT1 concatenated across time
                t = 0;
            end
            data = cellfun(@(beta) spiky.stat.Coords(zeros(height(beta), 1), beta).pca(nDims, Type="dims"), ...
                data, UniformOutput=false);
            if hasTestData
                dataTest = data(:, :, :, :, :, 2);
                data = data(:, :, :, :, :, 1);
            else
                dataTest = cell(size(data));
            end
            ss = spiky.stat.Subspaces(t, data, obj.Groups, obj.GroupIndices, obj.Partitions, ...
                obj.Conditions, X=obj.X, Y=obj.Y, DataTest=dataTest);
        end

        function ss = getProjections(obj, options)
            %GETPROJECTIONS Extract the projections of the decoder object
            arguments
                obj spiky.stat.Decoder
                options.NDims (1, 1) double {mustBePositive} = Inf
            end
            proj = cellfun(@(mdl) mdl(:, 1:min(options.NDims, width(mdl))), obj.Proj, UniformOutput=false);
            ss = spiky.stat.Subspaces(obj.Time, proj, obj.Groups, obj.GroupIndices, ...
                obj.Partitions, obj.Conditions, X=obj.X, Y=obj.Y);
        end

        function varargout = getStats(obj, options)
            %GETSTATS Get statistics related to the decoder models.
            %   [stats, ...] = GETSTATS(obj, options)
            %
            %   obj: Decoder object
            %   Name-value arguments:
            %       Metric: metric to calculate
            %           "prediction": predicted values from the decoder model (default)
            %           "varExplained": variance explained by the decoder model
            %           "procrustes": variance explained under procrustes alignment
            %           "accuracy": classification accuracy of the decoder model
            %           "confusion": confusion matrix of the decoder model
            %       X: input data to use for calculating statistics (default: obj.X)
            %       Y: target data to use for calculating statistics (default: obj.Y)
            %       Model: external model to use for calculating statistics instead of the decoder 
            %           models in obj.Data (default: [])
            %       Proj: whether to proj the data by the Mahalanobis weights in obj.Proj when 
            %           calculating statistics, or which whitening matrix to use (default: "train", 
            %           use the training data's whitening matrix; "test", use the test data's whitening 
            %           matrix; "none", do not proj; or a nNeurons x nNeurons whitening matrix to use for whitening)
            %       CrossTime: whether to perform cross-time decoding (default: false)
            %       CrossCondition: whether to perform cross-condition decoding (default: false)
            %       VarType: type of variance explained metric (default: "trace")
            %       ProcrustesType: type of procrustes metric (default: "varRatio")
            %       RidgeFraction: fraction of ridge regularization to apply when calculating variance explained (default: 0)
            %       NDims: number of dimensions to keep (default: Inf)
            %       AllowRotation: whether to allow rotation in Procrustes alignment (default: true)
            %       AllowScaling: whether to allow scaling in Procrustes alignment (default: false)
            %       AllowReflection: whether to allow reflection in Procrustes alignment (default: false)
            %       AllowTranslation: whether to allow translation in Procrustes alignment (default: true)
            %       Shuffle: whether to shuffle labels for significance testing (default: false)
            %       CalcP: whether to calculate p-values via permutation testing (default: false), S
            %
            %   stats: GroupedStat object containing the calculated statistics, nT x nGroups x nPartitions x nTrain x nTest
            %   ...: additional output arguments containing relevant info for the calculated statistics
            %       [stats, transforms, d] = getStats(..., Metric="procrustes")
            %           returns the Procrustes transformation structs for each decoder model
            arguments
                obj spiky.stat.Decoder
                options.Metric (1, 1) string {mustBeMember(options.Metric, ...
                    ["prediction" "varExplained" "procrustes" "accuracy" "confusion" "proj" "angle" "vaf" ...
                    "deviance" "gain"])} = "prediction"
                options.X = []
                options.Y = []
                options.Model = []
                options.Proj string {mustBeMember(options.Proj, ["none", "train", "test"])} = "train"
                options.CrossTime logical = false
                options.CrossCondition logical = false
                options.VarType string {mustBeMember(options.VarType, ["trace", "max", "pillai", "wilks"])} = "trace"
                options.ProcrustesType string {mustBeMember(options.ProcrustesType, ...
                    ["sim" "nse" "r2" "varRatio" "cosine" "rdm" "corr"])} = "sim"
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 1e-6
                options.NDims (1, 1) double {mustBePositive} = Inf
                options.AllowRotation logical = true
                options.AllowScaling logical = false
                options.AllowReflection logical = false
                options.AllowTranslation logical = true
                options.NShuffle double = 100;
                options.CalcP logical = false
                options.ProjTarget string {mustBeMember(options.ProjTarget, ["train" "test" "all"])} = "test"
            end
            chance = NaN;
            switch options.Metric
                case "varExplained"
                    assert(obj.Type=="mean")
                    chance = 0;
                case "accuracy"
                    assert(ismember(obj.Type, ["svm" "lda" "naivebayes"]))
                    chance = 1/numel(obj.Data{1}.ClassNames);
                    options.Proj = "train";
                case "proj"
                    % options.NDims = min(options.NDims, 4);
            end
            nT = height(obj.Data);
            nGroups = width(obj.Data);
            nPartitions = size(obj.Data, 3);
            nConditions = size(obj.Data, 4);
            isCompareMdl = ismember(options.Metric, ["proj" "angle" "vaf" "gain"]);
            isCellMode = ismember(options.Metric, ["prediction" "confusion" "proj" "deviance"]);
            isCellMerge = ismember(options.Metric, ["confusion"]);
            if options.CrossTime && options.CrossCondition
                assert(size(obj.Data, 4)==2)
            end
            if options.CrossTime
                nTrain = 1;
                nTest = nT;
            elseif options.CrossCondition
                nTrain = nConditions;
                nTest = nConditions;
            else
                nTrain = nConditions;
                nTest = 1;
            end
            stats = cell(nT, nGroups, nPartitions, nTrain);
            if options.CalcP
                nShuffle = options.NShuffle;
                nShufflePerPart = ceil(nShuffle/nPartitions);
                nShuffle = nShufflePerPart*nPartitions; % adjust nShuffle to be a multiple of nPartitions
            else
                nShuffle = nPartitions;
                nShufflePerPart = 1;
            end
            shuf = cell(nT, nGroups, nPartitions, nTrain);
            shufExtra = cell(nT, nGroups, nPartitions, nTrain);
            if options.Metric=="prediction"
                scores = cell(nT, nGroups, nPartitions, nTrain);
            end
            if options.Metric=="procrustes"
                transforms = cell(nT, nGroups, nPartitions, nTrain);
                d = cell(nT, nGroups, nPartitions, nTrain);
            end
            n = nT*nGroups*nPartitions*nTrain;
            mdls = obj.Data; % nT x nGroups x nPartitions x nTrain cell of decoder models
            if options.CrossTime
                mdls = mdls(:, :, :, 1); % use the first condition's models for cross-time decoding
            end
            if options.Metric=="proj"
                if mdls{1}.NBases>options.NDims
                    mdls = cellfun(@(coords) coords.pca(options.NDims, Type="dims"), mdls, ...
                        UniformOutput=false); % nNeurons x nDims PCA projection matrices for each model
                end
                % for projection metric, align the decoder bases to the first one
                mdls = spiky.stat.Coords.align(mdls, 3); % align decoder bases across partitions
            end
            mdls2 = cell(nT, nGroups, nPartitions, nTrain);
            data2 = obj.Data;
            if ~isempty(obj.DataTest{1})
                data2 = obj.DataTest; % use DataTest for calculating statistics if provided
            end
            if isCompareMdl
                for ii = 1:n
                    [idxT, idxG, idxP, ~] = ind2sub([nT, nGroups, nPartitions, nTrain], ii);
                    idxP = mod(idxP, nPartitions)+1; % wrap partition index for shuffling
                    if options.CrossTime && ~options.CrossCondition
                        mdls2{ii} = data2(:, idxG, idxP, 1);
                    elseif options.CrossTime && options.CrossCondition
                        mdls2{ii} = data2(:, idxG, idxP, 2);
                    elseif options.CrossCondition
                        mdls2{ii} = data2(idxT, idxG, idxP, :);
                    else
                        mdls2{ii} = data2(idxT, idxG, idxP, 1);
                    end
                end
            end
            X = options.X; % nT x nGroups x 1 x nConditions cell of nNeurons x nTrials
            y = options.Y; % nConditions x (nT) cell of nTrials x 1 categorical
            if isempty(X)
                useTrainingData = true;
                X = obj.X;
            else
                useTrainingData = false;
            end
            if isempty(y)
                y = obj.Y;
            end
            isTimeVarying = width(y)>1;
            if ~isempty(options.Model)
                if isa(options.Model, "spiky.stat.Decoder")
                    options.Model = options.Model.Data; % extract the model from the Decoder object
                end
                if ~iscell(options.Model)
                    options.Model = {options.Model}; % convert to cell if not already
                end
                % options.Model = options.Model(:)'; % ensure row vector
                assert(width(options.Model)==nGroups)
                if nT>1 && height(options.Model)==1
                    options.Model = repmat(options.Model, nT, 1, 1, 1);
                end
                if nPartitions>1 && size(options.Model, 3)==1
                    options.Model = repmat(options.Model, 1, 1, nPartitions, 1);
                end
                if nTrain>1 && size(options.Model, 4)==1
                    options.Model = repmat(options.Model, 1, 1, 1, nTrain);
                end
                mdls = options.Model;
            end
            proj = obj.Proj; % nT x nGroups x nPartitions x nConditions cell of nNeurons x nProj projection coords (e.g. whitening matrices)
            partitions = obj.Partitions; % nConditions x (nT) cell of partition labels
            pValues = NaN(nT, nGroups, 1, nTrain, nTest); % nT x nGroups x 1 x nTrain x nTest array of p-values for each statistic
            sz = [nT, nGroups, nPartitions, nTrain];
            pb = spiky.plot.ProgressBar(n, "Calculating statistics "+options.Metric);
            parfor ii = 1:n
                [idxT, idxG, idxP, idxC] = ind2sub(sz, ii);
                if isTimeVarying
                    idxTY = idxT;
                else
                    idxTY = 1;
                end
                mdl = mdls{ii};
                if isCompareMdl
                    mdlsTest = mdls2{ii}; % nTest x 1 cell of models to compare to for this model
                end
                stat1 = NaN(1, 1, 1, 1, nTest);
                if isCellMode
                    stat1 = cell(1, nTest);
                end
                if ismember(options.Metric, ["prediction"])
                    scores1 = cell(1, nTest);
                end
                if ismember(options.Metric, ["procrustes"])
                    transform1 = cell(1, nTest);
                    d1 = NaN(1, nTest);
                end
                if options.CalcP
                    if isCellMode
                        shuf1 = cell(1, 1, nShufflePerPart, 1, nTest);
                        shufExtra1 = cell(1, 1, nShufflePerPart, 1, nTest);
                    else
                        shuf1 = NaN(1, 1, nShufflePerPart, 1, nTest);
                        shufExtra1 = NaN(1, 1, nShufflePerPart, 1, nTest);
                    end
                end
                for jj = 1:nTest
                    isCrossCond = false;
                    idxC0 = idxC;
                    if options.CrossTime
                        idxT = jj; % use model from time jj for testing
                        if isTimeVarying
                            idxTY = idxT;
                        end
                        if options.CrossCondition
                            idxC = 2; % use last condition for testing in cross-time decoding
                            isCrossCond = length(y{idxC0})==length(y{idxC});
                        end
                    elseif options.CrossCondition
                        isCrossCond = idxC~=jj & length(y{idxC0})==length(y{jj});
                        idxC = jj; % use condition jj for testing
                    end
                    if ~isempty(X{1})
                        if useTrainingData
                            idcPTest = partitions{idxC, idxTY}(idxP, :)==1 & ~isnan(X{idxT, idxG, 1, idxC}(1, :));
                                % indices of trials in test partition
                        else
                            idcPTest = ~isnan(X{idxT, idxG, 1, idxC}(1, :));
                                % indices of trials in test partition
                        end
                        XAll = X{idxT, idxG, 1, idxC}; % nNeurons x nTrials for all trials in this condition
                        yAll = y{idxC, idxTY}; % nTrials x 1 categorical (or nTrials x nCats flags) for all trials in this condition
                        XTest = X{idxT, idxG, 1, idxC}(:, idcPTest); % nNeurons x nTrials
                        yTest = y{idxC, idxTY}(idcPTest, :); % nTrials x 1 categorical (or nTrials x nCats flags)
                        XTrain = X{idxT, idxG, 1, idxC}(:, ~idcPTest); % nNeurons x nTrials
                        yTrain = y{idxC, idxTY}(~idcPTest, :); % nTrials x 1 categorical (or nTrials x nCats flags)
                        if isCrossCond
                            yTestOrig = y{idxC0, idxTY}(idcPTest, :);
                        end
                        P = []; % projection coords object
                        if options.Proj=="train"
                            P = proj{ii};
                            if isa(P, "spiky.stat.Coords")
                                W = P.Bases'; % nProjs x nNeurons projection matrix for this model
                            else
                                W = P;
                            end
                        elseif options.Proj=="test"
                            W = [];
                        else
                            W = NaN;
                        end
                    else
                        idcPTest = partitions{idxC, idxTY}(idxP, :)==1; % indices of trials in test partition
                        XAll = [];
                        yAll = [];
                        XTest = [];
                        yTest = [];
                        W = NaN;
                    end
                    switch options.Metric
                        case "varExplained"
                            stat1(jj) = spiky.stat.Decoder.varExplained(mdl, XTest, yTest, ...
                                Type=options.VarType, RidgeFraction=options.RidgeFraction, ...
                                Proj=W);
                            if options.CalcP
                                for kk = 1:nShufflePerPart
                                    idc = randperm(length(yTest));
                                    yTestShuf = yTest(idc);
                                    shuf1(1, 1, kk, 1, jj) = spiky.stat.Decoder.varExplained(mdl, XTest, yTestShuf, ...
                                        Type=options.VarType, RidgeFraction=options.RidgeFraction, ...
                                        Proj=W);
                                end
                            end
                        case "procrustes"
                            [stat1(jj), transform1{jj}, d1(jj)] = spiky.stat.Decoder.procrustes(mdl, XTest, yTest, ...
                                Type=options.ProcrustesType, ...
                                Proj=W, ...
                                AllowRotation=options.AllowRotation, ...
                                AllowScaling=options.AllowScaling, ...
                                AllowReflection=options.AllowReflection, ...
                                AllowTranslation=options.AllowTranslation, ...
                                RidgeFraction=options.RidgeFraction, ...
                                NDims=options.NDims);
                            if options.CalcP
                                for kk = 1:nShufflePerPart
                                    % [~, ~, idcY] = unique(yTest);
                                    % nCats = numel(idcY);
                                    % idcCats = randperm(nCats)';
                                    % yTest = yTest(idcCats(idcY));
                                    % idcTrain = randperm(mdl.NBases);
                                    % mdl.Bases = mdl.Bases(:, idcTrain);
                                    idc = randperm(length(yTest));
                                    yTest = yTest(idc);
                                    [shuf1(1, 1, kk, 1, jj), ~, shufExtra1(1, 1, kk, 1, jj)] = ...
                                        spiky.stat.Decoder.procrustes(mdl, XTest, yTest, ...
                                        Type=options.ProcrustesType, ...
                                        Proj=W, ...
                                        AllowRotation=options.AllowRotation, ...
                                        AllowScaling=options.AllowScaling, ...
                                        AllowReflection=options.AllowReflection, ...
                                        AllowTranslation=options.AllowTranslation, ...
                                        RidgeFraction=options.RidgeFraction, ...
                                        NDims=options.NDims);
                                end
                            end
                        case "prediction"
                            if ~isempty(P)
                                XTest = P.project(XTest); % proj the test data by the proj coords object
                            elseif ~isempty(W)
                                XTest = W*XTest; % proj the test data by the proj matrix
                            end
                            if isa(mdl, "classreg.learning.classif.CompactClassificationECOC") || ...
                                isa(mdl, "classreg.learning.classif.CompactClassificationDiscriminant")
                                XTest = XTest';
                            end
                            nTrials = numel(idcPTest);
                            nCats = numel(mdl.ClassNames);
                            yPred = categorical(strings(nTrials, 1), categories(mdl.ClassNames));
                            sPred = NaN(numel(idcPTest), nCats);
                            if isa(mdl, "classreg.learning.classif.CompactClassificationDiscriminant")
                                [yPred(idcPTest), sPred(idcPTest, :)] = mdl.predict(XTest);
                            elseif isa(mdl, "classreg.learning.classif.CompactClassificationECOC")
                                if strcmp(mdl.ScoreType, "probability")
                                    [yPred(idcPTest), ~, ~, sPred(idcPTest, :)] = mdl.predict(XTest);
                                else
                                    yPred(idcPTest) = mdl.predict(XTest);
                                    sPred = [];
                                end
                            else
                                yPred(idcPTest) = mdl.predict(XTest);
                                sPred = [];
                            end
                            stat1{jj} = yPred;
                            scores1{jj} = sPred;
                        case "accuracy"
                            if ~isempty(P)
                                XTest = P.project(XTest); % proj the test data by the proj coords object
                            elseif ~isempty(W)
                                XTest = W*XTest; % proj the test data by the proj matrix
                            end
                            if isa(mdl, "classreg.learning.classif.CompactClassificationECOC") || ...
                                isa(mdl, "classreg.learning.classif.CompactClassificationDiscriminant")
                                XTest = XTest';
                            end
                            yPred = mdl.predict(XTest);
                            if ~isCrossCond
                                stat = groupsummary(yPred==yTest, yTest, "mean"); % accuracy for each class
                            else
                                % nClasses = numel(mdl.ClassNames);
                                % w = zeros(length(yTest), 1);
                                % for kk = 1:nClasses
                                %     for ll = 1:nClasses
                                %         isPair = yTestOrig==mdl.ClassNames(kk) & yTest==mdl.ClassNames(ll);
                                %         nPair = sum(isPair);
                                %         if nPair>0
                                %             w(isPair) = 1/nPair; 
                                %             % weight each class pair by inverse of number of trials in that pair to avoid biasing towards pairs with more trials
                                %         end
                                %     end
                                % end
                                % stat = sum(double(yPred==yTest).*w)/sum(w); % overall accuracy weighted by class pair counts
                                stat = groupsummary(yPred==yTest, {yTestOrig, yTest}, "mean"); % accuracy for each class pair
                            end
                            stat1(jj) = mean(stat); % overall accuracy
                        case "confusion"
                            if isa(mdl, "classreg.learning.classif.CompactClassificationECOC")
                                XTest = XTest';
                            end
                            yPred = mdl.predict(XTest);
                            cats = mdl.ClassNames;
                            c = confusionmat(yTest, yPred, Order=cats);
                            c = c./sum(c, 2); % normalize by true class counts to get conditional probabilities
                            stat1{jj} = shiftdim(c, -5); % 1 x 1 x 1 x 1 x 1 x nCats x nCats confusion matrix
                            if options.CalcP
                                for kk = 1:nShufflePerPart
                                    idc = randperm(length(yTest));
                                    yTestShuf = yTest(idc);
                                    cShuf = confusionmat(yTestShuf, yPred, Order=cats);
                                    cShuf = cShuf./sum(cShuf, 2);
                                    shuf1{1, 1, kk, 1, jj} = shiftdim(cShuf, -5);
                                end
                            end
                        case "proj"
                            % y1 = spiky.utils.flagsencode(yAll); % nTrials x nCats binary indicator matrix for test labels
                            % m = XAll*y1./sum(y1, 1); % nNeurons x nCats class means in test data
                            % p = mdl.project(m); % nDims x nCats
                            % stat1{jj} = spiky.stat.Coords(zeros(height(p), 1), p, 1:height(p), ...
                            %     categories(yTest, OutputType="categorical"));
                            x1 = NaN(width(mdl.NDimsOutput), numel(idcPTest));
                            switch options.ProjTarget
                                case "train"
                                    x = mdl.project(XTrain);
                                    x1(:, ~idcPTest) = x; % nNeurons x nTrials with NaN for trials not in train partition
                                case "test"
                                    x = mdl.project(XTest);
                                    x1(:, idcPTest) = x; % nNeurons x nTrials with NaN for trials not in test partition
                                case "all"
                                    x1 = mdl.project(XAll); % nNeurons x nTrials for all trials in this condition
                            end
                            stat1{jj} = x1;
                        case "angle"
                            mdlTest = mdlsTest{jj};
                            if mdl.NBases>options.NDims
                                mdl = mdl.pca(options.NDims, Type="dims"); % nNeurons x nDims subspaces
                            end
                            if mdlTest.NBases>options.NDims
                                mdlTest = mdlTest.pca(options.NDims, Type="dims"); % nNeurons x nDims subspaces
                            end
                            stat1(jj) = mdl.getSimilarity(mdlTest, Metric="angle");
                        case "vaf"
                            mdlTest = mdlsTest{jj};
                            c = mdl.pca(options.NDims, Type="dims"); % nNeurons x nDims subspaces
                            c.Origin = c.Origin*0;
                            cTest = mdlTest.pca(options.NDims, Type="dims"); % nNeurons x nDims subspaces
                            coefTest = mdlTest.Bases-mean(mdlTest.Bases, 2); % nNeurons x nCats centered coefficients
                            [~, coefPred] = c.project(cTest.Bases); % nNeurons x nCats projection of test coefficients onto train subspace
                            stat1(jj) = sum(coefPred.^2, "all")/sum(coefTest.^2, "all");
                        case "deviance"
                            stat1{jj} = cellfun(@(x) x.Deviance, mdl);
                            stat1{jj} = stat1{jj}(:)';
                        case "gain"
                            mdlTest = mdlsTest{jj};
                            stat1(jj) = norm(mdl.Bases-mean(mdl.Bases, 2), "fro")/...
                                norm(mdlTest.Bases-mean(mdlTest.Bases, 2), "fro");
                    end
                end
                if isCellMerge
                    stats{ii} = cat(5, stat1{:});
                else
                    stats{ii} = stat1;
                end
                if ismember(options.Metric, ["prediction"])
                    scores{ii} = scores1;
                end
                if ismember(options.Metric, ["procrustes"])
                    transforms{ii} = transform1;
                    d{ii} = d1;
                end
                if options.CalcP
                    if isCellMerge
                        shuf{ii} = cell2mat(shuf1);
                        shufExtra{ii} = cell2mat(shufExtra1);
                    else
                        shuf{ii} = shuf1;
                        shufExtra{ii} = shufExtra1;
                    end
                end
                pb.step
            end
            if isCellMode && ~isCellMerge
                stats = reshape(vertcat(stats{:}), nT, nGroups, nPartitions, nTrain, nTest);
            else
                stats = cell2mat(stats); % nT x nGroups x nPartitions x nTrain x nTest
            end
            if options.CrossTime
                partitions = repmat(obj.Partitions(1, :), nT, 1);
                conditions = obj.Time;
                stats = permute(stats, [1 2 3 5 4]); % nT x nGroups x nPartitions x nTest
            else
                partitions = obj.Partitions;
                conditions = obj.Conditions;
            end
            stats = spiky.stat.GroupedStat(obj.Time, stats, obj.Groups, obj.GroupIndices, ...
                partitions, conditions, Metric=options.Metric, Chance=chance, X=obj.X, Y=obj.Y);
            if ~isempty(shuf{1})
                shuf = cell2mat(shuf);
            end
            if ~isempty(shufExtra{1})
                shufExtra = cell2mat(shufExtra);
            end
            if options.CalcP && options.Metric~="accuracy"
                stats.Shuffle = shuf;
                stats.P = spiky.stat.Decoder.calcP(stats.Data, shuf, Side="high");
                stats.Chance = mean(shuf, "all", "omitmissing");
            end
            switch options.Metric
                case "prediction"
                    scores = reshape(vertcat(scores{:}), nT, nGroups, nPartitions, nTrain, nTest);
                    if ~isempty(scores{1}) % posterior available
                        statsData = num2cell(stats.Data, 3);
                        scores = num2cell(scores, 3);
                        for ii = 1:numel(scores)
                            s = cat(3, scores{ii}{:}); % nTrials x nCats x nPartitions posterior probabilities
                            s = mean(s, 3, "omitmissing");
                            [~, idcMax] = max(s, [], 2);
                            cats = categories(statsData{ii}{1}, OutputType="categorical");
                            d = categorical(strings(size(idcMax)));
                            isValid = ~isnan(idcMax);
                            d(isValid) = cats(idcMax(isValid));
                            statsData{ii} = d;
                            scores{ii} = s;
                        end
                        scores = spiky.stat.GroupedStat(obj.Time, scores, obj.Groups, obj.GroupIndices, ...
                            partitions, conditions, Metric="prediction");
                        stats.Data = statsData;
                        varargout{2} = scores;
                    end
                case "accuracy"
                    if options.CalcP
                        m = mean(stats.Data, 3, "omitmissing");
                        sigma = chance*(1-chance)/sqrt(nPartitions);
                        stats.P = spiky.stat.Decoder.calcP(stats.Data, Mu=chance, Sigma=sigma, ...
                            Type="normal", Side="high");
                    end
                case "confusion"
                    cats = obj.Data{1}.ClassNames;
                    stats = spiky.stat.Confusion(stats.Time, stats.Data, stats.Groups, stats.GroupIndices, ...
                        stats.Partitions, stats.Conditions, Cats=cats);
                    if options.CalcP
                        % for confusion matrices, calculate p-values for each cell using the shuffle distribution
                        p = (1+sum(shuf>=mean(stats.Data, 3), 3, "omitmissing"))./(1+size(shuf, 3));
                        stats.P = p;
                    end
                case "procrustes"
                    transforms = reshape(vertcat(transforms{:}), nT, nGroups, nPartitions, nTrain, nTest);
                    % transforms = cell2mat(transforms);
                    transforms = spiky.stat.GroupedStat(obj.Time, transforms, obj.Groups, obj.GroupIndices, ...
                        partitions, conditions, Metric="procrustesTransform");
                    d = reshape(vertcat(d{:}), nT, nGroups, nPartitions, nTrain, nTest);
                    d = spiky.stat.GroupedStat(obj.Time, d, obj.Groups, obj.GroupIndices, ...
                        partitions, conditions, Metric="rotation");
                    if options.CalcP
                        d.Shuffle = shufExtra;
                        d.P = spiky.stat.Decoder.calcP(d.Data, shufExtra, Side="low");
                        d.Chance = mean(shufExtra, "all", "omitmissing");
                    end
                    varargout{2} = transforms;
                    varargout{3} = d;
                case "proj"
                    % stats.Data is a nT x nGroups x nPartitions x nConditions x nConditionsTest cell of nDims x nTrials projected data
                    % output is a nT x nGroups x 1 x nConditions x nConditionsTest cell of 1 x nTrials x nDims x nPartitions TrigFr object
                    t = stats.Time;
                    nT = height(stats.Data);
                    nGroups = width(stats.Data);
                    nPartitions = size(stats.Data, 3);
                    nConditions = size(stats.Data, 4);
                    nConditionsTest = size(stats.Data, 5);
                    nTrials = width(stats.Data{1});
                    nDims = height(stats.Data{1});
                    data = num2cell(stats.Data, 3);
                    for ii = 1:numel(data)
                        [idxT, idxG, ~, idxC, idxCT] = ind2sub([nT, nGroups, 1, nConditions, nConditionsTest], ii);
                        data1 = permute(cat(3, data{ii}{:}), [4 2 1 3]); % 1 x nTrials x nDims x nPartitions
                        % isValid = ~isnan(data1(1, :, 1, :)); % 1 x nTrials x 1 x nPartitions logical
                        % nValidReps = sum(isValid, 4); % 1 x nTrials number of valid partitions for each trial
                        % nValidMax = max(nValidReps);
                        % data2 = NaN(1, nTrials, nDims, nValidMax); % 1 x nTrials x nDims x nValidMax
                        % for jj = 1:width(data1)
                        %     idc = find(isValid(1, jj, 1, :)); % indices of valid partitions for this trial
                        %     data2(1, jj, :, 1:length(idc)) = data1(1, jj, :, idc); % copy valid partitions for this trial
                        % end
                        data1 = spiky.trig.TrigFr(0, 1, data1);
                        data1.Time = t(idxT);
                        data{ii} = data1;
                    end
                    stats.Data = data;
                    % -- Obsolete: create TrigFr object (only works if all conditions have the same number of trials)
                        % output is a nT x nTrials x (nDims x nGroups) x nPartitions x nConditions x nConditionsTest TrigFr object
                        % neurons = spiky.core.Neuron.create(spiky.ephys.Session(""), stats.Groups, nDims);
                        % data = cat(3, stats.Data{:}); % nDims x nTrials x (nT x nGroups x nPartitions x nConditions)
                        % data = reshape(data, nDims, nTrials, nT, nGroups, nPartitions, nConditions, nConditionsTest);
                        % data = permute(data, [3 2 1 4 5 6 7]); % nT x nTrials x nDims x nGroups x nPartitions x nConditions
                        % data = reshape(data, nT, nTrials, nDims*nGroups, nPartitions, nConditions, nConditionsTest);
                        % stats = spiky.trig.TrigFr(0, 1, data);
                        % stats.Time = t;
                        % stats.Neuron = neurons;
                    % -- Obsolete: class averages as coords
                        % stats = spiky.stat.Subspaces(stats.Time, stats.Data, stats.Groups, stats.GroupIndices, ...
                        %     stats.Partitions, stats.Conditions);
                        % d = reshape(vertcat(d{:}), nT, nGroups, nPartitions, nTrain, nTest);
                        % d = spiky.stat.GroupedStat(obj.Time, d, obj.Groups, obj.GroupIndices, ...
                        %     partitions, conditions, Metric="gain");
                        % varargout{2} = d;
                case "deviance"
                    stats.Data = cell2mat(stats.Data); % dim2 from regions to neurons
                    stats.Groups = (1:width(stats.Data))';
                    stats.GroupIndices = eye(width(stats.Data))==1;
                case "gain"
                    if options.CalcP
                        % z = log(stats.Data);
                        z = (stats.Data>1)*2-1;
                        m = mean(z, 3, "omitmissing");
                        sz = size(z);
                        % sz(3) = 1;
                        sz(6) = options.NShuffle;
                        sz(sz==0) = 1;
                        % randomly flip sign of log gain to create null distribution under no gain
                        flip = randi([0 1], sz)*2-1;
                        zShuf = mean(z.*flip, 3, "omitmissing");
                        p = (1+sum(abs(zShuf)>=abs(m), 6, "omitmissing"))./(1+options.NShuffle); 
                        stats.P = p;
                    end
            end
            varargout{1} = stats;
        end
    end
end