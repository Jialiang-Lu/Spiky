classdef ProgressBar < handle

    properties (SetAccess = private)
        N double
        Valid logical = false
        Message string
        Id string
        StartTime uint64
        Progress double
        DataQueue parallel.pool.DataQueue
        Options struct
    end

    properties (Dependent)
        Waitbar
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
                options.Visible logical = true
                options.CloseOnFinish logical = true
            end

            obj.N = n;
            obj.Message = message;
            obj.StartTime = tic;
            obj.Progress = 0;
            obj.Options = options;
            if ~options.Visible || parallel.internal.pool.isPoolThreadWorker || ~isempty(getCurrentJob)
                return
            end
            f = waitbar(0, message, Color = [0.11 0.11 0.11], HandleVisibility="off", ...
                Tag=string(spiky.plot.ProgressBar.nextId()), UserData=obj, DeleteFcn=@(~, ~) delete(obj));
            % obj.Id = f.Tag;
            obj.DataQueue = parallel.pool.DataQueue;
            afterEach(obj.DataQueue, @obj.updateProgress);
            obj.Valid = true;
        end

        function waitbar = get.Waitbar(obj)
            %GET.WAITBAR Get the waitbar handle
            if ~obj.Valid
                waitbar = [];
                return
            end
            waitbar = findall(groot, Type="Figure", UserData=obj);
        end

        function step(obj)
            %STEP Update the progress of the progress bar
            if ~obj.Valid
                return
            end
            send(obj.DataQueue, 0);
        end

        function delete(obj)
            %DELETE Delete the progress bar
            if ~parallel.internal.pool.isPoolThreadWorker && isempty(getCurrentJob)
                delete(obj.Waitbar);
            end
            if ~isempty(obj.DataQueue) && isvalid(obj.DataQueue)
                send(obj.DataQueue, 1);
                delete(obj.DataQueue);
            end
        end
    end

    methods (Access = private)
        function updateProgress(obj, flag)
            %UPDATEPROGRESS Update the progress of the progress bar
            if ~obj.Valid
                return
            end
            obj.Progress = obj.Progress + 1;
            t = toc(obj.StartTime);
            tRest = t/obj.Progress*(obj.N-obj.Progress);
            % fprintf("%d\n", obj.Progress)
            if obj.Progress==obj.N || flag==1
                if obj.Options.CloseOnFinish
                    delete(obj.Waitbar);
                    delete(obj.DataQueue);
                    delete(obj);
                    return
                end
                message = sprintf("%s\nElapsed time %s", obj.Message, duration(0, 0, t));
            else
                message = sprintf("%s\n%s remaining", obj.Message, duration(0, 0, tRest));
            end
            h = obj.Waitbar;
            waitbar(obj.Progress/obj.N, h, message);
        end
    end
end