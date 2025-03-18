classdef ProgressBar < handle

    properties (SetAccess = private)
        N double
        Message string
        % Waitbar matlab.ui.Figure
        Id double
        StartTime uint64
        Progress double
        DataQueue parallel.pool.DataQueue
        Options struct
    end

    methods (Static)
        function id = nextId()
            %NEXTID Get the next unique id

            persistent id_
            if isempty(id_)
                id_ = 0;
            end
            id_ = id_ + 1;
            id = id_;
        end
    end

    methods
        function obj = ProgressBar(n, message, options)
            %PROGRESSBAR Create a new instance of ProgressBar

            arguments
                n double {mustBePositive, mustBeInteger}
                message string = ""
                options.Parallel logical = false
                options.CloseOnFinish logical = true
            end

            obj.N = n;
            obj.Message = message;
            obj.StartTime = tic;
            % obj.Waitbar = waitbar(0, message);
            f = waitbar(0, message);
            f.UserData = spiky.plot.ProgressBar.nextId();
            obj.Id = f.UserData;
            obj.Progress = 0;
            obj.Options = options;
            if options.Parallel
                obj.DataQueue = parallel.pool.DataQueue;
                afterEach(obj.DataQueue, @obj.updateProgress);
            end
        end

        function step(obj)
            %STEP Update the progress of the progress bar

            if obj.Options.Parallel
                send(obj.DataQueue, 0);
            else
                obj.updateProgress([]);
            end
        end

        function delete(obj)
            %DELETE Delete the progress bar

            % delete(obj.Waitbar);
            if ~parallel.internal.pool.isPoolThreadWorker && isempty(getCurrentJob)
                delete(obj.getWaitbar());
            end
            % delete(obj.DataQueue);
        end

        function h = getWaitbar(obj)
            %GETWAITBAR Get the waitbar handle

            h = findall(groot, Type="Figure", UserData=obj.Id, Tag="TMWWaitbar");
        end
    end

    methods (Access = private)
        function updateProgress(obj, ~)
            %UPDATEPROGRESS Update the progress of the progress bar

            obj.Progress = obj.Progress + 1;
            t = toc(obj.StartTime);
            tRest = t/obj.Progress*(obj.N-obj.Progress);
            % fprintf("%d\n", obj.Progress)
            if obj.Progress == obj.N
                if obj.Options.CloseOnFinish
                    delete(obj.getWaitbar());
                    delete(obj.DataQueue);
                    delete(obj);
                    return
                end
                message = sprintf("%s\nElapsed time %s", obj.Message, duration(0, 0, t));
            else
                message = sprintf("%s\n%s remaining", obj.Message, duration(0, 0, tRest));
            end
            waitbar(obj.Progress/obj.N, obj.getWaitbar(), message);
        end
    end
end