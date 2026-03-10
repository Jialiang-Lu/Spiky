function r = rotationMetric(T, options)
%ROTATIONMETRIC Normalized geodesic "rotation amount" in [0, 1].
%   r = rotationMetric(T)
%
%   T: transformation matrix to evaluate, n x n
%   r: rotation metric in [0, 1], where 0 means no rotation and 1 means the maximum possible rotation
%       or angle in degrees if options.Angle is true

arguments
    T (:, :) double
    options.Angle logical = true % if true, return angle in degrees instead of normalized metric
end

n = height(T);
if width(T) ~= n
    error("T must be square.");
end

if n < 2
    r = 0;
    return
end

%% Project to nearest proper rotation R in SO(n)
[u, ~, v] = svd(T, "econ");
R = u*v';
if det(R) < 0
    u(:, end) = -u(:, end);
    R = u*v';
end

%% Angle mode (degrees)
if options.Angle
    if n == 2
        theta = atan2(R(2, 1), R(1, 1)); % (-pi, pi]
        theta = abs(theta);
        theta = mod(theta, 2*pi);
        if theta > pi
            theta = 2*pi-theta;
        end
    elseif n == 3
        x = (trace(R)-1)/2;
        x = min(max(x, -1), 1);
        theta = acos(x); % [0, pi]
    else
        A = logm(R);
        if max(abs(imag(A(:)))) < 1e-10
            A = real(A);
        end
        A = 0.5*(A-A'); % enforce skew-symmetry
        theta = norm(A, "fro")/sqrt(2); % aggregate L2 angle (radians)
    end

    r = theta*(180/pi);
    return
end

%% Normalized geodesic rotation metric in [0, 1]
if n == 2
    theta = atan2(R(2, 1), R(1, 1));
    theta = abs(theta);
    theta = mod(theta, 2*pi);
    if theta > pi
        theta = 2*pi-theta;
    end
    r = theta/pi;
    return
elseif n == 3
    x = (trace(R)-1)/2;
    x = min(max(x, -1), 1);
    theta = acos(x);
    r = theta/pi;
    return
end

A = logm(R);
if max(abs(imag(A(:)))) < 1e-10
    A = real(A);
end
A = 0.5*(A-A'); % enforce skew-symmetry
geoDist = norm(A, "fro");

k = floor(n/2);
maxGeoDist = pi*sqrt(2*k);

if maxGeoDist == 0
    r = 0;
else
    r = geoDist/maxGeoDist;
end

r = min(max(r, 0), 1);
