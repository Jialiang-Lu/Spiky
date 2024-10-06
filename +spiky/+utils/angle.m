function a = angle(v1, v2, dim)
% ANGLE Angle between two vectors in degrees.
%
%   v1: vector or matrix of vectors where dim is the dimension of the vectors
%   v2: vector or matrix of vectors where dim is the dimension of the vectors
%   [dim]: dimension of the vectors, default is 1
%
%   a: angle in degrees

arguments
    v1 (:, :) double
    v2 (:, :) double
    dim (1, 1) double = 1
end

if ~all(size(v1)==size(v2))
    error("Vectors must have the same size")
end
if size(v1, dim)==3
    a = atan2d(vecnorm(cross(v1, v2, dim), 2, dim), dot(v1, v2, dim));
else
    a = real(acosd(max(min(dot(v1, v2)/(vecnorm(v1, 2, dim).*vecnorm(v2, 2, dim)), 1), -1)));
end
end

