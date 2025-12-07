function varargout = cellfun(func, varargin, options)
%CELLFUN Apply a function to each cell in a cell array and concatenate the output
%   native cellfun only supports concatenation when func returns a scalar, this function supports
%   concatenation when func returns arrays that can be concatenated
%
%   [A1, A2, ...] = CELLFUN(func, C1, C2, ..., Dim=1)
%
%   func: function handle to apply to each cell
%   C1, C2, ...: cell arrays
%   Dim: dimension along which to concatenate the output. if empty, cell2mat is used

arguments
    func 
end
arguments (Repeating)
    varargin
end
arguments
    options.Dim double = []
end
varargout{1:nargout} = cellfun(func, varargin{:}, UniformOutput=false);
for ii = 1:nargout
    if isempty(options.Dim)
        if iscell(varargout{ii}{1})
            for jj = 1:ndims(varargout{ii})
                varargout{ii} = cellfun(@(c) cat(jj, c{:}), num2cell(varargout{ii}, jj), ...
                    UniformOutput=false);
            end
            varargout{ii} = varargout{ii}{1};
        else
            varargout{ii} = cell2mat(varargout{ii});
        end
    else
        varargout{ii} = cat(options.Dim, varargout{ii}{:});
    end
end
