function config = loadConfig(fieldName)
%LOADCONFIG Load the Config.yaml file.

configPath = fullfile(fileparts(mfilename("fullpath")), "Config.yaml");
configFile = fileread(configPath);
config = spiky.utils.yaml.load(configFile);
if nargin > 0
    if isfield(config, fieldName)
        config = config.(fieldName);
    else
        error("Field '%s' does not exist in the config.", fieldName);
    end
end
