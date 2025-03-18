function c = nanconv(a, k, options)
    % NANCONV Convolution in 1D or 2D ignoring NaNs.
    %   C = NANCONV(A, K) convolves A and K, correcting for any NaN values
    %   in the input matrix A. The result is the same size as A.
    %
    %   C = NANCONV(A, K, options) specifies the following name-value pairs:
    %     Shape           - (string) Convolution shape: "same" (default), "full", or "valid".
    %     EdgeCorrection  - (logical) Apply edge correction to the output (default: true).
    %     NaNOutput       - (logical) Include NaNs in the output where they exist in A (default: false).
    %     TreatAs1D       - (logical) Treat inputs as 1D vectors if applicable (default: false).
    %
    % See also conv, convn
    
    arguments
        a {mustBeNumeric}
        k {mustBeNumeric}
        options.Shape (1,1) string = "same"
        options.EdgeCorrection (1,1) logical = false
        options.NaNOutput (1,1) logical = false
        options.TreatAs1D (1,1) logical = false
    end
    
    % Validate Shape input
    validShapes = ["same", "full", "valid"];
    if ~any(options.Shape == validShapes)
        error("%s:InvalidShape", mfilename, "Shape '%s' not implemented", options.Shape);
    end
    
    % Get the size of 'a'
    sza = size(a);
    
    % If TreatAs1D is true, convert vectors to column format
    if options.TreatAs1D
        if ~isvector(a) || ~isvector(k)
            error("MATLAB:conv:AorBNotVector", "A and B must be vectors.");
        end
        a = a(:); k = k(:);
    end
    
    % Create matrices for comparison
    o = ones(size(a));
    on = ones(size(a));
    
    % Identify NaN locations
    n = isnan(a);
    
    % Replace NaNs with zeros in 'a' and 'on'
    a(n) = 0;
    on(n) = 0;
    
    % Check for NaNs in the filter
    if any(isnan(k), "all")
        error("%s:NaNinFilter", mfilename, "Filter (k) contains NaN values.");
    end
    
    % Compute 'flat' function after convolution
    if any(n(:)) || options.EdgeCorrection
        flat = convn(on, k, options.Shape);
    else
        flat = o;
    end
    
    % Adjust for edge effects if needed
    if any(n(:)) && ~options.EdgeCorrection
        flat = flat ./ convn(o, k, options.Shape);
    end
    
    % Perform convolution
    c = convn(a, k, options.Shape) ./ flat;
    
    % Restore NaN locations if requested
    if options.NaNOutput
        c(n) = NaN;
    end
    
    % Convert back to original shape if TreatAs1D is enabled
    if options.TreatAs1D && sza(1) == 1
        c = c.';
    end
    
end
    