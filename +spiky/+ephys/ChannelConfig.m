classdef ChannelConfig < spiky.core.Metadata
    % CHANNELCONFIG Class representing a configuration of non-neural channels

    properties
        Aux (:, 1) string
        Adc (:, 1) string
        Dig (:, 1) string
    end

    methods (Static)
        function obj = read(configStruct)
            % READ Convert struct to ChannelConfig object
            arguments
                configStruct struct
            end
            aux = string(configStruct.aux);
            adc = string(configStruct.adc);
            dig = string(configStruct.dig);
            obj = spiky.ephys.ChannelConfig(aux(:), adc(:), dig(:));
        end
    end

    methods
        function obj = ChannelConfig(aux, adc, dig)
            % CHANNELCONFIG Constructor for ChannelConfig class
            arguments
                aux string
                adc string
                dig string
            end
            obj.Aux = aux;
            obj.Adc = adc;
            obj.Dig = dig;
        end
    end
end