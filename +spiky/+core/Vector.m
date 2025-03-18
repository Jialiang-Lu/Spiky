classdef Vector
    methods (Static)
        function a = angle(v1, v2, dim)
            %ANGLE Compute the angle between two vectors
            %
            %   a = ANGLE(v1, v2, dim)
            %
            %   v1: first vector
            %   v2: second vector
            %   dim: dimension along which to compute the angle
            %
            %   a: angle between the two vectors in degrees
            arguments
                v1
                v2
                dim (1, 1) double = 1
            end
            if size(v1, dim) ~= size(v2, dim)
                error("Vectors must have the same length")
            end
            if numel(v2)>numel(v1)
                v1 = v1.*ones(size(v2), class(v1));
            elseif numel(v1)>numel(v2)
                v2 = v2.*ones(size(v1), class(v2));
            end
            a = acosd(dot(v1, v2, dim)./(vecnorm(v1, 2, dim).*vecnorm(v2, 2, dim)));
        end

        function a = planeAngle(p1, p2)
            %PLANEANGLE Compute the angle between two (hyper)planes
            %
            %   a = PLANEANGLE(p1, p2)
            %
            %   p1: n*m matrix of n-d vectors spanning the first m-d (hyper)plane
            %   p2: n*m matrix of n-d vectors spanning the second m-d (hyper)plane
            %
            %   a: angle between the two planes in degrees
            arguments
                p1 (:, :) double
                p2 (:, :) double
            end
            if size(p1, 1)~=size(p2, 1)
                error("The number of points must be the same")
            end
            % n1 = null(p1');
            % n1 = n1(:, 1);
            % n2 = null(p2');
            % n2 = n2(:, 1);
            % a = spiky.core.Vector.angle(n1, n2);
            % w = min(size(p1, 2), size(p2, 2));
            [~, s] = svd(p1'*p2);
            a = mean(acosd(diag(s)));
        end
    end
end