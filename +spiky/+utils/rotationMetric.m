function r = rotationMetric(T)
%ROTATIONMETRIC Normalized geodesic "rotation amount" in [0, 1].
%   r = rotationMetric(T)
%
%   T: transformation matrix to evaluate, n x n
%   r: rotation metric in [0, 1], where 0 means no rotation and 1 means the maximum possible rotation
%       (180 degree rotation in each of the k = floor(n/2) independent planes)

arguments
    T (:, :) double
end

n = height(T);
if width(T)~=n
    error("T must be a square matrix");
end
if n<2
    r = 0;
    return
end
% Project to nearest orthogonal matrix, then enforce det = +1 (proper rotation)
[U, ~, V] = svd(T);
R = U*V';
if det(R)<0
    U(:, end) = -U(:, end);
    R = U*V';
end
% Geodesic distance on SO(n): ||logm(R)||_F
A = logm(R);
% Numerical cleanup: logm(R) should be skew-symmetric for a true rotation
A = (A-A')/2;
geoDist = norm(A, "fro");
% Normalize to [0, 1]
k = floor(n/2);
maxGeoDist = pi*sqrt(2*k);
if maxGeoDist>0
    r = geoDist/maxGeoDist;
    r = min(max(r, 0), 1); % ensure r is in [0, 1] even with numerical errors
else
    r = 0;
end
