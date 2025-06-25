function a = angle(v1, v2, dim)
% ANGLE Angle between two vectors in degrees.
%
%   v1: vector or matrix of vectors where dim is the dimension of the vectors
%   v2: vector or matrix of vectors where dim is the dimension of the vectors
%   [dim]: dimension of the vectors, default is 1
%
%   a: angle in degrees

arguments
    v1 double
    v2 double
    dim (1, 1) double = 1
end

if ~isequal(size(v1), size(v2))
    v1 = v1+zeros(size(v2));
    v2 = v2+zeros(size(v1));
end
if size(v1, dim)==3
    a = atan2d(vecnorm(cross(v1, v2, dim), 2, dim), dot(v1, v2, dim));
else
    a = real(acosd(max(min(dot(v1, v2, dim)/(vecnorm(v1, 2, dim).*vecnorm(v2, 2, dim)), 1), -1)));
end
end

