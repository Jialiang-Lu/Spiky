classdef Kilosort4
    properties
        fdir string
        fpthProbe string
    end

    methods
        function obj = Kilosort4(fdir, fpthProbe)
            % Kilosort4 creates a new instance of Kilosort4.

            arguments
                fdir string {mustBeFolder}
                fpthProbe string {mustBeFile}
            end

            obj.fdir = fdir;
            obj.fpthProbe = fpthProbe;
        end

        function run(obj)
            % RUN Run Kilosort4 on the specified data
            fdirConda = spiky.config.loadConfig("fdirConda");
            fpthKilosort4 = spiky.config.loadConfig("fpthKilosort4");
            envKilosort4 = spiky.config.loadConfig("envKilosort4");
            status = system(fdirConda+"\Scripts\activate.bat "+fdirConda+...
                cmdsep+"conda activate "+envKilosort4+cmdsep+"python "+fpthKilosort4+" "+...
                obj.fdir+" "+obj.fpthProbe, "-echo");
            if status==0
                disp("Kilosort4 completed successfully.")
            else
                error("Kilosort4 failed.")
            end
        end
    end
end