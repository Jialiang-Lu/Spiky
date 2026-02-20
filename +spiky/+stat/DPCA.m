classdef DPCA < spiky.stat.Subspaces
    %DPCA Demixed Principal Component Analysis
    %   DPCA object represents the results of dPCA analysis, including decoder/encoder matrices, 
    %   explained variance, and other related information.
    %   
    %   Properties:
    %       Decoder: Decoder matrices (W)
    %       Encoder: Encoder matrices (V)
    %       Stats: Statistics related to dPCA
    %           TotalVar: Total variance of the data
    %           TotalMargVar: Total marginalized variance for each marginalization
    %           ComponentVar: Variance explained by each component
    %           MargVar: Variance explained by each component for each marginalization
    %           CumulativePCA: Cumulative explained variance by PCA components
    %           CumulativeDPCA: Cumulative explained variance by dPCA components

    properties (Dependent)
        Decoder cell % Decoder matrices (W)
        NComponents double % Number of components
    end

    properties
        Encoder cell % Encoder matrices (V)
        Stats struct % Statistics related to dPCA
        MargNames (:, 1) string % Names of marginalizations
    end

    methods
        function obj = DPCA(decoder, encoder, stats, margNames, groups, groupIndices)
            %DPCA Create a new instance of DPCA
            arguments
                decoder cell % cell array of decoder matrices
                encoder cell % cell array of encoder matrices
                stats struct % struct array of statistics
                margNames (:, 1) string % names of marginalizations
                groups (:, 1) = NaN(width(decoder), 1)
                groupIndices cell = cell(height(groups), 1)
            end
            assert(isequal(size(decoder), size(encoder), size(stats)), ...
                "Decoder, Encoder, and Stats must have the same size.");
            obj@spiky.stat.Subspaces(0, decoder, groups, groupIndices);
            obj.Encoder = encoder;
            obj.Stats = stats;
            obj.MargNames = margNames;
        end

        function decoder = get.Decoder(obj)
            decoder = obj.Data;
        end

        function obj = set.Decoder(obj, decoder)
            obj.Data = decoder;
        end

        function n = get.NComponents(obj)
            n = obj.Decoder{1}.NBases;
        end

        function data = project(obj, data, name, idcDim, options)
            %PROJECT Project the data onto the dPCA components for the specified marginalization.
            %   data = PROJECT(obj, data, name, idcDim)
            %
            %   obj: DPCA object
            %   data: data to be projected (e.g., trigFr)
            %   idcDim: indices of the dPCA components to project onto
            %   Name-value options:
            %       Name: name of the marginalization to project onto (must be in MargNames)
            %       Individual: whether to project each component individually (default: false)
            arguments
                obj spiky.stat.DPCA
                data
                name string
                idcDim (1, :) double = 1:obj.NComponents
                options.Name string = obj.MargNames
                options.Individual logical = false
            end
            assert(all(ismember(options.Name, obj.MargNames)), ...
                "All specified names must be present in MargNames.");
            obj.Data = cellfun(@(coords) coords(:, ismember(coords.BasisNames, options.Name)), obj.Decoder, ...
                UniformOutput=false);
            data = project@spiky.stat.Subspaces(obj, data, idcDim, Individual=options.Individual);
        end

        function ss = getSubspaces(obj, name, idcDim)
            %GETSUBSPACES Get the subspaces corresponding to the specified marginalization and components.
            %   ss = GETSUBSPACES(obj, name, idcDim)
            %
            %   obj: DPCA object
            %   name: name of the marginalization to get subspaces for
            %   idcDim: indices of the dPCA components to include in the subspace
            arguments
                obj spiky.stat.DPCA
                name string
                idcDim (1, :) double = 1:2
            end
            assert(ismember(name, obj.MargNames), ...
                "Specified name must be present in MargNames.");
            data = cellfun(@(coords) coords(:, ismember(coords.BasisNames, name)), obj.Decoder, ...
                UniformOutput=false);
            data = cellfun(@(d) d(:, idcDim), data, UniformOutput=false);
            ss = spiky.stat.Subspaces(0, data, obj.Groups, obj.GroupIndices);
        end

        function ss = pca(obj, name, nDims)
            %PCA Perform PCA on the data to get the top nDims principal components 
            % for the specified marginalization.
            %   ss = PCA(obj, name, nDims)
            %
            %   obj: DPCA object
            %   name: name of the marginalization to perform PCA on
            %   nDims: number of principal components to return
            arguments
                obj spiky.stat.DPCA
                name string
                nDims (1, 1) double
            end
            assert(ismember(name, obj.MargNames), ...
                "Marginalization '%s' not found in MargNames.", name);
            data = cell(size(obj.Data));
            for ii = 1:numel(obj.Data)
                idcMarg = find(obj.Decoder{ii}.BasisNames==name);
                assert(numel(idcMarg)>=nDims, ...
                    "Number of dimensions requested exceeds the number of components");
                data{ii} = obj.Decoder{ii}(:, idcMarg).pca(nDims);
            end
            ss = spiky.stat.Subspaces(0, data, obj.Groups, obj.GroupIndices);
        end

        function plotSummary(obj, trigFr, vars, options)
            arguments
                obj spiky.stat.DPCA
                trigFr spiky.trig.TrigFr
                vars table % event labels
                options.NDims (1, 1) double = 10
                options.NDimsPerVar (1, 1) double = 3
            end

            %% Prepare data
            assert(all(ismember(vars.Properties.VariableNames, obj.MargNames)), ...
                "All variable names in vars must be present in the basis names of the decoder.");
            nVars = numel(obj.MargNames);
            proj = obj.project(trigFr, 1:options.NDims, Individual=true);
            
            %% Plot summary
            for ii = 1:obj.NGroups
                figure
                tiledlayout(nVars, options.NDimsPerVar+1)
                %% Bar plot of explained variance by components
                nexttile(1)
                bar(obj.Stats(ii).MargVar(:, 1:options.NDims)', "stacked")
                legend(obj.MargNames, Location="northeast")
                ylabel("Explained Variance (%)")
                xticks(1:options.NDims)
                xticklabels(obj.Decoder{ii}.BasisNames(1:options.NDims))
                xtickangle(45)
                %% Plot components for each variable
                for jj = 1:nVars
                    idcVar = find(obj.Decoder{ii}.BasisNames==obj.MargNames(jj));
                    if numel(idcVar)==0
                        continue
                    elseif numel(idcVar)>options.NDimsPerVar
                        idcVar = idcVar(1:options.NDimsPerVar);
                    end
                    if obj.MargNames(jj)~="Time"
                        var1 = categorical(vars.(obj.MargNames(jj)));
                    else
                        var1 = categorical(ones(height(vars), 1));
                    end
                    for kk = 1:numel(idcVar)
                        idxComp = idcVar(kk);
                        nexttile(kk+1+(jj-1)*(options.NDimsPerVar+1))
                        idxProj = (ii-1)*obj.NComponents+idxComp;
                        proj1 = proj(:, :, idxProj);
                        proj1.plotFr(var1, FaceAlpha=0.3);
                        ylabel("")
                        xlabel("")
                        title(sprintf("#%d - %s (%.1f%%)", idxComp, obj.MargNames(jj), ...
                            obj.Stats(ii).ComponentVar(idxComp)))
                        if kk~=numel(idcVar)
                            legend off
                        end
                    end
                end
                sgtitle(obj.Groups(ii))
                spiky.plot.fixfig
            end
        end
    end
end