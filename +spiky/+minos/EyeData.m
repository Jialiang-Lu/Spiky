classdef EyeData < spiky.core.Metadata

    properties
        Data spiky.core.TimeTable
        Fixations spiky.core.Periods
        Saccades spiky.core.Periods
        Blinks spiky.core.Periods
        FixationTargets spiky.core.TimeTable
    end

    properties (Dependent)
        Time double
    end

    methods (Static)
        function vp = getViewport(gaze, height, width)
            % GETVIEWPORT Get viewport
            %
            %   vp = getViewport(gaze, height, width)
            %
            %   gaze: gaze data
            %   height: height of the screen in degrees of view angle
            %   width: width of the screen in degrees of view angle
            %
            %   vp: viewport, (0, 0) is the left top corner, (1, 1) is the right bottom corner
            arguments
                gaze (:, 3) double
                height (1, 1) double
                width (1, 1) double = NaN
            end
            if isnan(width)
                w = tand(height/2)*16/9;
            else
                w = tand(width/2);
            end
            h = tand(height/2);
            z = Inf(size(gaze, 1), 1);
            z(isnan(gaze(:, 1))) = NaN;
            vp = [gaze(:, 1)./gaze(:, 3)./w.*0.5+0.5...
                gaze(:, 2)./gaze(:, 3)./h.*0.5+0.5 z];
        end

        function obj = load(fdir, func, fiveDot, transform, fov)
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
                fiveDot spiky.minos.Paradigm = spiky.minos.Paradigm.empty
                transform spiky.minos.Transform = spiky.minos.Transform.empty
                fov double = 60
            end
            %%
            data0 = spiky.minos.Data(fullfile(fdir, "Eye.bin"));
            t = func(double(data0.Data.Timestamp)/1e7);
            data = table();
            data.Timestamp = data0.Data.Timestamp;
            data.LeftPupil = data0.Data.LeftPupil;
            data.LeftGaze = data0.Data.LeftGaze;
            data.RightPupil = data0.Data.RightPupil;
            data.RightGaze = data0.Data.RightGaze;
            data.Convergence = data0.Data.Convergence;
            data.Convergence = data.Convergence./data.Convergence(:, 3);
            idcLeftClosed = data0.Data.LeftPupil==0;
            idcRightClosed = data0.Data.RightPupil==0;
            data.LeftGaze(idcLeftClosed, :) = NaN("single");
            data.RightGaze(idcRightClosed, :) = NaN("single");
            data = spiky.core.TimeTable(t, data);
            %%
            if ~isempty(fiveDot)
                % Calibrate with FiveDot
                [pos, ~, idcPos] = unique(fiveDot.Trials.Pos, "rows", "sorted");
                pos = pos./pos(:, 3);
                nPos = size(pos, 1);
                prdTrials = spiky.core.Periods([fiveDot.Trials.Start_Align fiveDot.Trials.End]);
                
                dataRaw = spiky.minos.Data(fullfile(fdir, "EyeRaw.bin"));
                tRaw = func(double(dataRaw.Data.Timestamp)/1e7);
                dataRaw = spiky.core.TimeTable(tRaw, dataRaw.Data);
                data1 = dataRaw.inPeriods(prdTrials, KeepType=true);
                angVel = [vecnorm(diff(data1.LeftGaze, 1, 1), 2, 2)./diff(data1.Time); 0];
                isFix = angVel<5 & data1.LeftPupil>0 & data1.RightPupil>0;
                data1 = data1(isFix, :);

                leftGaze = ones(nPos, 3, "single");
                rightGaze = ones(nPos, 3, "single");
                for ii = 1:nPos
                    % Find fixated periods
                    isPos1 = idcPos==ii;
                    pos1 = pos(ii, :);
                    prd1 = prdTrials.Time(isPos1, :);
                    dataTrial = data.inPeriods(prd1, KeepType=true);
                    d1 = vecnorm(dataTrial.Convergence-pos1, 2, 2);
                    tFix1 = dataTrial.Time(d1<0.1);
                    prdFix1 = spiky.core.Events(tFix1).findContinuous(0.1, 0.1);
                    % Filter data
                    data2 = data1.inPeriods(prd1, KeepType=true);
                    data2 = data2.inPeriods(prdFix1, KeepType=true);
                    leftGaze(ii, 1:2) = median(data2.LeftGaze(:, 1:2), "omitnan");
                    rightGaze(ii, 1:2) = median(data2.RightGaze(:, 1:2), "omitnan");
                end

                w = warning;
                warning off
                fitTypeX = fittype("poly22");
                fitTypeY = fittype("poly22");
                weights = exp(-vecnorm(pos(:, 1:2), 2, 2)*3);
                leftFitX = fit(leftGaze(:, 1:2), pos(:, 1), fitTypeX, Weights=weights, ...
                    Robust="off");
                leftFitY = fit(leftGaze(:, 1:2), pos(:, 2), fitTypeY, Weights=weights, ...
                    Robust="off");
                rightFitX = fit(rightGaze(:, 1:2), pos(:, 1), fitTypeX, Weights=weights, ...
                    Robust="off");
                rightFitY = fit(rightGaze(:, 1:2), pos(:, 2), fitTypeY, Weights=weights, ...
                    Robust="off");
                warning(w);

                leftGazeFitted = leftGaze;
                leftGazeFitted(:, 1) = leftFitX(leftGaze(:, 1:2));
                leftGazeFitted(:, 2) = leftFitY(leftGaze(:, 1:2));
                rightGazeFitted = rightGaze;
                rightGazeFitted(:, 1) = rightFitX(rightGaze(:, 1:2));
                rightGazeFitted(:, 2) = rightFitY(rightGaze(:, 1:2));
                spiky.plot.fig
                scatter(pos(:, 1), pos(:, 2), 60, "g", "*")
                hold on
                scatter(leftGazeFitted(:, 1), leftGazeFitted(:, 2), 60, "r", "o")
                scatter(rightGazeFitted(:, 1), rightGazeFitted(:, 2), 60, "y", "o")
                legend(["Dot positions" "Left gaze" "Right gaze"], Location="best")
                title("Five Dot Calibration")
                xlabel("Azimuth")
                ylabel("Elevation")

                dataRaw.LeftGaze(:, 1) = leftFitX(dataRaw.LeftGaze(:, 1:2));
                dataRaw.LeftGaze(:, 2) = leftFitY(dataRaw.LeftGaze(:, 1:2));
                dataRaw.RightGaze(:, 1) = rightFitX(dataRaw.RightGaze(:, 1:2));
                dataRaw.RightGaze(:, 2) = rightFitY(dataRaw.RightGaze(:, 1:2));

                dataRaw.Data.Convergence = (dataRaw.LeftGaze+dataRaw.RightGaze)./2;
                dataRaw.Convergence = dataRaw.Convergence./dataRaw.Convergence(:, 3);
                idcLeftClosed = dataRaw.LeftPupil==0;
                idcRightClosed = dataRaw.RightPupil==0;
                dataRaw.LeftGaze(idcLeftClosed, :) = NaN("single");
                dataRaw.RightGaze(idcRightClosed, :) = NaN("single");
                dataRaw.Convergence(idcLeftClosed&idcRightClosed, :) = NaN("single");
                dataRaw.Data.Proj = spiky.minos.EyeData.getViewport(dataRaw.Convergence, fov);
                data = dataRaw;
                t = data.Time;
            end
            %% Get eye events
            events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
            if ~isempty(events.Data)
                %%
                fixations = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Fixation")));
                saccades = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Saccade")));
                leftBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Blink", 0)));
                rightBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Blink", 1)));
                blinks = leftBlinks|rightBlinks;
                %% Find fixation targets
                if ~isempty(transform)
                    nFixations = height(fixations.Time);
                    prds = spiky.core.Periods.concat(transform.Period);
                    [~, idcFix, idcTr] = prds.haveEvents(fixations.Start+0.01);
                    gaze = data.Convergence;
                    vp = spiky.minos.EyeData.getViewport(gaze, fov);
                    vp = single(vp);
                    proj = interp1(t, vp, fixations.Start+0.01);
                    gaze = interp1(t, gaze, fixations.Start+0.01);
                    %%
                    ids = zeros(nFixations, 1, "int32");
                    names = strings(nFixations, 1);
                    trials = zeros(nFixations, 1, "int32");
                    parts = spiky.minos.BodyPart(zeros(nFixations, 1));
                    targetPos = zeros(nFixations, 3, "single");
                    targetProj = zeros(nFixations, 3, "single");
                    angles = zeros(nFixations, 1, "single");
                    one3 = ones(1, 1, 12, "single");
                    oneFunc = @(x) x.*one3;
                    %%
                    pb = spiky.plot.ProgressBar(nFixations, "Calculating fixation targets", ...
                        Parallel=true);
                    parfor ii = 1:nFixations
                        %%
                        is1 = idcFix==ii;
                        if sum(is1)==0
                            pb.step
                            continue
                        end
                        idc1 = idcTr(is1);
                        tr1 = transform(idc1).interp(fixations.Start(ii)+0.01);
                        proj1 = {tr1.Proj};
                        proj1 = cellfun(oneFunc, proj1, UniformOutput=false);
                        proj1 = vertcat(proj1{:});
                        vec1 = (proj1-0.5)*2.*[tand(fov/2)/9*16 tand(fov/2) 0]+[0 0 1];
                        vec1 = vec1./vecnorm(vec1, 2, 2);
                        ang1 = acosd(dot(vec1, gaze(ii, :).*ones(size(vec1)), 2)./vecnorm(gaze(ii, :), 2));
                        [minAngle, idxMin] = min(ang1, [], "all");
                        [idxMinTr, idxMinPart] = ind2sub(size(ang1), idxMin);
                        trMin = tr1(idxMinTr);
                        if ~trMin.IsHuman
                            idxMinPart = 1;
                        end
                        part = spiky.minos.BodyPart(idxMinPart-1);
                        ids(ii) = trMin.Id;
                        names(ii) = trMin.Name;
                        targetPos(ii, :) = trMin.Pos(:, :, idxMinPart);
                        targetProj(ii, :) = trMin.Proj(:, :, idxMinPart);
                        angles(ii) = minAngle;
                        trials(ii) = trMin.Trial;
                        parts(ii) = part;
                        pb.step
                    end
                    names = categorical(names);
                    %%
                    fixationTargets = table(trials, ids, names, parts, gaze, proj, ...
                        targetPos, targetProj, angles, VariableNames=["Trial" "Id" "Name" "Part" ...
                        "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
                else
                    fixationTargets = table(Size=[0 9], VariableTypes=["int32" "int32" "string" ...
                        "spiky.minos.BodyPart" "single" "single" "single" "single" "single"], ...
                        VariableNames=["Trial" "Id" "Name" "Part" ...
                        "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
                end
            else
                fixations = spiky.core.Periods.empty;
                saccades = spiky.core.Periods.empty;
                blinks = spiky.core.Periods.empty;
                fixationTargets = table(Size=[0 9], VariableTypes=["int32" "int32" "string" ...
                    "spiky.minos.BodyPart" "single" "single" "single" "single" "single"], ...
                    VaraibleNames=["Trial" "Id" "Name" "Part" ...
                    "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
            end
            %%
            obj = spiky.minos.EyeData;
            obj.Data = data;
            obj.Fixations = fixations;
            obj.Saccades = saccades;
            obj.Blinks = blinks;
            if isempty(fixationTargets)
                obj.FixationTargets = spiky.core.TimeTable([], fixationTargets);
            else
                obj.FixationTargets = spiky.core.TimeTable(fixations.Start, fixationTargets);
            end
        end

        function periods = extractPeriods(events, type, eye)
            arguments
                events table
                type string
                eye (1, 1) double = 0
            end
            events1 = events(endsWith(string(events.Type), type)&...
                events.Eye==eye, :);
            if startsWith(string(events1.Type(1)), "End")
                events1(1, :) = [];
            end
            if startsWith(string(events1.Type(end)), "Start")
                events1(end, :) = [];
            end
            if mod(height(events1), 2)~=0
                error("Odd number of events")
            end
            periods = double([events1.Timestamp(1:2:end), ...
                events1.Timestamp(2:2:end)])./1e7;
        end
    end

    methods
        function time = get.Time(obj)
            time = obj.Data.Time;
        end
    end
end