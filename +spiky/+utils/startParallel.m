function myPool = startParallel(numCores)
% Start a parallel pool if one is not already running
%
%   numCores: number of cores to use

arguments
    numCores (1, 1) {mustBeNumeric, mustBePositive} = maxNumCompThreads
end

myPool1 = gcp("nocreate");
if isempty(myPool1)
    myPool1 = parpool("Threads", numCores);
elseif myPool1.NumWorkers~=numCores || ~isa(myPool1, "parallel.ThreadPool")
    delete(myPool1);
    myPool1 = parpool("Threads", numCores);
end

if nargout==1
    myPool = myPool1;
end

end