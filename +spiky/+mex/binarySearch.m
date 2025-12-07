function index = binarySearch(array, target, left, right)
%BINARYSEARCH Search for a target in a sorted array
% index = binarySearch(array, target, left, right)
%
%   array: 1D sorted array of doubles
%   target: target value
%   [left]: optional left index to start the search
%   [right]: optional right index to end the search
%
%   index: index of the target or the largest value smaller than the target in the array
arguments
    array double {mustBeVector}
    target (1, 1) double
    left (1, 1) double = 1
    right (1, 1) double = length(array)
end
index = spiky.mex.binarySearch_(array, target, left, right);

end