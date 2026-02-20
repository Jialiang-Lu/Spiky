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
            trHuman = tr(tr.IsHuman);
            intvlTrHuman = vertcat(trHuman.Interval);
            trials = obj.Trials;
            ti = obj.TrialInfo;
            ti = ti(ismember(ti.Number, trials.Number), :);
            t1 = ti.Time(1);
            fGetVar = @(x) categorical(extractBefore(x.get(t1)', " "));
            adjs = fGetVar(obj.Vars.Adjs);
            actors = fGetVar(obj.Vars.Actors);
            targets = fGetVar(obj.Vars.Targets);
            singleActions = fGetVar(obj.Vars.SingleActions);
            doubleActions = fGetVar(obj.Vars.Actions);
            indirectActions = fGetVar(obj.Vars.IndirectActions);
            actionAdjs = fGetVar(obj.Vars.ActionAdjs);
            actionAdjTargets = fGetVar(obj.Vars.ActionAdjTargets);
            actionAdjTargetAdjs = fGetVar(obj.Vars.ActionAdjTargetAdjs);
            %% Preprocessing
            isVersion1 = ismember("Type", ti.VarNames);
            isVersion2 = ismember("SubjectType", ti.VarNames) && ismember("Human", ti.SubjectType);
            isVersion3 = ~isVersion1 && ~isVersion2;
            if isVersion1
                %% Old version
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
                tiAction(ti.Type=="HumanHuman") = doubleActions(ti.Action(ti.Type=="HumanHuman")+1);
                tiAction(ti.Type=="HumanObject") = singleActions(ti.Action(ti.Type=="HumanObject")+1);
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
            elseif isVersion2
                %% New version
                [~, idcUnique] = unique(ti{:, ["Id" "IsStart"]}, "rows", "stable");
                ti = ti(idcUnique, :);
                tmp = categorical(strings(height(ti), 1));
                %% Subject
                isHuman = ti.SubjectType=="Human";
                tiSubjectName = tmp;
                tiSubjectName(isHuman) = actors(ti.SubjectName(isHuman)+1);
                tiSubjectName(~isHuman) = actionAdjTargets(ti.SubjectName(~isHuman)+1);
                ti.SubjectName = tiSubjectName;
                %% Object
                isObjActor = ti.ObjectType=="Human";
                isObjObject = ti.ObjectType=="Object";
                isObjAdj = ti.ObjectType=="Adj";
                tiObjectName = tmp;
                tiObjectName(isObjActor) = actors(ti.ObjectName(isObjActor)+1);
                tiObjectName(isObjObject) = actionAdjTargets(ti.ObjectName(isObjObject)+1);
                tiObjectName(isObjAdj & isHuman) = adjs(ti.ObjectName(isObjAdj & isHuman)+1);
                tiObjectName(isObjAdj & ~isHuman) = actionAdjTargetAdjs(ti.ObjectName(isObjAdj & ~isHuman)+1);
                ti.ObjectName = tiObjectName;
                %% Direct Object
                isDirectObject = ti.DirectObjectType=="Object";
                tiDirectObjectName = tmp;
                tiDirectObjectName(isDirectObject) = actionAdjTargets(ti.DirectObjectName(isDirectObject)+1);
                ti.DirectObjectName = tiDirectObjectName;
                %% Action
                isSingleAction = ti.PredicateType=="SingleAction";
                isDoubleAction = ti.PredicateType=="Action";
                isActionAdj = ti.PredicateType=="ActionAdj";
                isIndirectAction = ti.PredicateType=="IndirectAction";
                tiAction = tmp;
                % tiAction(isSingleAction) = singleActions(ti.PredicateName(isSingleAction)+1);
                tiAction(isSingleAction) = singleActions(1);
                tiAction(isDoubleAction) = doubleActions(ti.PredicateName(isDoubleAction)+1);
                tiAction(isActionAdj) = actionAdjs(ti.PredicateName(isActionAdj)+1);
                tiAction(isIndirectAction) = indirectActions(ti.PredicateName(isIndirectAction)+1);
                ti.PredicateName = tiAction;
            elseif isVersion3
                %% Latest version
                %% Fix bug 1
                idcFix = find(ti.SubjectId>0);
                if ~isempty(idcFix)
                    idcFixNew = zeros(size(idcFix));
                    tiNumber = ti.Number;
                    tiIsStart = ti.IsStart;
                    tiName = ti.SubjectName;
                    tiId = ti.SubjectId;
                    for ii = 1:numel(idcFix)
                        idc = idcFix(ii);
                        idcNew = find(tiNumber(idc+1:end)==tiNumber(idc) & ...
                            tiIsStart(idc+1:end)==tiIsStart(idc) & ...
                            tiName(idc+1:end)==tiName(idc), 1, "first");
                        tiId(idc) = tiId(idc+idcNew);
                    end
                    ti.SubjectId = tiId;
                end
                %% Fix bug 2
                idcFix = find(ti.PredicateType=="IndirectAction" & ti.ObjectType=="Target");
                if ~isempty(idcFix)
                    ti.ObjectType(idcFix) = "Actor";
                end
                %% 
                idcUnique = ismember(ti.Id, ti.Id(~ti.IsStart));
                ti = ti(idcUnique);
                tmp = categorical(strings(height(ti), 1));
                %% Subject
                tiSubjectName = tmp;
                isActor = ti.SubjectType=="Actor";
                isTarget = ti.SubjectType=="Target";
                isActionAdjTarget = ti.SubjectType=="ActionAdjTarget";
                tiSubjectName(isActor) = actors(ti.SubjectName(isActor)+1);
                tiSubjectName(isTarget) = targets(ti.SubjectName(isTarget)+1);
                tiSubjectName(isActionAdjTarget) = actionAdjTargets(ti.SubjectName(isActionAdjTarget)+1);
                ti.SubjectName = tiSubjectName;
                %% Object
                tiObjectName = tmp;
                isObjActor = ti.ObjectType=="Actor";
                isObjTarget = ti.ObjectType=="Target";
                isObjAdj = ti.ObjectType=="Adj";
                isObjActionAdjTarget = ti.ObjectType=="ActionAdjTarget";
                tiObjectName(isObjActor) = actors(ti.ObjectName(isObjActor)+1);
                tiObjectName(isObjTarget) = targets(ti.ObjectName(isObjTarget)+1);
                tiObjectName(isObjActionAdjTarget) = actionAdjTargets(ti.ObjectName(isObjActionAdjTarget)+1);
                tiObjectName(isObjAdj & isActor) = adjs(ti.ObjectName(isObjAdj & isActor)+1);
                tiObjectName(isObjAdj & ~isActor) = actionAdjTargetAdjs(ti.ObjectName(isObjAdj & ~isActor)+1);
                ti.ObjectName = tiObjectName;
                %% Direct Object
                isDirectObject = ti.DirectObjectType=="Target";
                tiDirectObjectName = tmp;
                tiDirectObjectName(isDirectObject) = actionAdjTargets(ti.DirectObjectName(isDirectObject)+1);
                ti.DirectObjectName = tiDirectObjectName;
                %% Action
                isSingleAction = ti.PredicateType=="SingleAction";
                isDoubleAction = ti.PredicateType=="Action";
                isActionAdj = ti.PredicateType=="ActionAdj";
                isIndirectAction = ti.PredicateType=="IndirectAction";
                tiAction = tmp;
                % tiAction(isSingleAction) = singleActions(ti.PredicateName(isSingleAction)+1);
                tiAction(isSingleAction) = singleActions(1);
                tiAction(isDoubleAction) = doubleActions(ti.PredicateName(isDoubleAction)+1);
                tiAction(isActionAdj) = actionAdjs(ti.PredicateName(isActionAdj)+1);
                tiAction(isIndirectAction) = indirectActions(ti.PredicateName(isIndirectAction)+1);
                ti.PredicateName = tiAction;
            end
            %% Visibility of each entity
            itvTrials = spiky.core.Intervals(obj.Trials{:, ["Move" "End"]}); 
            itvTrials.Time(1) = 0; 
            itvTrials.Time(end) = Inf;
            vis = {tr.Visible}';
            idcVis = find(cellfun(@any, vis));
            nVis = numel(idcVis);
            vis = vis(idcVis);
            idcStart = cellfun(@(x) find(x, 1, "first"), vis);
            idcEnd = cellfun(@(x) find(x, 1, "last"), vis);
            tr = tr(idcVis);
            names = categorical(tr.Name);
            types = strings(nVis, 1);
            isHuman = tr.IsHuman;
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
            nodesVis = spiky.scene.SceneNode(per, names, types, tr.Id, pos, rot, proj);
            if isVersion1
                nodesAdj = spiky.scene.SceneNode;
            else
                tiAdj = ti(ismissing(ti.PredicateName) & ti.ObjectType=="Adj" & ti.IsStart, :);
                [idcVisInAdj, idcAdjInVis] = ismember(tr.Id, tiAdj.SubjectId);
                idcAdjInVis = idcAdjInVis(idcVisInAdj);
                nodesVis = nodesVis(idcVisInAdj);
                nodesAdj = spiky.scene.SceneNode(nodesVis.Time, tiAdj.ObjectName(idcAdjInVis), ...
                    "Adj", tiAdj.ObjectId(idcAdjInVis), nodesVis.Pos, nodesVis.Rot, nodesVis.Proj);
            end
            [~, ~, idcStart] = itvTrials.haveEvents(nodesVis.Time(:, 1));
            [~, ~, idcEnd] = itvTrials.haveEvents(nodesVis.Time(:, 2));
            graphVis = spiky.scene.SceneGraph(nodesVis.Time, ...
                obj.Trials.Number(idcStart), obj.Trials.Number(idcEnd), nodesVis, [], nodesAdj);
            graphVis.Time = graphVis.Time+obj.Latency;
            %% Walk
            per = trials{:, ["Move" "Wait"]};
            tWalk = mean(per, 2);
            [~, idcTrialWalk, idcTrWalk] = intvlTrHuman.haveEvents(tWalk);
            trWalk = trHuman(idcTrWalk);
            per = per(idcTrialWalk, :);
            posWalk = trWalk.getPos("Root", per(:, 1)+0.01);
            rotWalk = trWalk.getRot("Root", per(:, 1)+0.01);
            projWalk = trWalk.getProj("Root", per(:, 1)+0.01);
            nodesWalk = spiky.scene.SceneNode(per, trWalk.Name, ...
                "Humanoid", trWalk.Id, posWalk, rotWalk, projWalk);
            nodesWalkVerb = spiky.scene.SceneNode(per, "Walk", ...
                "Verb", 0, posWalk, rotWalk, projWalk);
            [~, ~, idcEnd] = itvTrials.haveEvents(per(:, 2));
            graphWalk = spiky.scene.SceneGraph(per, obj.Trials.Number(idcEnd), ...
                obj.Trials.Number(idcEnd), nodesWalk, nodesWalkVerb);
            %% Idle
            if isVersion1
                isIdle = ~ismissing(ti.Actor) & ti.Action=="Idle" & ti.Role=="Source";
                nIdle = sum(isIdle);
                tiIdle = ti(isIdle, :);
                [~, idcIdleTrial] = ismember(ti.Number(isIdle), trials.Number);
                per = trials{idcIdleTrial, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, tiIdle.Actor, "Humanoid", ...
                    tiIdle.Id, tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
                nodesVerb = spiky.scene.SceneNode(per, "Idle", "Verb", 0, ...
                    tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
            else
                isIdle = ti.PredicateName=="Idle" & ti.IsStart;
                tiIdle = ti(isIdle, :);
                [~, idcIdleTrial] = ismember(ti.Number(isIdle), trials.Number);
                per = trials{idcIdleTrial, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, tiIdle.SubjectName, "Humanoid", ...
                    tiIdle.SubjectId, tiIdle.SubjectPos, tiIdle.SubjectRot, tiIdle.SubjectProj);
                nodesVerb = spiky.scene.SceneNode(per, "Idle", "Verb", 0, ...
                    tiIdle.SubjectPos, tiIdle.SubjectRot, tiIdle.SubjectProj);
            end
            [~, ~, idcStart] = itvTrials.haveEvents(per(:, 1));
            graphIdle = spiky.scene.SceneGraph(per, obj.Trials.Number(idcStart), ...
                obj.Trials.Number(idcStart), nodesSubject, nodesVerb);
            %% Action
            if isVersion1
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
                per = trials{idcActionTrial, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, ti.Actor(idcSource), "Humanoid", ...
                    ti.Id(idcSource), ti.Pos(idcSource, :), ti.Rot(idcSource, :), ti.Proj(idcSource, :));
                nodesObject = spiky.scene.SceneNode(per, ti.Actor(idcTarget), "Humanoid", ...
                    ti.Id(idcTarget), ti.Pos(idcTarget, :), ti.Rot(idcTarget, :), ti.Proj(idcTarget, :));
                nodesVerb = spiky.scene.SceneNode(per, tiActions.Action, "Verb", ...
                    tiActions.Id, tiActions.Pos, tiActions.Rot, tiActions.Proj);
                nodesIndirect = spiky.scene.SceneNode.uniform(height(per));
            else
                tiAction = ti(ismember(ti.PredicateType, ["Action" "IndirectAction"]) & ti.IsStart, :);
                [idcActionInTrial, idcTrialInAction] = ismember(tiAction.Number, trials.Number);
                tiAction = tiAction(idcActionInTrial, :);
                tiAction.ObjectType(tiAction.ObjectType=="Actor") = "Humanoid";
                tiAction.ObjectType(tiAction.ObjectType=="Target") = "Object";
                idcTrialInAction = idcTrialInAction(idcActionInTrial);
                per = trials{idcTrialInAction, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, tiAction.SubjectName, "Humanoid", ...
                    tiAction.SubjectId, tiAction.SubjectPos, tiAction.SubjectRot, tiAction.SubjectProj);
                nodesObject = spiky.scene.SceneNode(per, tiAction.ObjectName, ...
                    tiAction.ObjectType, tiAction.ObjectId, tiAction.ObjectPos, tiAction.ObjectRot, tiAction.ObjectProj);
                nodesVerb = spiky.scene.SceneNode(per, tiAction.PredicateName, "Verb", ...
                    tiAction.Id, tiAction.PredicatePos, tiAction.PredicateRot, tiAction.PredicateProj);
                isIndirectAction = tiAction.PredicateType=="IndirectAction" & tiAction.IsStart;
                nodesIndirect = spiky.scene.SceneNode.uniform(height(per));
                nodesIndirect(isIndirectAction) = spiky.scene.SceneNode(per(isIndirectAction, :), ...
                    tiAction.DirectObjectName(isIndirectAction), "Object", ...
                    tiAction.DirectObjectId(isIndirectAction), ...
                    tiAction.DirectObjectPos(isIndirectAction, :), ...
                    tiAction.DirectObjectRot(isIndirectAction, :), ...
                    tiAction.DirectObjectProj(isIndirectAction, :));
            end
            [~, ~, idcStart] = itvTrials.haveEvents(per(:, 1));
            graphAction = spiky.scene.SceneGraph(per, obj.Trials.Number(idcStart), ...
                obj.Trials.Number(idcStart), nodesSubject, nodesVerb, nodesObject, nodesIndirect);
            %% ActionAdj
            if isVersion1 || isVersion2
                graphActionAdj = spiky.scene.SceneGraph;
            else
                tiActionAdj = sortrows(ti(ti.PredicateType=="ActionAdj", :), ["Id", "IsStart"], ...
                    ["ascend", "descend"]);
                per = reshape(tiActionAdj.Time, 2, [])';
                tiActionAdj = tiActionAdj(tiActionAdj.IsStart, :);
                nodesSubject = spiky.scene.SceneNode(per, tiActionAdj.SubjectName, "Humanoid", ...
                    tiActionAdj.SubjectId, tiActionAdj.SubjectPos, tiActionAdj.SubjectRot, tiActionAdj.SubjectProj);
                nodesVerb = spiky.scene.SceneNode(per, tiActionAdj.PredicateName, "ActionAdj", ...
                    tiActionAdj.Id, tiActionAdj.PredicatePos, tiActionAdj.PredicateRot, tiActionAdj.PredicateProj);
                nodesObject = spiky.scene.SceneNode(per, tiActionAdj.ObjectName, "Object", ...
                    tiActionAdj.ObjectId, tiActionAdj.ObjectPos, tiActionAdj.ObjectRot, tiActionAdj.ObjectProj);
                [~, ~, idcStart] = itvTrials.haveEvents(per(:, 1));
                [~, ~, idcEnd] = itvTrials.haveEvents(per(:, 2));
                graphActionAdj = spiky.scene.SceneGraph(per, obj.Trials.Number(idcStart), ...
                    obj.Trials.Number(idcEnd), nodesSubject, nodesVerb, nodesObject);
            end
            %%
            obj.TrialInfo = ti;
            obj.Graph = [graphVis; graphWalk; graphAction; graphIdle; graphActionAdj];
            obj.Graph = obj.Graph.sort();
            %% Fixations
            fix = minos.Eye.FixationTargets;
            fix = fix(fix.Start>=obj.Intervals.Time(1) & fix.End<=obj.Intervals.Time(end) & ...
                fix.Trial>=obj.Trials.Number(1) & fix.Trial<=obj.Trials.Number(end), :);
            fix.Data.IsFace = ~ismissing(fix.Name) & fix.MinAngle<8 & ismember(fix.Part, ...
                [spiky.minos.BodyPart.Head spiky.minos.BodyPart.UpperChest ...
                spiky.minos.BodyPart.Hip ...
                spiky.minos.BodyPart.LeftArm spiky.minos.BodyPart.RightArm ...
                spiky.minos.BodyPart.LeftHand spiky.minos.BodyPart.RightHand]);
            fix = fix(fix.IsFace, :);
            nFix = height(fix);
            %% Fixation sequences
            idcNameGroup = findgroups(fix.Name);
            isNameChange = [true; diff(idcNameGroup)~=0];
            idcSeq = zeros(nFix, 1);
            idcInSeq = zeros(nFix, 1);
            seqLength = zeros(nFix, 1);
            for ii = 1:max(idcNameGroup)
                idc1 = idcNameGroup==ii;
                [idcSeq(idc1), idcInSeq(idc1), seqLength(idc1)] = fix(idc1, :).findSequence(0.2, ...
                    IdcJump=isNameChange(idc1));
            end
            idcSeq = fix.Name.*categorical(idcSeq);
            [~, ~, idcSeq] = unique(idcSeq, "stable");
            fix.Data.IdcSeq = idcSeq;
            fix.Data.IdcInSeq = idcInSeq;
            fix.Data.SeqLength = seqLength;
            %% Find prev fixation
            prevName = categorical(NaN(nFix, 1));
            prevName(2:end) = fix.Name(1:end-1);
            fix.Data.PrevName = prevName;
            prevSeqName = categorical(NaN(nFix, 1));
            idcFirst = find(idcInSeq==1);
            [hasPrevSeq, idcPrevSeq] = ismember(idcSeq-1, idcSeq(idcFirst));
            prevSeqName(hasPrevSeq) = fix.Name(idcFirst(idcPrevSeq(hasPrevSeq)));
            fix.Data.PrevSeqName = prevSeqName;
            %% Find fixation role
            graphVerb = obj.Graph(obj.Graph.IsVerb, :);
            [~, idcFixVerb, idcVerbFix] = graphVerb.haveEvents(fix.Start);
            isFixSubject = fix.Id(idcFixVerb)==graphVerb.Subject.Id(idcVerbFix) | ...
                ismember(graphVerb.Predicate.Name(idcVerbFix), ["Walk" "Idle"]);
            isFixObject = fix.Id(idcFixVerb)==graphVerb.Object.Id(idcVerbFix);
            fix.Data.Role = categorical(NaN(nFix, 1));
            fix.Role(idcFixVerb(isFixSubject)) = "Subject";
            fix.Role(idcFixVerb(isFixObject)) = "Object";
            isAction = graphVerb.Predicate.Type(idcVerbFix)=="Action" & ...
                ~ismember(graphVerb.Predicate.Name(idcVerbFix), ["Walk" "Idle"]);
            fix.Data.OtherRole = categorical(NaN(nFix, 1));
            fix.OtherRole(idcFixVerb(isAction & isFixSubject)) = "Object";
            fix.OtherRole(idcFixVerb(isAction & isFixObject)) = "Subject";
            fix.Data.Verb = categorical(NaN(nFix, 1));
            fix.Verb(idcFixVerb) = graphVerb.Predicate.Name(idcVerbFix);
            fix.Data.Action = fix.Verb;
            fix.Action(ismember(fix.Action, ["Walk" "Idle"])) = missing;
            fix.Verb(ismissing(fix.Verb)) = "Wait";
            fix.Data.ActionRole = categorical(string(fix.Action)+string(fix.Role));
            fix.Data.OtherActionRole = categorical(string(fix.Action)+string(fix.OtherRole));
            fix.Data.NActors = cellfun(@numel, fix.Names);
            %% Find fixated actionadj
            graphActionAdj = obj.Graph(obj.Graph.IsActionAdj, :).interpById(fix.Id, fix.Start+0.02);
            graphActionAdjTarget = obj.Graph(obj.Graph.IsAttribute & ...
                obj.Graph.Subject.Type=="Object").interpById(graphActionAdj.Object.Id);
            fix.Data.ActionAdj = graphActionAdj.Predicate.Name;
            fix.Data.ActionAdjTarget = graphActionAdjTarget.Subject.Name;
            fix.Data.ActionAdjTargetAdj = graphActionAdjTarget.Object.Name;
            %% Time after action start
            idcAction = find(~ismissing(fix.Action));
            trialsAction = unique(fix.Trial(idcAction));
            [isValid, idcInGraph] = ismember(trialsAction, graphAction.TrialStart);
            trialsAction = trialsAction(isValid);
            tAction = graphAction.Time(idcInGraph(isValid), 1);
            [isInActionTrial, idcFixInActionTrial] = ismember(fix.Trial, trialsAction);
            timeAfterAction = NaN(nFix, 1);
            timeAfterAction(isInActionTrial) = fix.Start(isInActionTrial)-tAction(idcFixInActionTrial(isInActionTrial));
            fix.Data.TimeAfterAction = timeAfterAction;
            %% Assign roles before and after action
            trialsAction = fix.Trial(idcAction);
            idcBeforeAction = find(ismember(fix.Trial, trialsAction) & ismissing(fix.Action));
            idcAfterAction = find(ismember(fix.Trial, trialsAction+1) & ismissing(fix.Action));
            roleBeforeAction = categorical(NaN(nFix, 1));
            roleAfterAction = categorical(NaN(nFix, 1));
            actionBeforeAction = categorical(NaN(nFix, 1));
            actionAfterAction = categorical(NaN(nFix, 1));
            keyAction = [fix.Trial(idcAction) fix.Id(idcAction)];
            [~, ia] = unique(keyAction, "rows", "stable");
            keyActionFirst = keyAction(ia, :);
            idcActionFirst = idcAction(ia);
            keyBefore = [fix.Trial(idcBeforeAction) fix.Id(idcBeforeAction)];
            [isMatchBefore, idcBeforeInAction] = ismember(keyBefore, keyActionFirst, "rows");
            idcBeforeActionValid = idcBeforeAction(isMatchBefore);
            idcActionBefore = idcActionFirst(idcBeforeInAction(isMatchBefore));
            roleBeforeAction(idcBeforeActionValid) = fix.Role(idcActionBefore);
            actionBeforeAction(idcBeforeActionValid) = fix.Action(idcActionBefore);
            keyAfter = [fix.Trial(idcAfterAction)-1 fix.Id(idcAfterAction)];
            [isMatchAfter, idcAfterInAction] = ismember(keyAfter, keyActionFirst, "rows");
            idcAfterActionValid = idcAfterAction(isMatchAfter);
            idcActionAfter = idcActionFirst(idcAfterInAction(isMatchAfter));
            roleAfterAction(idcAfterActionValid) = fix.Role(idcActionAfter);
            actionAfterAction(idcAfterActionValid) = fix.Action(idcActionAfter);
            fix.Data.RoleBeforeAction = roleBeforeAction;
            fix.Data.RoleAfterAction = roleAfterAction;
            fix.Data.ActionBeforeAction = actionBeforeAction;
            fix.Data.ActionAfterAction = actionAfterAction;
            %% Randomize role for handshake
            idcHandshake = find(fix.Action=="Handshake");
            nHandshake = numel(idcHandshake);
            idcSwap = rand(nHandshake, 1)<0.5;
            fix.Role(idcHandshake(idcSwap)) = "Object";
            fix.Role(idcHandshake(~idcSwap)) = "Subject";
            idcHandshake = find(fix.ActionBeforeAction=="Handshake");
            nHandshake = numel(idcHandshake);
            idcSwap = rand(nHandshake, 1)<0.5;
            fix.RoleBeforeAction(idcHandshake(idcSwap)) = "Object";
            fix.RoleBeforeAction(idcHandshake(~idcSwap)) = "Subject";
            idcHandshake = find(fix.ActionAfterAction=="Handshake");
            nHandshake = numel(idcHandshake);
            idcSwap = rand(nHandshake, 1)<0.5;
            fix.RoleAfterAction(idcHandshake(idcSwap)) = "Object";
            fix.RoleAfterAction(idcHandshake(~idcSwap)) = "Subject";
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
                units = spikes.Neuron;
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