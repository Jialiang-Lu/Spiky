classdef Decoder < spiky.stat.GroupedStat
    %DECODER class for decoder models and related statistics.
    %   Decoder object represents the results of decoder analysis
    %
    %   Properties:
    %       Data: cell array of decoder models for each time point, group, partition, and condition
    %       X: cell array of data, nT x nGroups x 1 x nConditions cell of nNeurons x nTrials
    %       Y: cell array of labels, nConditions x 1 cell of nTrials x 1 categorical
    %       Whiten: nT x nGroups x 1 x nConditions cell of nNeurons x nNeurons whitening matrices
    %       Type: type of decoder

    properties
        X
        Y
        Whiten
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
            dataNames = ["Data" "X" "Whiten"]';
        end

        function [stat, transform, d] = varExplained(mdl, X, y, options)
            arguments
                mdl spiky.stat.Coords
                X double
                y categorical
                options.Type string {mustBeMember(options.Type, ["trace", "max", "pillai", "wilks"])} = "trace"
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 0
                options.Whiten double = []
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
            if ~isempty(options.Whiten)
                X = options.Whiten\X; % whiten the data by the Mahalanobis weights
                XHat = options.Whiten\XHat; % whiten the predicted response
                basesUsed = options.Whiten\mdl.Bases; % whiten the decoder bases
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
                options.Type string {mustBeMember(options.Type, ["nse" "r2" "varRatio" "cosine" "rdm" "corr"])} = "varRatio"
                options.Whiten logical = false
                options.AllowRotation logical = true
                options.AllowScaling logical = false
                options.AllowReflection logical = false
                options.AllowTranslation logical = true
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 1e-6
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
            stat = NaN(nCats, 1);
            transform = cell(nCats, 1);
            d = NaN(nCats, 1);
            for ii = 1:nCats
                idcOthers = setdiff(1:nCats, ii);
                idcTrialOthers = ismember(idcY, idcOthers);
                XThis = X(:, idcY==ii); % nNeurons x nTrials in this class
                if options.Whiten
                    XOther = X(:, idcTrialOthers); % nNeurons x nTrials in other classes
                    resOther = XOther-mTest(:, idcY(idcTrialOthers)); % nNeurons x nTrials residuals for other classes
                    WOther = resOther*resOther'/(width(XOther)-nCats+1); % nNeurons x nNeurons covariance of other classes
                    WOther = WOther + options.RidgeFraction*trace(WOther)/width(WOther)*eye(size(WOther)); 
                        % add ridge regularization
                    W = chol(WOther, "lower"); % nNeurons x nNeurons whitening matrix based on other classes
                    mwTrain = W\mTrain; % nNeurons x nCats whitened class means in training data
                    mwTest = W\mTest; % nNeurons x nCats whitened class means in test data
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
                %%
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
                        [~, ~, tr] = procrustes(DTest', DTrain', ...
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
                %%
                transform{ii} = tr;
                mcTestPred = tr.b.*tr.T'*mcTrainThis+tr.c'; % nNeurons x 1 predicted class mean for this class in test data
                mTestPred = mcTestPred+muTestOther; % nNeurons x 1 predicted class mean for this class in test data
                switch options.Type
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
    end

    methods
        function obj = Decoder(time, data, x, y, ...
                groups, groupIndices, partitions, conditions, weights, options)
            %DECODER Create a new instance of Decoder
            arguments
                time double = []
                data = []
                x cell = {}
                y cell = {}
                groups (:, 1) = NaN(width(data), 1)
                groupIndices = logical.empty(height(groups), 0)
                partitions (:, 1) = cell(size(data, 4), 1)
                conditions (:, 1) = categorical(strings(size(data, 4), 1))
                weights cell = cell(size(data))
                options.Type (1, 1) string = "mean"
            end
            obj@spiky.stat.GroupedStat(time, data, groups, groupIndices, partitions, conditions)
            obj.X = x;
            obj.Y = y;
            obj.Whiten = weights;
            obj.Type_ = options.Type;
        end

        function type = get.Type(obj)
            type = obj.Type_;
        end

        function varargout = getStats(obj, options)
            %GETSTATS Get statistics related to the decoder models.
            %   [stats, ...] = GETSTATS(obj, options)
            %
            %   obj: Decoder object
            %   Name-value arguments:
            %       Metric: metric to calculate
            %           "varExplained": variance explained by the decoder model (default)
            %           "procrustes": variance explained under procrustes alignment
            %           "accuracy": classification accuracy of the decoder model
            %           "confusion": confusion matrix of the decoder model
            %       CrossTime: whether to perform cross-time decoding (default: false)
            %       CrossCondition: whether to perform cross-condition decoding (default: false)
            %       VarType: type of variance explained metric (default: "trace")
            %       RidgeFraction: fraction of ridge regularization to apply when calculating variance explained (default: 0)
            %
            %   stats: GroupedStat object containing the calculated statistics
            %   ...: additional output arguments containing relevant info for the calculated statistics
            %       [stats, transforms, d] = getStats(..., Metric="procrustes")
            %           returns the Procrustes transformation structs for each decoder model
            arguments
                obj spiky.stat.Decoder
                options.Metric (1, 1) string {mustBeMember(options.Metric, ...
                    ["varExplained" "procrustes" "accuracy" "confusion"])} = "varExplained"
                options.Whiten logical = false
                options.UseTrainWhiten logical = false
                options.CrossTime logical = false
                options.CrossCondition logical = false
                options.VarType string {mustBeMember(options.VarType, ["trace", "max", "pillai", "wilks"])} = "trace"
                options.ProcrustesType string {mustBeMember(options.ProcrustesType, ...
                    ["nse" "r2" "varRatio" "cosine" "rdm" "corr"])} = "varRatio"
                options.RidgeFraction (1, 1) double {mustBeNonnegative} = 1e-6
                options.AllowRotation logical = true
                options.AllowScaling logical = false
                options.AllowReflection logical = false
                options.AllowTranslation logical = true
                options.Shuffle logical = false
            end
            chance = NaN;
            switch options.Metric
                case "varExplained"
                    assert(obj.Type=="mean")
                    chance = 0;
                case "accuracy"
                    assert(obj.Type=="svm")
                    chance = 1/numel(obj.Data{1}.ClassNames);
            end
            nT = height(obj.Data);
            nGroups = width(obj.Data);
            nPartitions = size(obj.Data, 3);
            nConditions = size(obj.Data, 4);
            if options.CrossTime
                assert(nConditions==2, ...
                    "Cross-time decoding is only implemented for 2 conditions")
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
            if options.Metric=="procrustes"
                transforms = cell(nT, nGroups, nPartitions, nTrain);
                d = cell(nT, nGroups, nPartitions, nTrain);
            end
            mdls = obj.Data; % nT x nGroups x nPartitions x nConditions cell of decoder models
            if options.CrossTime
                mdls = mdls(:, :, :, 1); % use the first condition's models for cross-time decoding
            end
            X = obj.X; % nT x nGroups x 1 x nConditions cell of nNeurons x nTrials
            y = obj.Y; % nConditions x 1 cell of nTrials x 1 categorical
            weights = obj.Whiten; % nT x nGroups x 1 x nConditions cell of nNeurons x nNeurons whitening matrices
            partitions = obj.Partitions; % nConditions x 1 cell of partition labels
            n = nT*nGroups*nPartitions*nTrain;
            sz = [nT, nGroups, nPartitions, nTrain];
            pb = spiky.plot.ProgressBar(n, "Calculating statistics "+options.Metric);
            parfor ii = 1:n
                [idxT, idxG, idxP, idxC] = ind2sub(sz, ii);
                mdl = mdls{ii};
                stat1 = NaN(1, 1, 1, 1, nTest);
                if options.Metric=="confusion"
                    stat1 = cell(1, nTest);
                end
                if options.Metric=="procrustes"
                    transform1 = cell(1, nTest);
                    d1 = NaN(1, nTest);
                end
                for jj = 1:nTest
                    if options.CrossTime
                        idxT = jj; % use model from time jj for testing
                        idxC = 2; % use condition 2 for testing in cross-time decoding
                    elseif options.CrossCondition
                        idxC = jj; % use condition jj for testing
                    end
                    idcPTest = partitions{idxC}(idxP, :); % indices of trials in test partition
                    XTest = X{idxT, idxG, 1, idxC}(:, idcPTest); % nNeurons x nTrials
                    yTest = y{idxC}(idcPTest); % nTrials x 1 categorical
                    switch options.Metric
                        case "varExplained"
                            if options.Whiten
                                W = weights{idxT, idxG, 1, idxC}; % nNeurons x nNeurons whitening matrix
                            else
                                W = [];
                            end
                            stat1(jj) = spiky.stat.Decoder.varExplained(mdl, XTest, yTest, ...
                                Type=options.VarType, RidgeFraction=options.RidgeFraction, ...
                                Whiten=W);
                        case "procrustes"
                            if options.Shuffle
                                [~, ~, idcY] = unique(yTest);
                                nCats = numel(idcY);
                                idcCats = randperm(nCats)';
                                yTest = yTest(idcCats(idcY)); % shuffle class labels in test data
                            end
                            [stat1(jj), transform1{jj}, d1(jj)] = spiky.stat.Decoder.procrustes(mdl, XTest, yTest, ...
                                Type=options.ProcrustesType, ...
                                Whiten=options.Whiten, ...
                                AllowRotation=options.AllowRotation, ...
                                AllowScaling=options.AllowScaling, ...
                                AllowReflection=options.AllowReflection, ...
                                AllowTranslation=options.AllowTranslation, ...
                                RidgeFraction=options.RidgeFraction);
                        case "accuracy"
                            if isa(mdl, "classreg.learning.classif.CompactClassificationECOC") || ...
                                isa(mdl, "classreg.learning.classif.ClassificationECOC")
                                XTest = XTest';
                            end
                            yPred = mdl.predict(XTest);
                            stat = groupsummary(yPred==yTest, yTest, "mean"); % accuracy for each class
                            stat1(jj) = mean(stat); % overall accuracy
                        case "confusion"
                            if isa(mdl, "classreg.learning.classif.CompactClassificationECOC") || ...
                                isa(mdl, "classreg.learning.classif.ClassificationECOC")
                                XTest = XTest';
                            end
                            yPred = mdl.predict(XTest);
                            cats = mdl.ClassNames;
                            c = confusionmat(yTest, yPred, Order=cats);
                            c = c./sum(c, 2); % normalize by true class counts to get conditional probabilities
                            stat1{jj} = c; % confusion matrix for this test condition
                    end
                end
                stats{ii} = stat1;
                if options.Metric=="procrustes"
                    transforms{ii} = transform1;
                    d{ii} = d1;
                end
                pb.step
            end
            if options.Metric=="confusion"
                stats = reshape(vertcat(stats{:}), nT, nGroups, nPartitions, nTrain, nTest);
            else
                stats = cell2mat(stats); % nT x nGroups x nPartitions x nTrain x nTest
            end
            if options.CrossTime
                partitions = repmat(obj.Partitions(1), nT, 1);
                conditions = obj.Time;
                stats = permute(stats, [1 2 3 5 4]); % nT x nGroups x nPartitions x nTest
            else
                partitions = obj.Partitions;
                conditions = obj.Conditions;
            end
            stats = spiky.stat.GroupedStat(obj.Time, stats, obj.Groups, obj.GroupIndices, ...
                partitions, conditions, Metric=options.Metric, Chance=chance);
            varargout{1} = stats;
            if options.Metric=="procrustes"
                transforms = reshape(vertcat(transforms{:}), nT, nGroups, nPartitions, nTrain, nTest);
                % transforms = cell2mat(transforms);
                transforms = spiky.stat.GroupedStat(obj.Time, transforms, obj.Groups, obj.GroupIndices, ...
                    partitions, conditions, Metric="procrustesTransform");
                d = reshape(vertcat(d{:}), nT, nGroups, nPartitions, nTrain, nTest);
                d = spiky.stat.GroupedStat(obj.Time, d, obj.Groups, obj.GroupIndices, ...
                    partitions, conditions, Metric="rotationMetric");
                varargout{2} = transforms;
                varargout{3} = d;
            end
        end
    end
end