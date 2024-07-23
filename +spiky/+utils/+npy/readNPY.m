

function data = readNPY(filename)
% Function to read NPY files into matlab.
% *** Only reads a subset of all possible NPY files, specifically N-D arrays of certain data types.
% See https://github.com/kwikteam/npy-matlab/blob/master/tests/npy.ipynb for
% more.
%
import spiky.utils.npy.*

[shape, dataType, fortranOrder, littleEndian, totalHeaderLength, ~] = readNPYheader(filename);

if littleEndian
    fid = fopen(filename, 'r', 'l');
else
    fid = fopen(filename, 'r', 'b');
end

try

    [~] = fread(fid, totalHeaderLength, 'uint8');

    % read the data
    if strcmp(dataType, 'char*1')
        data = fread(fid, shape(end:-1:1), 'uint8=>uint8')';
        data = cellstr(char(data));
    else
        data = fread(fid, prod(shape), [dataType '=>' dataType]);
    
        if length(shape)>1 && ~fortranOrder
            data = reshape(data, shape(end:-1:1));
            data = permute(data, [length(shape):-1:1]);
        elseif length(shape)>1
            data = reshape(data, shape);
        end
    end

    fclose(fid);

catch me
    fclose(fid);
    rethrow(me);
end
