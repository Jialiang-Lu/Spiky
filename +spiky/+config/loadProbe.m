function probe = loadProbe(probeName)
    % LOADPROBE Load a probe from a file
    %   probe = LOADPROBE(probeName) loads a probe from a file with the name
    %       probeName

    arguments (Input)
        probeName string
    end
    arguments (Output)
        probe spiky.ephys.Probe
    end

    if ~isscalar(probeName)
        probe = arrayfun(@spiky.config.loadProbe, probeName, "UniformOutput", false);
        probe = [probe{:}]';
        return
    end
    s = what("spiky/config/probes");
    probePath = fullfile(s.path, probeName + ".mat");
    fi = spiky.core.FileInfo(probePath);
    if isempty(fi)
        probe = spiky.ephys.Probe.empty;
    else
        probe = spiky.ephys.Probe.load(probePath);
    end
end