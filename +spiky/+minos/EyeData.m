classdef EyeData

    properties
        Data spiky.core.EventsTable
        Fixations spiky.core.Intervals
        Saccades spiky.core.Intervals
        Blinks spiky.core.Intervals
        FixationTargets spiky.core.IntervalsTable
    end

    properties (Dependent)
        Time double
    end

    methods (Static)
        function vp = getViewport(gaze, height, width)
            %GETVIEWPORT Get viewport
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

        function gaze = getGaze(vp, height, width)
            %GETGAZE Get gaze direction vector from viewport
            %
            %   gaze = getGaze(vp, height, width)
            %
            %   vp: viewport, (0, 0) is the left top corner, (1, 1) is the right bottom corner
            %   height: height of the screen in degrees of view angle
            %   width: width of the screen in degrees of view angle
            %
            %   gaze: gaze direction vector (Nx3 matrix)
            arguments
                vp (:, 3) double
                height (1, 1) double
                width (1, 1) double = NaN
            end
            if isnan(width)
                w = tand(height/2)*16/9;
            else
                w = tand(width/2);
            end
            h = tand(height/2);
            gaze = ones(size(vp, 1), 3, like=vp);
            gaze(:, 1) = (vp(:, 1)-0.5).*w*2;
            gaze(:, 2) = (vp(:, 2)-0.5).*h*2;
            gaze = gaze./vecnorm(gaze, 2, 2);
        end

        function obj = load(fdir, func, fiveDot, transform, fov)
            %LOAD Load eye data from a directory
            %
            %   fdir: directory containing the eye data
            %   func: function to convert the time
            %   fiveDot: paradigm from a 5-dot calibration
            %
            %   obj: eye data object
            arguments
                fdir (1, 1) string {mustBeFolder}
                func = []
                fiveDot spiky.minos.Paradigm = spiky.minos.Paradigm
                transform spiky.minos.Transform = spiky.minos.Transform
                fov double = 60
            end
            %%
            fprintf("Loading eye data\n");
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
            data = spiky.core.EventsTable(t, data);
            %%
            if ~isempty(fiveDot)
                %% Calibrate with FiveDot
                fprintf("Calibrating eye data with FiveDot paradigm\n");
                [pos, ~, idcPos] = unique(fiveDot.Trials.Pos, "rows", "sorted");
                pos = pos./pos(:, 3);
                nPos = size(pos, 1);
                prdTrials = spiky.core.Intervals([fiveDot.Trials.Data.Start_Align fiveDot.Trials.Data.End]);
                
                dataRaw = spiky.minos.Data(fullfile(fdir, "EyeRaw.bin"));
                proc = spiky.minos.Data(fullfile(fdir, "EyeProcessor.bin"));
                tRaw = func(double(dataRaw.Data.Timestamp)/1e7);
                dataRaw = spiky.core.EventsTable(tRaw, dataRaw.Data);
                data1 = dataRaw.inIntervals(prdTrials, KeepType=true);
                angVel = [vecnorm(diff(data1.LeftGaze, 1, 1), 2, 2)./diff(data1.Time); 0];
                isFix = angVel<5 & (data1.LeftPupil>0 | data1.RightPupil>0);
                data1 = data1(isFix, :);

                %%
                leftGaze = NaN(nPos, 3, "single");
                rightGaze = NaN(nPos, 3, "single");
                names = ["LeftGaze" "RightGaze"];
                for ii = 1:nPos
                    % Find fixated intervals
                    isPos1 = idcPos==ii;
                    pos1 = pos(ii, :);
                    prd1 = prdTrials.Time(isPos1, :);
                    dataTrial = data.inIntervals(prd1, KeepType=true);
                    for jj = 1:2
                        d1 = vecnorm(dataTrial.Data.(names(jj))-pos1, 2, 2);
                        tFix1 = dataTrial.Time(d1<0.2);
                        prdFix1 = spiky.core.Events(tFix1).findContinuous(0.1, 0.1);
                        data2 = data1.inIntervals(prd1, KeepType=true);
                        data2 = data2.inIntervals(prdFix1, KeepType=true);
                        tmp = data2.Data.(names(jj));
                        if jj==1
                            leftGaze(ii, 1:2) = median(tmp(:, 1:2), "omitnan");
                        else
                            rightGaze(ii, 1:2) = median(tmp(:, 1:2), "omitnan");
                        end
                    end
                end
                leftGaze(:, 3) = 1;
                rightGaze(:, 3) = 1;
                idcValidLeft = ~isnan(leftGaze(:, 1));
                idcValidRight = ~isnan(rightGaze(:, 1));

                %%
                w = warning;
                warning off
                fitTypeX = fittype("poly11");
                fitTypeY = fittype("poly11");
                weights = exp(-vecnorm(pos(:, 1:2), 2, 2)*4);
                leftFitX = fit(leftGaze(idcValidLeft, 1:2), pos(idcValidLeft, 1), fitTypeX, ...
                    Weights=weights(idcValidLeft), Robust="off");
                leftFitY = fit(leftGaze(idcValidLeft, 1:2), pos(idcValidLeft, 2), fitTypeY, ...
                    Weights=weights(idcValidLeft), Robust="off");
                rightFitX = fit(rightGaze(idcValidRight, 1:2), pos(idcValidRight, 1), fitTypeX, ...
                    Weights=weights(idcValidRight), Robust="off");
                rightFitY = fit(rightGaze(idcValidRight, 1:2), pos(idcValidRight, 2), fitTypeY, ...
                    Weights=weights(idcValidRight), Robust="off");
                warning(w);

                leftGazeFitted = leftGaze;
                leftGazeFitted(:, 1) = leftFitX(leftGaze(:, 1:2));
                leftGazeFitted(:, 2) = leftFitY(leftGaze(:, 1:2));
                rightGazeFitted = rightGaze;
                rightGazeFitted(:, 1) = rightFitX(rightGaze(:, 1:2));
                rightGazeFitted(:, 2) = rightFitY(rightGaze(:, 1:2));
                figure
                scatter(pos(:, 1), pos(:, 2), 60, "g", "*")
                hold on
                scatter(leftGazeFitted(:, 1), leftGazeFitted(:, 2), 60, "r", "o")
                scatter(rightGazeFitted(:, 1), rightGazeFitted(:, 2), 60, "y", "o")
                legend(["Dot positions" "Left gaze" "Right gaze"], Location="best")
                title("Five Dot Calibration")
                xlabel("Azimuth")
                ylabel("Elevation")
                drawnow

                %%
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
                data = dataRaw;
                t = data.Time;
            end
            data.Data.Proj = spiky.minos.EyeData.getViewport(data.Convergence, fov);
            %% Get eye events
            fprintf("Loading eye events\n");
            events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
            if ~isempty(events.Data)
                %%
                fixations = spiky.core.Intervals(func(...
                    spiky.minos.EyeData.extractIntervals(events.Data, "Fixation")));
                saccades = spiky.core.Intervals(func(...
                    spiky.minos.EyeData.extractIntervals(events.Data, "Saccade")));
                leftBlinks = spiky.core.Intervals(func(...
                    spiky.minos.EyeData.extractIntervals(events.Data, "Blink", 0)));
                rightBlinks = spiky.core.Intervals(func(...
                    spiky.minos.EyeData.extractIntervals(events.Data, "Blink", 1)));
                blinks = leftBlinks|rightBlinks;
                %% Find fixation targets
                if ~isempty(transform)
                    fprintf("Finding fixation targets\n");
                    transform = transform(transform.IsHuman);
                    nFixations = height(fixations.Time);
                    nTr = numel(transform);
                    gaze = data.Convergence;
                    vp = spiky.minos.EyeData.getViewport(gaze, fov);
                    vp = single(vp);
                    proj = interp1(t, vp, fixations.Start+0.01);
                    gaze = interp1(t, gaze, fixations.Start+0.01);
                    %%
                    trT = cell(nTr, 1);
                    trIdc = cell(nTr, 1);
                    trIdcT = cell(nTr, 1);
                    trPos = cell(nTr, 1);
                    trProj = cell(nTr, 1);
                    trTrial = cell(nTr, 1);
                    for ii = 1:nTr
                        idc1 = find(transform(ii).Visible);
                        idc1 = idc1(1:end-1);
                        trT{ii} = transform(ii).Time([idc1 idc1+1]);
                        trIdc{ii} = ones(numel(idc1), 1).*ii;
                        trPos{ii} = transform(ii).Pos(idc1, :, :);
                        trProj{ii} = transform(ii).Proj(idc1, :, :);
                        trTrial{ii} = transform(ii).Trial(idc1);
                        trIdcT{ii} = idc1;
                    end
                    trT = vertcat(trT{:});
                    trIdc = vertcat(trIdc{:});
                    trIdcT = vertcat(trIdcT{:});
                    trPos = vertcat(trPos{:});
                    trProj = vertcat(trProj{:});
                    trTrial = vertcat(trTrial{:});
                    trVec = (trProj-0.5)*2.*[tand(fov/2)/9*16 tand(fov/2) 0]+[0 0 1];
                    [~, idcSortTr] = sort(trT(:, 1), "ascend");
                    trTSorted = trT(idcSortTr, :);
                    trIdcSorted = trIdc(idcSortTr);
                    trIdcTSorted = trIdcT(idcSortTr);
                    trVecSorted = trVec(idcSortTr, :, :);
                    trPosSorted = trPos(idcSortTr, :, :);
                    trProjSorted = trProj(idcSortTr, :, :);
                    trTrialSorted = trTrial(idcSortTr);
                    %%
                    [~, idcFixInTr, idcTrWithFix] = spiky.core.Intervals(trTSorted).haveEvents(fixations.Start+0.01);
                    ang = squeeze(spiky.utils.angle(trVecSorted(idcTrWithFix, :, :), gaze(idcFixInTr, :), 2));
                    tbl = table();
                    tbl.Angle = ang;
                    tbl.IdcFix = idcFixInTr;
                    tbl1 = groupsummary(tbl, "IdcFix", ...
                        @(x) spiky.utils.wrap(@min, 1:2, x(:, 2:end)', [], "all"), ...
                        "Angle");
                    idcFixValid = tbl1.IdcFix;
                    ang1 = tbl1.fun1_Angle;
                    minAng = cell2mat(ang1(:, 1));
                    minInd = cell2mat(ang1(:, 2));
                    idcMinTrEach = floor((minInd-1)/11)+1;
                    idcMinPart = mod(minInd-1, 11)+1;
                    idcMinTr = zeros(height(ang1), 1);
                    idcAllTr = cell(height(ang1), 1);
                    idcOtherTr = cell(height(ang1), 1);
                    isDouble = false(height(ang1), 1);
                    for ii = 1:height(ang1)
                        idc1 = find(idcFixInTr==idcFixValid(ii));
                        idx1 = idcMinTrEach(ii);
                        idcMinTr(ii) = idcTrWithFix(idc1(idx1));
                        idcAllTr{ii} = idcTrWithFix(idc1);
                        idcOtherTr{ii} = idcTrWithFix(idc1(1:end~=idx1));
                        isDouble(ii) = numel(idc1)==2;
                    end
                    idcTr = trIdcSorted(idcMinTr);
                    idcTrAll = cellfun(@(x) trIdcSorted(x), idcAllTr, UniformOutput=false);
                    idcTrOther = cellfun(@(x) trIdcSorted(x), idcOtherTr, UniformOutput=false);
                    nValid = numel(idcFixValid);
                    %%
                    ids = zeros(nFixations, 1, "int32");
                    idss = cell(nFixations, 1);
                    otherIds = zeros(nFixations, 1, "int32");
                    names = categorical(NaN(nFixations, 1));
                    namess = cell(nFixations, 1);
                    otherNames = categorical(NaN(nFixations, 1));
                    trials = zeros(nFixations, 1, "int32");
                    parts = spiky.minos.BodyPart(zeros(nFixations, 1));
                    targetPos = zeros(nFixations, 3, "single");
                    targetProj = zeros(nFixations, 3, "single");
                    angles = zeros(nFixations, 1, "single");
                    %%
                    ids(idcFixValid) = transform.Id(idcTr);
                    idss(idcFixValid) = cellfun(@(x) transform.Id(x), idcTrAll, UniformOutput=false);
                    otherIds(idcFixValid(isDouble)) = transform.Id(cell2mat(idcTrOther(isDouble)));
                    names(idcFixValid) = categorical(transform.Name(idcTr));
                    namess(idcFixValid) = cellfun(@(x) categorical(transform.Name(x)), idcTrAll, UniformOutput=false);
                    otherNames(idcFixValid(isDouble)) = categorical(transform.Name(cell2mat(idcTrOther(isDouble))));
                    trials(idcFixValid) = trTrialSorted(idcMinTr);
                    parts(idcFixValid) = spiky.minos.BodyPart(idcMinPart);
                    idcPos = sub2ind(size(trPosSorted), ...
                        repmat(idcMinTr, 3, 1), reshape(repmat(1:3, nValid, 1), [], 1), ...
                        repmat(idcMinPart+1, 3, 1));
                    targetPos(idcFixValid, :) = reshape(trPosSorted(idcPos), [], 3);
                    targetProj(idcFixValid, :) = reshape(trProjSorted(idcPos), [], 3);
                    angles(idcFixValid) = minAng;
                    %%
                    fixationTargets = table(trials, ids, names, idss, namess, otherIds, ...
                        otherNames, parts, gaze, proj, ...
                        targetPos, targetProj, angles, VariableNames=["Trial" "Id" "Name" "Ids" ...
                        "Names" "OtherId" "OtherName" "Part" ...
                        "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
                else
                    fixationTargets = table(Size=[0 9], VariableTypes=["int32" "int32" "categorical" ...
                        "cell" "cell" "int32" "categorical" ...
                        "spiky.minos.BodyPart" "single" "single" "single" "single" "single"], ...
                        VariableNames=["Trial" "Id" "Name" "Ids" ...
                        "Names" "OtherId" "OtherName" "Part" ...
                        "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
                end
            else
                fixations = spiky.core.Intervals;
                saccades = spiky.core.Intervals;
                blinks = spiky.core.Intervals;
                fixationTargets = table(Size=[0 9], VariableTypes=["int32" "int32" "categorical" ...
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
                obj.FixationTargets = spiky.core.IntervalsTable(double.empty(0, 2), fixationTargets);
            else
                obj.FixationTargets = spiky.core.IntervalsTable(fixations.Time, fixationTargets);
            end
        end

        function intervals = extractIntervals(events, type, eye)
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
            intervals = double([events1.Timestamp(1:2:end), ...
                events1.Timestamp(2:2:end)])./1e7;
        end
    end

    methods
        function intervals = getViewIntervals(obj, mingap, mininterval)
            %GETVIEWINTERVALS Get intervals when the eye is visible
            %
            %   mingap: minimum gap between intervals in seconds
            %   mininterval: minimum interval length in seconds
            %
            %   intervals: intervals when the eye is visible
            arguments
                obj spiky.minos.EyeData
                mingap (1, 1) double = 1
                mininterval (1, 1) double = 2
            end
            if isempty(obj.Data.Time)
                intervals = spiky.core.Intervals;
                return
            end
            isViewing = ~isnan(obj.Data.Convergence(:, 1)) & ...
                obj.Data.Proj(:, 1)>0 & ...
                obj.Data.Proj(:, 1)<1 & ...
                obj.Data.Proj(:, 2)>0 & ...
                obj.Data.Proj(:, 2)<1;
            tt = spiky.core.EventsTable(obj.Data.Time, isViewing);
            intervals = tt.findIntervals(0, mingap, mininterval);
        end

        function time = get.Time(obj)
            time = obj.Data.Time;
        end
    end
end