

function [data, mapShape] = memmapNPY(filename)
import spiky.utils.npy.*
% Function to memmap NPY files into matlab.
[arrayShape, dataType, fortranOrder, littleEndian, totalHeaderLength] = ...
    readNPYheader(filename);
if fortranOrder
    mapShape = arrayShape;
else
    mapShape = arrayShape(end:-1:1);
end
data = memmapfile(filename, 'Format', {dataType, mapShape, 'm'}, 'Offset', totalHeaderLength);
