classdef ActionTheater < spiky.par.Paradigm
    %ACTIONTHEATER represents a paradigm for the Action Theater

    properties
        Graph spiky.scene.SceneGraph % Scene graph representing the actions and interactions
        Fix spiky.core.IntervalsTable % Fixations during the paradigm
    end

    methods
        function obj = ActionTheater(minos, tr)
            %ACTIONTHEATER represents a paradigm for the Action Theater
            arguments
                minos spiky.minos.MinosInfo
                tr spiky.minos.Transform
            end
            
            obj@spiky.par.Paradigm(minos, "ActionTheater");
            %% Clean up the data and convert indices to names
            tr = tr([tr.IsHuman]');
            ti = obj.TrialInfo;
            trials = obj.Trials;
            ti = ti(ismember(ti.Number, trials.Number), :);
            t1 = ti.Time(1);
            actors = categorical(extractBefore(obj.Vars.Actors.get(t1)', " "));
            targets = categorical(extractBefore(obj.Vars.Targets.get(t1)', " "));
            actions1 = extractBefore(obj.Vars.SingleActions.get(t1)', " ");
            actions2 = extractBefore(obj.Vars.Actions.get(t1)', " ");
            adjs = extractBefore(obj.Vars.Adjs.get(t1)', " ");
            isHuman = (ti.Type~="HumanObject" | ti.Role~="Target") & ...
                ismember(ti.Role, ["Source" "Target" "Spawn" "Kill"]);
            isHumanRole = (ti.Type~="HumanObject" | ti.Role~="Target") & ...
                ismember(ti.Role, ["Source" "Target"]);
            isSpawn = ti.Role=="Spawn";
            isKill = ti.Role=="Kill";
            isObject = ti.Type=="HumanObject" & ti.Role=="Target";
            isAction = ti.Role=="Action";
            isDoubleAction = ismember(ti.Type, ["HumanHuman" "HumanHumanObject"]);
            tiActor = strings(height(ti), 1);
            tiActor(isHuman) = actors(ti.Actor(isHuman)+1);
            tiActor(isObject) = targets(ti.Actor(isObject)+1);
            tiAction = strings(height(ti), 1);
            tiAction(ti.Type=="HumanHuman") = actions2(ti.Action(ti.Type=="HumanHuman")+1);
            tiAction(ti.Type=="HumanObject") = actions1(ti.Action(ti.Type=="HumanObject")+1);
            tiAdj = strings(height(ti), 1);
            tiAdj(~isAction) = adjs(ti.Adj(~isAction)+1);
            try
                actions3 = extractBefore(obj.Vars.IndirectActions.get(t1)', " ");
                tiAction(ti.Type=="HumanHumanObject") = actions3(ti.Action(ti.Type=="HumanHumanObject")+1);
            catch
            end
            ti.Actor = categorical(tiActor);
            ti.Action = categorical(tiAction);
            ti.Adj = categorical(tiAdj);
            ti.Data.Proj = spiky.minos.EyeData.getViewport(ti.Pos, 60);
            %% Visibility of each entity
            vis = {tr.Visible}';
            idcVis = find(cellfun(@any, vis));
            nVis = numel(idcVis);
            vis = vis(idcVis);
            idcStart = cellfun(@(x) find(x, 1, "first"), vis);
            idcEnd = cellfun(@(x) find(x, 1, "last"), vis);
            tr = tr(idcVis);
            names = categorical([tr.Name]');
            types = strings(nVis, 1);
            isHuman = [tr.IsHuman]';
            types(isHuman) = "Humanoid";
            types(~isHuman) = "Object";
            types = categorical(types);
            per = zeros(nVis, 2);
            pos = zeros(nVis, 3);
            rot = zeros(nVis, 3);
            proj = zeros(nVis, 3);
            % pb = spiky.plot.ProgressBar(nVis, "Calculating visibility", Parallel=true);
            parfor ii = 1:nVis
                idx1 = idcStart(ii);
                idx2 = idcEnd(ii);
                per(ii, :) = tr(ii).Time([idx1 idx2]);
                pos(ii, :) = tr(ii).Pos(idx1, :, 1);
                rot(ii, :) = tr(ii).Rot(idx1, :, 1);
                proj(ii, :) = tr(ii).Proj(idx1, :, 1);
                % pb.step
            end
            nodesVis = spiky.scene.SceneNode(per, names, types, [tr.Id]', pos, rot, proj);
            graphVis = spiky.scene.SceneGraph(per, nodesVis);
            graphVis.Time = graphVis.Time+obj.Latency;
            %% Walk
            idcWalk = find(isHumanRole | isKill);
            nWalk = numel(idcWalk);
            trialsWalk = trials(ismember(trials.Number, ti.Number(idcWalk)), :);
            [~, idcWalkTrial] = ismember(ti.Number(idcWalk), trialsWalk.Number);
            per = trialsWalk(idcWalkTrial, ["Move" "Wait"]).Data{:, :};
            tiWalk = ti(idcWalk, :);
            [~, idcWalkInVis] = ismember(nodesVis.Id, tiWalk.Id);
            per(idcWalkInVis, 1) = graphVis.Time(:, 1);
            [~, idcWalkInVis2] = ismember(nodesVis.Id, tiWalk.Id(end:-1:1));
            idcWalkInVis2 = nWalk+1-idcWalkInVis2;
            per(idcWalkInVis2, 2) = graphVis.Time(:, 2);
            nodesWalk = spiky.scene.SceneNode(per, tiWalk.Actor, "Humanoid", tiWalk.Id, ...
                tiWalk.Pos, tiWalk.Rot, tiWalk.Proj);
            nodesWalkVerb = spiky.scene.SceneNode(per, "Walk", "Verb", 0, ...
                tiWalk.Pos, tiWalk.Rot, tiWalk.Proj);
            graphWalk = spiky.scene.SceneGraph(per, nodesWalk, nodesWalkVerb);
            %% Idle
            isIdle = ~ismissing(ti.Actor) & ti.Action=="Idle" & ti.Role=="Source";
            nIdle = sum(isIdle);
            tiIdle = ti(isIdle, :);
            [~, idcIdleTrial] = ismember(ti.Number(isIdle), trials.Number);
            per = trials(idcIdleTrial, ["Start" "End"]).Data{:, :};
            nodesSubject = spiky.scene.SceneNode(per, tiIdle.Actor, "Humanoid", ...
                tiIdle.Id, tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
            nodesVerb = spiky.scene.SceneNode(per, "Idle", "Verb", 0, ...
                tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
            graphIdle = spiky.scene.SceneGraph(per, nodesSubject, nodesVerb);
            %% Action
            idcSource = find(ti.Role=="Source" & isDoubleAction);
            idcTarget = find(ti.Role=="Target" & isDoubleAction);
            assert(numel(idcSource)==numel(idcTarget), ...
                "Number of sources and targets must match.");
            assert(all(ti.Number(idcSource)==ti.Number(idcTarget)), ...
                "Source and target must have the same trial number.");
            nAction = numel(idcSource);
            [~, idcActionTrial] = ismember(ti.Number(idcSource), trials.Number);
            tiActions = ti(isAction & isDoubleAction, :);
            [~, idcActionInfo] = ismember(ti.Number(idcSource), tiActions.Number);
            tiActions = tiActions(idcActionInfo, :);
            per = trials(idcActionTrial, ["Start" "End"]).Data{:, :};
            nodesSubject = spiky.scene.SceneNode(per, ti.Actor(idcSource), "Humanoid", ...
                ti.Id(idcSource), ti.Pos(idcSource, :), ti.Rot(idcSource, :), ti.Proj(idcSource, :));
            nodesObject = spiky.scene.SceneNode(per, ti.Actor(idcTarget), "Humanoid", ...
                ti.Id(idcTarget), ti.Pos(idcTarget, :), ti.Rot(idcTarget, :), ti.Proj(idcTarget, :));
            nodesVerb = spiky.scene.SceneNode(per, tiActions.Action, "Verb", ...
                tiActions.Id, tiActions.Pos, tiActions.Rot, tiActions.Proj);
            graphAction = spiky.scene.SceneGraph(per, nodesSubject, nodesVerb, nodesObject);
            %%
            obj.TrialInfo = ti;
            obj.Graph = [graphVis; graphWalk; graphAction; graphIdle];
            obj.Graph = obj.Graph.sort();
            %% Fixations
            fix = minos.Eye.FixationTargets;
            fix = fix(fix.Start>=obj.Intervals.Time(1) & fix.End<=obj.Intervals.Time(end), :);
            fix.Data.IsFace = ~ismissing(fix.Name) & fix.MinAngle<8 & ismember(fix.Part, ...
                [spiky.minos.BodyPart.Head spiky.minos.BodyPart.UpperChest ...
                spiky.minos.BodyPart.LeftArm spiky.minos.BodyPart.RightArm ...
                spiky.minos.BodyPart.LeftHand spiky.minos.BodyPart.RightHand]);
            idcFixFace = find(fix.IsFace);
            nFix = height(fix);
            %% Find fixation role
            graphVerb = obj.Graph(obj.Graph.IsVerb, :);
            [~, idcFixVerb, idcVerbFix] = graphVerb.haveEvents(fix.Start);
            idSubject = graphVerb.Subject.Id;
            isFixSubject = fix.Id(idcFixVerb)==idSubject(idcVerbFix) | ...
                ismember(graphVerb.Predicate.Name(idcVerbFix), ["Walk" "Idle"]);
            fix.Data.Role = categorical(NaN(nFix, 1));
            fix.Role(idcFixVerb(isFixSubject)) = "Subject";
            fix.Role(idcFixVerb(~isFixSubject)) = "Object";
            fix.Data.OtherRole = categorical(NaN(nFix, 1));
            fix.OtherRole(idcFixVerb(isFixSubject)) = "Object";
            fix.OtherRole(idcFixVerb(~isFixSubject)) = "Subject";
            fix.Data.Verb = categorical(NaN(nFix, 1));
            fix.Verb(idcFixVerb) = graphVerb.Predicate.Name(idcVerbFix);
            fix.Data.Action = fix.Verb;
            fix.Action(ismember(fix.Action, ["Walk" "Idle"])) = missing;
            fix.Data.ActionRole = categorical(string(fix.Action)+string(fix.Role));
            fix.Data.OtherActionRole = categorical(string(fix.Action)+string(fix.OtherRole));
            %% Find non-fixated targets
            prdTr = spiky.core.Intervals.concat(tr.Interval);
            [~, idcFixInTr, idcTrInFix] = prdTr.haveEvents(fix.Start+0.05);
            idcFixValidTr = unique(idcFixInTr);
            tmp = categorical([tr(idcTrInFix).Name]');
            fixNames = splitapply(@(x) {x}, tmp, findgroups(idcFixInTr));
            fixOtherName = arrayfun(@(a, b) a{1}(setdiff(1:numel(a{1}), find(a{1}==b, 1))), ...
                fixNames, fix.Name(idcFixValidTr), UniformOutput=false);
            fix.Data.Names = categorical(NaN(nFix, 1));
            fix.Names(idcFixValidTr) = categorical(cellfun(@(x) join(sort(string(x)), "|"), fixNames));
            fix.Data.OtherName = categorical(NaN(nFix, 1));
            for ii = 1:numel(idcFixValidTr)
                if isscalar(fixOtherName{ii})
                    fix.OtherName(idcFixValidTr(ii)) = fixOtherName{ii};
                end
            end
            fix.Data.NActors = zeros(nFix, 1);
            fix.NActors(idcFixValidTr) = cellfun(@numel, fixNames);
            %%
            obj.Fix = fix;
        end

        function labels = getLabels(obj, t)
            %GETLABELS Get labels for GLM
            arguments
                obj spiky.par.ActionTheater
                t (:, 1) double
            end
            labels = spiky.stat.Labels(t);
            %% Add counts and identity states
            counts = obj.Graph.getCounts();
            names = obj.Graph.getIdenties();
            labels = labels.addLabel(counts, Name="Count", Mode="state", Categorize=true);
            labels = labels.addLabel(names, Name="Name", Mode="state");
            %% Add transitions
            trans = obj.Graph.getTransitions();
            labels = labels.addLabel(trans(trans.IsAdd, "Change"), Name="EnterStart", Mode="trigger");
            labels = labels.addLabel(trans(trans.IsAdd, "Change"), Name="EnterName");
            labels = labels.addLabel(trans(~trans.IsAdd, "Change"), Name="LeaveStart", Mode="trigger");
            labels = labels.addLabel(trans(~trans.IsAdd, "Change"), Name="LeaveName");
            %% Add verbs
            verbs = obj.Graph.getVerbs();
            % labels = labels.addLabel(verbs, Name="Verb", Mode="state");
            labels = labels.addLabel(verbs(verbs.Data~="Idle", :), Name="ActionStart", Mode="trigger");
            labels = labels.addLabel(verbs(verbs.Data~="Idle", :), Name="Action");
            %% Add action roles
            actions = obj.Graph.Predicates.Name(obj.Graph.Predicates.Name~="Walk" & ...
                obj.Graph.Predicates.Type=="Verb");
            isAction = ismember(obj.Graph.Predicate.Name, actions);
            ttSubjects = obj.Graph(isAction, "Subject").toEventsTable("start");
            ttSubjects.Data = ttSubjects.Subject.Name;
            ttObjects = obj.Graph(isAction, "Object").toEventsTable("start");
            ttObjects.Data = ttObjects.Object.Name;
            dataActions = obj.Graph.Predicate.Name(isAction);
            for ii = 1:numel(actions)
                labels = labels.addLabel(ttSubjects(dataActions==actions(ii), :), ...
                    Name=string(actions(ii))+"SubjectName");
                labels = labels.addLabel(ttObjects(dataActions==actions(ii), :), ...
                    Name=string(actions(ii))+"ObjectName");
            end
            %% Add fixations
            fix = obj.Fix(obj.Fix.IsFace, :);
            fix.Data.ActionRole = categorical(string(fix.Verb)+string(fix.Role));
            labels = labels.addLabel(obj.Fix.Start, Name="FixStart", Mode="trigger");
            labels = labels.addLabel(fix(:, "Name"), Name="FixName");
            labels = labels.addLabel(fix(:, "OtherName"), Name="FixOtherName");
            % labels = labels.addLabel(fix(:, "Verb"), Name="FixVerb");
            labels = labels.addLabel(fix(:, "ActionRole"), Name="FixActionRole");
        end

        function [zetaTests, idcZeta] = getZetaTests(obj, spikes, options)
            %GETZETATEST Get zeta tests for the paradigm
            arguments
                obj spiky.par.ActionTheater
                spikes spiky.core.Spikes
                options.Recalculate (1, 1) logical = false
                options.Alpha (1, 1) double = 1e-3
                options.MaxEvents (1, 1) double = 2000
            end
            fpth = obj.Session.getFpth("ActionTheater.Zeta.mat");
            if exist(fpth, "file") && ~options.Recalculate
                tmp = load(fpth, "zetaTests");
                zetaTests = tmp.zetaTests;
                names = string(fieldnames(zetaTests));
                unitsAll = zetaTests.(names(1)).Groups;
                units = vertcat(spikes.Neuron);
                isValid = ismember(string(unitsAll), string(units));
                for ii = 1:length(names)
                    z = zetaTests.(names(ii));
                    zetaTests.(names(ii)) = z(:, isValid);
                end
            else
                zetaTests = struct();
                idcVis = find(obj.Graph.IsVisibility);
                idcVis = idcVis(1:min(end, options.MaxEvents));
                zetaTests.Enter = spikes.zeta(obj.Graph.Time(idcVis, 1), 1);
                zetaTests.Leave = spikes.zeta(obj.Graph.Time(idcVis, 2), 1);
                idcWalk = find(obj.Graph.IsVerb & obj.Graph.Predicate.Name=="Walk");
                idcWalk = idcWalk(1:min(end, options.MaxEvents));
                zetaTests.Walk = spikes.zeta(obj.Graph.Predicate.Time(idcWalk, 1), 1);
                idcAction = find(obj.Graph.IsVerb & obj.Graph.Predicate.Name~="Walk");
                idcAction = idcAction(1:min(end, options.MaxEvents));
                zetaTests.Action = spikes.zeta(obj.Graph.Predicate.Time(idcAction, 1), 1);
                idcFix = find(obj.Fix.IsFace);
                idcFix = idcFix(1:min(end, options.MaxEvents));
                zetaTests.Fix = spikes.zeta(obj.Fix.Time(idcFix), 1);
                save(fpth, "zetaTests");
            end
            if nargout>1
                idcZeta = structfun(@(x) find(x.P<options.Alpha)', zetaTests, UniformOutput=false);
                idcZetaAll = struct2cell(idcZeta);
                idcZetaAll = unique(vertcat(idcZetaAll{:}));
                idcZeta.All = idcZetaAll;
            end
        end

        function trigCounts = trigCounts(obj, spikes, res)
            %TRIGCOUNTS Count spikes during the paradigm
            %   trigCounts = trigCounts(obj, spikes, res)
            %
            %   spikes: spiky.core.Spikes object
            %   res: resolution of the counts
            %
            %   trigCounts: 1xnTxnNeuron spike counts at each time point within the paradigm
            
            arguments
                obj spiky.par.ActionTheater
                spikes spiky.core.Spikes
                res double = 0.05
            end
            t1 = ceil(obj.Intervals.Time(1)/res)*res;
            t = t1:res:obj.Intervals.Time(end);
            trigCounts = spikes.trigCounts(t1, t);
        end

        function [trigFr, parFr] = trigFr(obj, spikes, res, halfWidth, kernel, normalize)
            %TRIGFR Firing rate during the paradigm
            %   trigFr = trigFr(obj, spikes, res, halfWidth, kernel, normalize)
            %
            %   spikes: spiky.core.Spikes object
            %   res: resolution of the firing rate
            %   halfWidth: half width of the kernel
            %   kernel: kernel function (default: "gaussian")
            %   normalize: whether to normalize the firing rate (default: true)
            %
            %   trigFr: 1xnTxnNeuron firing rate at each time point within the paradigm
            %   parFr: nTx1xnNeuron continuous firing rate from the beginning to the end, useful for
            %       time-based operations
            
            arguments
                obj spiky.par.ActionTheater
                spikes spiky.core.Spikes
                res double = 0.05
                halfWidth double = 0.1
                kernel string {mustBeMember(kernel, ["gaussian", "box"])} = "gaussian"
                normalize logical = true
            end
            
            t1 = ceil(obj.Intervals.Time(1)/res)*res;
            t = t1:res:obj.Intervals.Time(end);
            [t2, idcT] = obj.Intervals.haveEvents(t);
            parFr = spikes.trigFr(t1, t, HalfWidth=halfWidth, Kernel=kernel, Normalize=normalize);
            trigFr = parFr(idcT, :, :);
            trigFr.Data = permute(trigFr.Data, [2 1 3]);
            trigFr.Time = 0;
            trigFr.Events_ = t2;
            trigFr.Window = [0 res];
        end
    end
end