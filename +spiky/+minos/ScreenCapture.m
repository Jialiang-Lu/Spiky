classdef ScreenCapture < spiky.core.Metadata & handle
    %SCREENCAPTURE Class representing a screen capture video

    properties
        Session spiky.ephys.Session
        Path string = ""
        Sync spiky.ephys.EventGroup = spiky.ephys.EventGroup
    end

    properties (Transient)
        Reader %VideoReader
        IsOpen logical = false
        IsValidTime logical = false
        Frame
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
            obj.Frame = zeros(obj.Height, obj.Width, 3, "uint8");
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
                    frame = obj.Frame;
                    obj.IsValidTime = false;
                end
            else
                obj.CurrentTime = t;
                if obj.IsValidTime
                    frame = readFrame(obj.Reader);
                else
                    frame = obj.Frame;
                end
            end
            obj.Frame = frame;
        end

        function writeSrt(obj, t, s, filePath, options)
            % WRITESRT Writes a .srt subtitle file from captions and timestamps.
            %
            %   writeSrt(obj, t, s, filePath, ...)
            %
            %   obj: ScreenCapture object
            %   t: column vector of timestamps in seconds
            %   s: column vector of caption strings
            %   filePath: path to save the .srt file
            %   Name-value arguments:
            %       DefaultDurationSeconds: default duration for each caption (default: 1 second)
            %       GapSeconds: gap between captions (default: 0.02 seconds)
            %       MinDurationSeconds: minimum duration for each caption (default: 0.10 seconds)
            %       SkipEmpty: whether to skip empty captions (default: true)
            %       UseWindowsNewline: whether to use Windows-style newlines (default: true)
            %       TrimWhitespace: whether to trim whitespace from captions (default: true)

            arguments
                obj spiky.minos.ScreenCapture
                t (:, 1) double {mustBeFinite, mustBeNonnegative}
                s (:, 1) string
                filePath string = extractBefore(obj.Path, "."+alphanumericsPattern+lineBoundary)+".srt"
                options.DefaultDurationSeconds double {mustBePositive} = 1
                options.GapSeconds double {mustBeNonnegative} = 0.5
                options.MinDurationSeconds double {mustBePositive} = 0.10
                options.SkipEmpty logical = true
                options.UseWindowsNewline logical = false
                options.TrimWhitespace logical = true
            end

            %% Validate inputs
            nLines = size(s, 1);
            assert(height(t)==nLines, ...
                "The number of timestamps and captions must be the same.");
            if options.UseWindowsNewline
                newlineStr = sprintf("\r\n");
            else
                newlineStr = newline;
            end

            %% Compute end times
            t = obj.Sync.Sync.Fit(t);
            startSeconds = t;
            endSeconds = [t(2:end) - options.GapSeconds; t(end) + options.DefaultDurationSeconds];
            endSeconds = max(endSeconds, startSeconds + options.MinDurationSeconds);

            %% Open file (UTF-8)
            [fid, msg] = fopen(filePath, "w", "n", "UTF-8");
            if fid < 0
                error("Failed to open file: %s", msg);
            end
            cleaner = onCleanup(@() fclose(fid));

            %% Write SRT blocks
            idx = 0;
            for ii = 1:nLines
                caption = s(ii);
                if options.TrimWhitespace
                    caption = strtrim(caption);
                end
                if options.SkipEmpty && strlength(caption) == 0
                    continue
                end
                caption = replace(caption, ["\r\n", "\n", "\r"], newlineStr);
                idx = idx + 1;
                startStr = formatSrtTime(startSeconds(ii));
                endStr = formatSrtTime(endSeconds(ii));
                timeLine = startStr + " --> " + endStr;
                block = string(idx) + newlineStr + timeLine + newlineStr + caption + newlineStr + newlineStr;
                fprintf(fid, "%s", block);
            end

            function timeStr = formatSrtTime(secondsValue)
                % FORMATSRTTIME Converts seconds to SRT timestamp format "HH:MM:SS,mmm".
                secondsValue = max(0, secondsValue);
                totalMs = round(secondsValue * 1000);
                ms = mod(totalMs, 1000);
                totalSec = floor(totalMs / 1000);
                ss = mod(totalSec, 60);
                totalMin = floor(totalSec / 60);
                mm = mod(totalMin, 60);
                hh = floor(totalMin / 60);
                timeStr = compose("%02d:%02d:%02d,%03d", hh, mm, ss, ms);
                timeStr = timeStr(1);
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