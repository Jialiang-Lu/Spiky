function B = imgaussfilt(A, sigma, options)
    % IMGAUSSFILT Applies Gaussian filtering to an image, handling NaNs.
    %
    %   B = imgaussfilt(A, sigma) filters image A using a Gaussian
    %   kernel with standard deviation sigma, preserving NaN handling.
    %
    %   B = imgaussfilt(A, sigma, "FilterSize", FS) specifies the filter size.
    %   B = imgaussfilt(A, sigma, "Padding", P) sets the padding method.
    %
    %   Name-Value pairs:
    %     - FilterSize: Size of the Gaussian filter (default: auto based on sigma)
    %     - Padding: Padding method, one of ("replicate", "symmetric", "circular", "constant")
    %       Default: 'replicate'
    
    arguments
        A double % Input image
        sigma double {mustBePositive} % Standard deviation of the Gaussian filter
        options.FilterSize double {mustBeInteger, mustBePositive} = 2*ceil(2*sigma)+1
        options.Padding string {mustBeMember(options.Padding, ["replicate", "symmetric", "circular", "constant"])} = "replicate"
    end
    
    % Generate the Gaussian kernel
    if isscalar(sigma)
        sigma = [sigma sigma];
    end
    if isscalar(options.FilterSize)
        options.FilterSize = [options.FilterSize options.FilterSize];
    end
    h = images.internal.createGaussianKernel(sigma, options.FilterSize);
    
    % Handle padding
    switch options.Padding
        case "replicate"
            A_padded = padarray(A, floor(options.FilterSize/2), 'replicate', 'both');
        case "symmetric"
            A_padded = padarray(A, floor(options.FilterSize/2), 'symmetric', 'both');
        case "circular"
            A_padded = padarray(A, floor(options.FilterSize/2), 'circular', 'both');
        otherwise
            A_padded = padarray(A, floor(options.FilterSize/2), NaN, 'both');
    end
    
    % Perform convolution with NaN-aware handling
    B_padded = spiky.utils.nanconv(A_padded, h);
    
    % Crop back to original size
    B = B_padded(ceil(options.FilterSize(1)/2):end-floor(options.FilterSize(1)/2), ...
                 ceil(options.FilterSize(2)/2):end-floor(options.FilterSize(2)/2), :);
    
    end
    