classdef Sync
    %SYNC Class representing synchronization between two clocks

    properties
        Name (1, 1) string % Name of the synchronization
        Fit (1, 1) cfit % Fit object, also the forward convert function
        Inv (1, 1) % Inverse convert function
        Scale (1, 1) double % Scale factor
        Offset (1, 1) double % Offset in seconds
        Gof (1, 1) struct % Goodness of fit
    end

    methods
        function obj = Sync(name, fit, inv, scale, offset, gof)
            arguments
                name (1, 1) string = ""
                fit (1, 1) cfit = cfit
                inv (1, 1) = @() []
                scale (1, 1) double = 1
                offset (1, 1) double = 0
                gof (1, 1) struct = struct
            end
            obj.Name = name;
            obj.Fit = fit;
            obj.Inv = inv;
            obj.Scale = scale;
            obj.Offset = offset;
            obj.Gof = gof;
        end
   end
end