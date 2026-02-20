classdef Coords < spiky.core.Array
    %COORDS Class representing a coordinate system in a N-D space
    %
    % Origin (NDims x 1 vector)
    % Bases (NDims x NBases matrix)

    properties
        Origin (:, 1) double
        BasisNames (:, 1)
    end

    properties (Dependent)
        DimNames (:, 1)
        NDims double
        NBases double
        Bases (:, :)
    end

    properties (Hidden)
        Dims_ (:, 1)
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
            dimLabelNames = {["DimNames"; "Origin"]; "BasisNames"};
        end
    end

    methods
        function obj = Coords(origin, bases, dimNames, basisNames)
            %COORDS Create a new instance of Coords
            %
            %   Coords(origin, bases, ...) creates a new instance of Coords
            %
            %   origin: origin of the coordinate system
            %   bases: basis vectors
            %   dimNames: dimension names or objects
            %   basisNames: names of the basis vectors
            %
            %   obj: Coords object
            arguments
                origin (:, 1) double = double.empty(0, 1)
                bases (:, :, :) double = double.empty(0, 0)
                dimNames (:, 1) = zeros(height(origin), 1)
                basisNames (:, 1) = categorical(NaN(width(bases), 1))
            end
            assert(height(origin)==height(bases), ...
                "The number of rows in bases must be the same as the length of origin");
            assert(height(dimNames)==height(origin), ...
                "The number of rows in dimNames must be the same as the length of origin");
            obj@spiky.core.Array(bases);
            obj.Origin = origin;
            obj.DimNames = dimNames;
            obj.BasisNames = basisNames;
        end

        function [data, proj] = project(obj, data, idcBases, options)
            %PROJECT Project the data onto the coordinate system
            %
            %   data = PROJECT(obj, data)
            %
            %   obj: coordinate system
            %   data: data to project, nDim x nObs
            %   idcBases: indices of the bases to use for projection
            %   Name-value arguments:
            %       Individual: whether to project each basis vector individually
            %
            %   data: projected data, length(idcBases) x nObs
            %   proj: projected data in the original space, nDims x nObs
            arguments
                obj spiky.stat.Coords
                data double
                idcBases double = 1:obj.NBases
                options.Individual logical = false
            end
            assert(height(data)==obj.NDims, ...
                "The number of rows in data must be the same as the number of dimensions in the coordinate system")
            B = obj.Bases(:, idcBases);
            if options.Individual
                data = B'*(data-obj.Origin);
                proj = B*data+obj.Origin;
            else
                data = (B'*B)\(B'*(data-obj.Origin));
                proj = B*data+obj.Origin;
            end
        end

        function data = unproject(obj, data, idcBases)
            %UNPROJECT Unproject the data from the coordinate system
            %
            %   data = UNPROJECT(obj, data)
            %
            %   obj: coordinate system
            %   data: data to unproject, nDataBases x nObs
            %   idcBases: indices of the bases used for projection
            %
            %   data: unprojected data, nDims x nObs
            arguments
                obj spiky.stat.Coords
                data double
                idcBases double = 1:height(data)
            end
            assert(height(data)==numel(idcBases), ...
                "The number of rows in data must be the same as the number of indices in idcBases")
            assert(numel(idcBases)<=obj.NBases, ...
                "The number of indices in idcBases must be less than or equal to the number of bases in the coordinate system")
            B = obj.Bases(:, idcBases);
            data = B*data+obj.Origin;
        end

        function obj = pca(obj, nDims)
            %PCA Reduce the basis dimensions using PCA
            %   obj = PCA(obj, nDims)
            %
            %   obj: Coords object
            %   nDims: number of dimensions to keep
            arguments
                obj spiky.stat.Coords
                nDims double {mustBePositive, mustBeInteger}
            end
            assert(nDims<=obj.NBases, ...
                "nDims must be less than or equal to the number of bases");
            [~, s, v] = svd(obj.Bases, "econ");
            sv = diag(s);
            explained = sv.^2/sum(sv.^2)*100;
            obj.Bases = obj.Bases*v(:, 1:nDims);
            obj.BasisNames = explained(1:nDims);
        end

        function obj = addPCA(obj, data, options)
            %ADDPCA Add PCA basis vectors in the orthogonal complement of the current bases
            %   obj = ADDPCA(obj, data)
            %
            %   obj: Coords object
            %   data: data to compute PCA, nDims x nObs
            %   Name-value arguments:
            %       NAdd: number of PCA basis vectors to add
            arguments
                obj spiky.stat.Coords
                data double
                options.NAdd double = 1
            end
            nDims = height(data);
            bases = orth(obj.Bases);
            nBases = width(bases);
            data = data-obj.Origin;
            data = data-bases*(bases'*data);
            [u, s, v] = svd(data', "econ");
            options.NAdd = min([options.NAdd, nDims-nBases]);
            newBases = v(:, 1:options.NAdd);
            obj.Bases = [obj.Bases, newBases];
            obj.BasisNames = [obj.BasisNames; categorical("PCA"+(1:options.NAdd).')];
        end

        function sim = getSimilarity(obj, other, idcDims, options)
            %GETSIMILARITY Get the similarity between two coordinate systems
            %   sim = GETSIMILARITY(obj, other, idcDims, options)
            %
            %   obj: Coords object
            %   other: another Coords object
            %   idcDims: indices of the bases to use for similarity calculation
            %   Name-value arguments:
            %       Metric: similarity metric ("projection" or "nuclear")
            arguments
                obj spiky.stat.Coords
                other spiky.stat.Coords
                idcDims double = 1:obj.NBases
                options.Metric string {mustBeMember(options.Metric, ["projection" "nuclear"])} = "projection"
            end
            assert(obj.NDims==other.NDims, ...
                "The number of dimensions in the two coordinate systems must be the same");
            assert(obj.NBases==other.NBases, ...
                "The number of bases in the two coordinate systems must be the same");
            B1 = obj.Bases(:, idcDims);
            B2 = other.Bases(:, idcDims);
            [U, S, V] = svd(B1'*B2);
            nDims = numel(idcDims);
            switch options.Metric
                case "projection"
                    sim = sum(diag(S).^2)/nDims;
                case "nuclear"
                    sim = sum(diag(S))/nDims;
            end
        end

        function n = get.NDims(obj)
            n = height(obj.Origin);
        end

        function n = get.NBases(obj)
            n = width(obj.Bases);
        end

        function dimNames = get.DimNames(obj)
            if class(obj)=="spiky.stat.TimeCoords"
                dimNames = obj.Time;
                return
            end
            dimNames = obj.Dims_;
        end

        function obj = set.DimNames(obj, dimNames)
            if class(obj)=="spiky.stat.TimeCoords"
                obj.Time = dimNames;
                return
            end
            assert(height(dimNames)==height(obj.Bases), ...
                "The number of rows in dimNames must be the same as the length of origin");
            obj.Dims_ = dimNames;
        end

        function b = get.Bases(obj)
            b = obj.Data;
        end

        function obj = set.Bases(obj, b)
            obj.Data = b;
        end
    end
end