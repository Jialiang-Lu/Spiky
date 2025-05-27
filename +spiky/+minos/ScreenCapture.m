classdef ScreenCapture < spiky.core.Metadata & handle
    %SCREENCAPTURE Class representing a screen capture video

    properties
        Session spiky.ephys.Session
        Path string = ""
        Sync spiky.ephys.EventGroup = spiky.ephys.EventGroup.empty
    end

    properties (Transient)
        Reader %VideoReader
        IsOpen logical = false
        IsValidTime logical = false
    end

    properties (Transient, Hidden)
        CurrentTime_ double = 0
    end

    properties (Dependent)
        CurrentTime double
        Duration double
        FrameRate double
        Width double
        Height double
    end

    methods
        function obj = open(obj)
            %OPEN Open the video file
            %
            %   obj: screen capture object

            if isempty(obj.Path) || obj.Path=="" || ~exist(obj.Path, "file")
                error("Invalid video file path")
            end
            if isempty(obj.Reader) || ~isvalid(obj.Reader)
                obj.Reader = VideoReader(obj.Path);
                obj.IsOpen = true;
            end
        end
        
        function obj = close(obj)
            %CLOSE Close the video file
            %
            %   obj: screen capture object
            
            if isvalid(obj.Reader)
                obj.Reader.close();
                obj.IsOpen = false;
                obj.CurrentTime = 0;
            end
        end

        function frame = getFrame(obj, t)
            %GETFRAME Get a frame at the given time
            %
            %   frame: image at the given time
            %   t: time in seconds

            arguments
                obj
                t double = NaN
            end

            if ~obj.IsOpen
                error("Video file is not open")
            elseif isnan(t)
                if obj.Reader.hasFrame()
                    frame = readFrame(obj.Reader);
                    obj.IsValidTime = true;
                else
                    frame = zeros(obj.Height, obj.Width, 3, "uint8");
                    obj.IsValidTime = false;
                    obj.CurrentTime_ = obj.Reader.Duration;
                end
            else
                obj.CurrentTime = t;
                if obj.IsValidTime
                    frame = readFrame(obj.Reader);
                else
                    frame = zeros(obj.Height, obj.Width, 3, "uint8");
                end
            end
        end

        function t = get.CurrentTime(obj)
            if ~obj.IsOpen
                error("Video file is not open")
            elseif ~obj.IsValidTime
                t = obj.CurrentTime_;
            else
                t = obj.Sync.Sync.Inv(obj.Reader.CurrentTime);
            end
        end

        function set.CurrentTime(obj, t)
            if ~obj.IsOpen
                error("Video file is not open")
            else
                t1 = obj.Sync.Sync.Fit(t);
                if t1<0 || t1>obj.Duration
                    obj.IsValidTime = false;
                    obj.CurrentTime_ = t;
                else
                    obj.IsValidTime = true;
                    obj.Reader.CurrentTime = t1;
                    obj.CurrentTime_ = t;
                end
            end
        end

        function duration = get.Duration(obj)
            if ~obj.IsOpen
                error("Video file is not open")
            else
                duration = obj.Reader.Duration;
            end
        end

        function fr = get.FrameRate(obj)
            if ~obj.IsOpen
                error("Video file is not open")
            else
                fr = obj.Reader.FrameRate;
            end
        end

        function w = get.Width(obj)
            if ~obj.IsOpen
                error("Video file is not open")
            else
                w = obj.Reader.Width;
            end
        end

        function h = get.Height(obj)
            if ~obj.IsOpen
                error("Video file is not open")
            else
                h = obj.Reader.Height;
            end
        end
    end
end