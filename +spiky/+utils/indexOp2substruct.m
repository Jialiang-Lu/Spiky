function s = indexOp2substruct(indexOp)
% INDEXOP2SUBSTRUCT Convert index operation to substruct

n = length(indexOp);
c = cell(1, 2*n);
for ii = 1:n
    switch indexOp(ii).Type
        case "Paren"
            c{2*ii-1} = '()';
            c{2*ii} = indexOp(ii).Indices;
        case "Brace"
            c{2*ii-1} = '{}';
            c{2*ii} = indexOp(ii).Indices;
        case "Dot"
            c{2*ii-1} = '.';
            c{2*ii} = indexOp(ii).Name{1};
    end
end
s = substruct(c{:});
end