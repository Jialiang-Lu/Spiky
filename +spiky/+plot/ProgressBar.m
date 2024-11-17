classdef ProgressBar < handle

    properties (SetAccess = private)
        N double
        Message string
        Waitbar matlab.ui.Figure
        StartTime uint64
        Progress double
        DataQueue parallel.pool.DataQueue
        Options struct
    end

    methods
        function obj = ProgressBar(n, message, options)
            %PROGRESSBAR Create a new instance of ProgressBar

            arguments
                n double {mustBePositive, mustBeInteger}
                message string = ""
                options.parallel logical = false
                options.closeOnFinish logical = true
            end

            obj.N = n;
            obj.Message = message;
            obj.StartTime = tic;
            obj.Waitbar = waitbar(0, message);
            obj.Progress = 0;
            obj.Options = options;
            if options.parallel
                obj.DataQueue = parallel.pool.DataQueue;
                afterEach(obj.DataQueue, @obj.updateProgress);
            end
        end

        function add(obj)
            %ADD Update the progress of the progress bar

            if obj.Options.parallel
                send(obj.DataQueue, 0);
            else
                obj.updateProgress([]);
            end
        end

        function delete(obj)
            %DELETE Delete the progress bar

            delete(obj.Waitbar);
            delete(obj.DataQueue);
        end
    end

    methods (Access = private)
        function updateProgress(obj, ~)
            %UPDATEPROGRESS Update the progress of the progress bar

            obj.Progress = obj.Progress + 1;
            t = toc(obj.StartTime);
            tRest = t/obj.Progress*(obj.N-obj.Progress);
            if obj.Progress == obj.N
                if obj.Options.closeOnFinish
                    delete(obj);
                    return
                end
                message = sprintf("%s\nElapsed time %s", obj.Message, duration(0, 0, t));
            else
                message = sprintf("%s\n%s remaining", obj.Message, duration(0, 0, tRest));
            end
            waitbar(obj.Progress/obj.N, obj.Waitbar, message);
        end
    end
end