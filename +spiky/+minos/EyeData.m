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

    methods
        function time = get.Time(obj)
            time = obj.Data.Time;
        end

        function vp = getViewport(obj, height, width)
            % GETVIEWPORT Get viewport
            %
            %   vp = getViewport(obj, height, width)
            %
            %   obj: eye data object
            %   height: height of the screen in degrees of view angle
            %   width: width of the screen in degrees of view angle
            %
            %   vp: viewport, (0, 0) is the left top corner, (1, 1) is the right bottom corner

            arguments
                obj spiky.minos.EyeData
                height (1, 1) double
                width (1, 1) double = NaN
            end
            if isnan(width)
                width = height/9*16;
            end
            gaze = double(obj.Data.Convergence);
            vp = [gaze(:, 1)./gaze(:, 3)./tand(width/2).*0.5+0.5...
                gaze(:, 2)./gaze(:, 3)./tand(height/2).*0.5+0.5];
            vp(gaze(:, 3)<=0, :) = NaN;
            vp = spiky.core.TimeTable(obj.Time, vp);
        end
    end

    methods (Static)
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
            idcLeftClosed = data0.Data.LeftPupil==0;
            idcRightClosed = data0.Data.RightPupil==0;
            data.LeftGaze(idcLeftClosed, :) = NaN("single");
            data.RightGaze(idcRightClosed, :) = NaN("single");
            data = spiky.core.TimeTable(t, data);
            %%
            events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
            if ~isempty(events.Data)
                %%
                events = spiky.minos.Data(fullfile(fdir, "EyeLinkEvent.bin"));
                fixations = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Fixation")));
                saccades = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Saccade")));
                leftBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Blink", 0)));
                rightBlinks = spiky.core.Periods(func(...
                    spiky.minos.EyeData.extractPeriods(events.Data, "Blink", 1)));
                blinks = leftBlinks|rightBlinks;
                %%
                if ~isempty(transform)
                    nFixations = height(fixations);
                    prds = vertcat(transform.Period);
                    [~, idcFix, idcTr] = prds.haveEvents(fixations.Start+0.01);
                    gaze = double(data.Convergence);
                    vp = [gaze(:, 1)./gaze(:, 3)./tand(fov/9*16/2)*0.5+0.5...
                        gaze(:, 2)./gaze(:, 3)./tand(fov/2)*0.5+0.5 gaze(:, 3).*Inf];
                    vp(gaze(:, 3)<=0, :) = NaN;
                    vp = single(vp);
                    proj = interp1(t, vp, fixations.Start+0.01);
                    gaze = interp1(t, gaze, fixations.Start+0.01);
                    gaze = gaze./vecnorm(gaze, 2, 2);
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
                        tr1 = transform(idc1).interp(fixations.Start(ii));
                        proj1 = {tr1.Proj};
                        proj1 = cellfun(oneFunc, proj1, UniformOutput=false);
                        proj1 = vertcat(proj1{:});
                        vec1 = (proj1-0.5)*2.*[tand(fov/9*16/2) tand(fov/2) 0]+[0 0 1];
                        vec1 = vec1./vecnorm(vec1, 2, 2);
                        ang1 = acosd(dot(vec1, gaze(ii, :).*ones(size(vec1)), 2));
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
                    fixationTargets = table(trials, ids, names, parts, single(gaze), proj, ...
                        targetPos, targetProj, angles, VariableNames=["Trial" "Id" "Name" "Part" ...
                        "Gaze" "Proj" "TargetPos" "TargetProj" "MinAngle"]);
                else
                    fixationTargets = table(Size=[0 9], VariableTypes=["int32" "int32" "string" ...
                        "spiky.minos.BodyPart" "single" "single" "single" "single" "single"], ...
                        VaraibleNames=["Trial" "Id" "Name" "Part" ...
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
            obj.FixationTargets = spiky.core.TimeTable(fixations.Start, fixationTargets);
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
end