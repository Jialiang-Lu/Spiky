function deleteFiles(fpth)
%DELETEFILES Delete files matching the given file path pattern
%   deleteFiles(fpth)
arguments
    fpth string
end
[fdir, fn, fext] = fileparts(fpth);
delete(fpth);
delete(fullfile(fdir, fn+"_dark"+fext));
delete(fullfile(fdir, fn+"_light"+fext));
end
