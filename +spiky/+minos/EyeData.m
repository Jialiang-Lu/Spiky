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
            data = spiky.minos.Data(fullfile(fdir, "Eye.bin"));
            data.Values = mergevars(data.Values, ["LeftGazeX", "LeftGazeY", "LeftGazeZ"], ...
                NewVariableName="LeftGaze");
            data.Values = mergevars(data.Values, ["LeftGazeRealX", "LeftGazeRealY", ...
                "LeftGazeRealZ"], NewVariableName="LeftGazeReal");
            data.Values = mergevars(data.Values, ["RightGazeX", "RightGazeY", "RightGazeZ"], ...
                NewVariableName="RightGaze");
            data.Values = mergevars(data.Values, ["RightGazeRealX", "RightGazeRealY", ...
                "RightGazeRealZ"], NewVariableName="RightGazeReal");
            data.Values = mergevars(data.Values, ["ConvergenceX", "ConvergenceY", ...
                "ConvergenceZ"], NewVariableName="Convergence");
            t = func(double(data.Values.Timestamp)/1e7);
            data = spiky.core.TimeTable(t, data.Values);
            if exist(fullfile(fdir, "EyeLinkEvent.bin"), "file")
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
                error("Not implemented")
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
            events1 = events(endsWith(events.ValueType, type)&...
                events.ValueEye==eye, :);
            if startsWith(events1.ValueType(1), "End")
                events1(1, :) = [];
            end
            if startsWith(events1.ValueType(end), "Start")
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