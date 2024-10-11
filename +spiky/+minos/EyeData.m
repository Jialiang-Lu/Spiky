classdef EyeData < spiky.core.Metadata

    properties
        Data spiky.core.TimeTable
        Fixations spiky.core.Periods
        Saccades spiky.core.Periods
        Blinks spiky.core.Periods
    end

    properties (Dependent)
        Time double
    end

    methods (Static)
        function obj = load(fdir, func, fiveDot)
            % LOAD Load eye data from a directory
            %
            %   fdir: directory containing the eye data
            %   func: function to convert the time
            %   fiveDot: paradigm from a 5-dot calibration
            %
            %   obj: eye data object
            arguments
                fdir (1, 1) string {mustBeFolder}
                func = []
                fiveDot spiky.minos.Paradigm = []
            end
            data0 = spiky.minos.Data(fullfile(fdir, "Eye.bin"));
            t = func(double(data0.Values.Timestamp)/1e7);
            data = table();
            data.Timestamp = data0.Values.Timestamp;
            data.LeftPupil = data0.Values.LeftPupil;
            data.LeftGaze = [data0.Values.LeftGazeX, data0.Values.LeftGazeY, ...
                data0.Values.LeftGazeZ];
            data.RightPupil = data0.Values.RightPupil;
            data.RightGaze = [data0.Values.RightGazeX, data0.Values.RightGazeY, ...
                data0.Values.RightGazeZ];
            data.Convergence = [data0.Values.ConvergenceX, data0.Values.ConvergenceY, ...
                data0.Values.ConvergenceZ];
            idcLeftClosed = data0.Values.LeftPupil==0;
            idcRightClosed = data0.Values.RightPupil==0;
            data.LeftGaze(idcLeftClosed, :) = NaN("single");
            data.RightGaze(idcRightClosed, :) = NaN("single");
            data = spiky.core.TimeTable(t, data);
            events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
            if ~isempty(events.Values)
                events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
                fixations = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Values, "Fixation")));
                saccades = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Values, "Saccade")));
                leftBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Values, "Blink", 0)));
                rightBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Values, "Blink", 1)));
                blinks = leftBlinks|rightBlinks;
            else
                fixations = spiky.core.Periods.empty;
                saccades = spiky.core.Periods.empty;
                blinks = spiky.core.Periods.empty;
            end
            obj = spiky.minos.EyeData;
            obj.Data = data;
            obj.Fixations = fixations;
            obj.Saccades = saccades;
            obj.Blinks = blinks;
        end

        function periods = extractPeriods(events, type, eye)
            arguments
                events table
                type string
                eye (1, 1) double = 0
            end
            events1 = events(endsWith(events.Type, type)&...
                events.Eye==eye, :);
            if startsWith(events1.Type(1), "End")
                events1(1, :) = [];
            end
            if startsWith(events1.Type(end), "Start")
                events1(end, :) = [];
            end
            if mod(height(events1), 2)~=0
                error("Odd number of events")
            end
            periods = double([events1.Timestamp(1:2:end), ...
                events1.Timestamp(2:2:end)])./1e7;
        end
    end
end