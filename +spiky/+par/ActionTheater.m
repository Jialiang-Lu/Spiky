classdef ActionTheater < spiky.par.Paradigm
    %ACTIONTHEATER represents a paradigm for the Action Theater

    properties
        Graph spiky.scene.SceneGraph % Scene graph representing the actions and interactions
        Fix spiky.core.IntervalsTable % Fixations during the paradigm
        FixSeq spiky.core.IntervalsTable % Sequences of fixations
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
            trials = obj.Data.Trials;
            ti = obj.Data.TrialInfo;
            ti = ti(ismember(ti.Number, trials.Number), :);
            t1 = ti.Time(1);
            fGetVar = @(x) categorical(erase(extractBefore(x.get(t1)', " "), digitsPattern+textBoundary));
            adjs = fGetVar(obj.Data.Vars.Adjs);
            actors = fGetVar(obj.Data.Vars.Actors);
            targets = fGetVar(obj.Data.Vars.Targets);
            singleActions = fGetVar(obj.Data.Vars.SingleActions);
            doubleActions = fGetVar(obj.Data.Vars.Actions);
            indirectActions = fGetVar(obj.Data.Vars.IndirectActions);
            actionAdjs = fGetVar(obj.Data.Vars.ActionAdjs);
            actionAdjTargets = fGetVar(obj.Data.Vars.ActionAdjTargets);
            actionAdjTargetAdjs = fGetVar(obj.Data.Vars.ActionAdjTargetAdjs);
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
                    actions3 = extractBefore(obj.Data.Vars.IndirectActions.get(t1)', " ");
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
                ti.SubjectType(isHuman) = "Humanoid";
                tiSubjectName = tmp;
                tiSubjectName(isHuman) = actors(ti.SubjectName(isHuman)+1);
                tiSubjectName(~isHuman) = actionAdjTargets(ti.SubjectName(~isHuman)+1);
                ti.SubjectName = tiSubjectName;
                %% Object
                isObjActor = ti.ObjectType=="Human";
                isObjObject = ti.ObjectType=="Object";
                ti.ObjectType(isObjActor) = "Humanoid";
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
                isIdle = ti.PredicateType=="SingleAction" & ti.PredicateName==-2;
                isSingleAction = ti.PredicateType=="SingleAction";
                isDoubleAction = ti.PredicateType=="Action";
                isActionAdj = ti.PredicateType=="ActionAdj";
                isIndirectAction = ti.PredicateType=="IndirectAction";
                tiAction = tmp;
                if any(ti.PredicateName(isSingleAction)>=0)
                    tiAction(isIdle) = "Idle";
                    tiAction(isSingleAction & ~isIdle) = singleActions(ti.PredicateName(isSingleAction & ~isIdle)+1);
                else
                    tiAction(isSingleAction) = singleActions(1);
                end
                tiAction(isDoubleAction) = doubleActions(ti.PredicateName(isDoubleAction)+1);
                tiAction(isActionAdj) = actionAdjs(ti.PredicateName(isActionAdj)+1);
                tiAction(isIndirectAction) = indirectActions(ti.PredicateName(isIndirectAction)+1);
                ti.PredicateName = tiAction;
            end
            %% Visibility of each entity
            itvTrials = spiky.core.Intervals(obj.Data.Trials{:, ["Move" "End"]}); 
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
            % pb = spiky.plot.ProgressBar(nVis, "Calculating visibility");
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
            [~, idcPer] = sort(per(:, 1));
            nodesVis = nodesVis(idcPer);
            tr = tr(idcPer);
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
            [~, idcHasStart, idcStart] = itvTrials.haveEvents(nodesVis.Time(:, 1));
            [~, idcHasEnd, idcEnd] = itvTrials.haveEvents(nodesVis.Time(:, 2), Sorted=false);
            trialStart = zeros(height(nodesVis), 1, "int32");
            trialEnd = zeros(height(nodesVis), 1, "int32");
            trialStart(idcHasStart) = int32(obj.Data.Trials.Number(idcStart));
            trialEnd(idcHasEnd) = int32(obj.Data.Trials.Number(idcEnd));
            trialStart(trialStart==0) = int32(obj.Data.Trials.Number(1));
            trialEnd(trialEnd==0) = int32(obj.Data.Trials.Number(end));
            graphVis = spiky.scene.SceneGraph(nodesVis.Time, ...
                trialStart, trialEnd, nodesVis, [], nodesAdj);
            graphVis.Time = graphVis.Time+obj.Data.Latency;
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
                "SingleVerb", 0, posWalk, rotWalk, projWalk);
            [~, ~, idcEnd] = itvTrials.haveEvents(per(:, 2), Sorted=false);
            graphWalk = spiky.scene.SceneGraph(per, obj.Data.Trials.Number(idcEnd), ...
                obj.Data.Trials.Number(idcEnd), nodesWalk, nodesWalkVerb, NActors=obj.Data.Trials.Move_Type(idcEnd));
            %% SingleAction
            if isVersion1
                isIdle = ~ismissing(ti.Actor) & ti.Action=="Idle" & ti.Role=="Source";
                nIdle = sum(isIdle);
                tiIdle = ti(isIdle, :);
                [~, idcIdleTrial] = ismember(ti.Number(isIdle), trials.Number);
                per = trials{idcIdleTrial, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, tiIdle.Actor, "Humanoid", ...
                    tiIdle.Id, tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
                nodesVerb = spiky.scene.SceneNode(per, "Idle", "SingleVerb", 0, ...
                    tiIdle.Pos, tiIdle.Rot, tiIdle.Proj);
            else
                isSingleAction = ti.PredicateType=="SingleAction" & ti.IsStart;
                tiSingle = ti(isSingleAction, :);
                [~, idcSingleActionTrial] = ismember(ti.Number(isSingleAction), trials.Number);
                per = trials{idcSingleActionTrial, ["Start" "End"]};
                nodesSubject = spiky.scene.SceneNode(per, tiSingle.SubjectName, "Humanoid", ...
                    tiSingle.SubjectId, tiSingle.SubjectPos, tiSingle.SubjectRot, tiSingle.SubjectProj);
                nodesVerb = spiky.scene.SceneNode(per, tiSingle.PredicateName, "SingleVerb", 0, ...
                    tiSingle.SubjectPos, tiSingle.SubjectRot, tiSingle.SubjectProj);
            end
            [~, ~, idcStart] = itvTrials.haveEvents(per(:, 1));
            graphSingle = spiky.scene.SceneGraph(per, obj.Data.Trials.Number(idcStart), ...
                obj.Data.Trials.Number(idcStart), nodesSubject, nodesVerb, NActors=obj.Data.Trials.Start_Type(idcStart));
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
                nodesVerb = spiky.scene.SceneNode(per, tiActions.Action, "DoubleVerb", ...
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
                nodesVerb = spiky.scene.SceneNode(per, tiAction.PredicateName, "DoubleVerb", ...
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
            graphAction = spiky.scene.SceneGraph(per, obj.Data.Trials.Number(idcStart), ...
                obj.Data.Trials.Number(idcStart), nodesSubject, nodesVerb, nodesObject, nodesIndirect, ...
                NActors=obj.Data.Trials.Start_Type(idcStart));
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
                [~, idcObjectAdj] = ismember(tiActionAdj.ObjectId, graphVis.Subject.Id);
                nodesObjectAdj = graphVis.Object(idcObjectAdj);
                [~, ~, idcStart] = itvTrials.haveEvents(per(:, 1));
                [~, ~, idcEnd] = itvTrials.haveEvents(per(:, 2));
                graphActionAdj = spiky.scene.SceneGraph(per, obj.Data.Trials.Number(idcStart), ...
                    obj.Data.Trials.Number(idcEnd), nodesSubject, nodesVerb, nodesObject, nodesObjectAdj);
            end
            %% Combine graphs and store in the object
            obj.Data.TrialInfo = ti;
            obj.Data.Graph = [graphVis; graphWalk; graphAction; graphSingle; graphActionAdj];
            obj.Data.Graph = obj.Data.Graph.sort();
            %% Fixations
            fix = minos.Eye.FixationTargets;
            if isempty(fix)
                return
            end
            fix = fix(fix.Start>=obj.Data.Intervals.Time(1) & fix.End<=obj.Data.Intervals.Time(end) & ...
                fix.Trial>=obj.Data.Trials.Number(1) & fix.Trial<=obj.Data.Trials.Number(end), :);
            fix.Data.IsFace = ~ismissing(fix.Name) & fix.MinAngle<8 & ismember(fix.Part, ...
                [spiky.minos.BodyPart.Head spiky.minos.BodyPart.UpperChest ...
                spiky.minos.BodyPart.Hip ...
                spiky.minos.BodyPart.LeftArm spiky.minos.BodyPart.RightArm ...
                spiky.minos.BodyPart.LeftHand spiky.minos.BodyPart.RightHand]);
            fix.Data = removevars(fix.Data, ["Gaze" "Proj" "TargetPos" "TargetProj"]);
            nFix = height(fix);
            %% Remove invalid fixations
            % fix = fix(fix.IsFace, :);
            fix.Id(~fix.IsFace) = 0;
            fix.Name(~fix.IsFace) = missing;
            fix.OtherId(~fix.IsFace) = 0;
            fix.OtherName(~fix.IsFace) = missing;
            fix.Part(~fix.IsFace) = spiky.minos.BodyPart.Root;
            %% Fixation sequences
            fix.Data.NActors = cellfun(@numel, fix.Names);
            idcNameGroup = findgroups(fix.Id);
            isNameChange = [true; diff(idcNameGroup)~=0];
            idcSeq = zeros(nFix, 1);
            idcInSeq = zeros(nFix, 1);
            seqLength = zeros(nFix, 1);
            for ii = 1:max(idcNameGroup)
                idc1 = idcNameGroup==ii;
                [idcSeq(idc1), idcInSeq(idc1), seqLength(idc1)] = fix(idc1, :).findSequence(0.3, ...
                    IdcJump=isNameChange(idc1));
            end
            idcSeq = categorical(fix.Id).*categorical(idcSeq);
            [~, ~, idcSeq] = unique(idcSeq, "stable");
            fix.Data.IdcSeq = idcSeq;
            fix.Data.IdcInSeq = idcInSeq;
            fix.Data.SeqLength = seqLength;
            %% Find prev fixation
            hasPrevFix = find(fix.Start(2:end)-fix.End(1:end-1)<0.3)+1;
            prevName = categorical(NaN(nFix, 1));
            prevName(2:end) = fix.Name(1:end-1);
            prevName(~hasPrevFix) = missing;
            fix.Data.PrevName = prevName;
            prevId = zeros(nFix, 1, "int32");
            prevId(2:end) = fix.Id(1:end-1);
            prevId(~hasPrevFix) = 0;
            fix.Data.PrevId = prevId;
            prevSeqName = categorical(NaN(nFix, 1));
            idcFirst = find(idcInSeq==1);
            [hasPrevSeq, idcPrevSeq] = ismember(idcSeq-1, idcSeq(idcFirst));
            prevSeqName(hasPrevSeq) = fix.Name(idcFirst(idcPrevSeq(hasPrevSeq)));
            fix.Data.PrevSeqName = prevSeqName;
            %% Find relative position of non-fixated
            hasOtherFix = find(fix.OtherId~=0);
            nOtherFix = numel(hasOtherFix);
            [~, idcThisInTr] = ismember(fix.Id(hasOtherFix), tr.Id);
            [~, idcOtherInTr] = ismember(fix.OtherId(hasOtherFix), tr.Id);
            parts = fix.Part(hasOtherFix);
            projThis = zeros(nOtherFix, 3, "single");
            projOther = zeros(nOtherFix, 3, "single");
            t1 = fix.Start(hasOtherFix)+0.02;
            tr1 = tr(idcThisInTr);
            tr2 = tr(idcOtherInTr);
            parfor ii = 1:nOtherFix
                projThis(ii, :) = tr1(ii).getProj(parts(ii), t1(ii));
                projOther(ii, :) = tr2(ii).getProj(parts(ii), t1(ii));
            end
            projRel = projOther-projThis;
            fix.Data.OtherProjRel = NaN(nFix, 3, "single");
            fix.Data.OtherProjRel(hasOtherFix, :) = projRel;
            %% Find fixation role
            graphVerb = obj.Data.Graph(obj.Data.Graph.IsVerb, :);
            [~, idcFixVerb, idcVerbFix] = graphVerb.haveEvents((fix.Start+fix.End)/2);
            % isValidVerb = ismember(idcFixVerb, find(fix.IsFace));
            % idcFixVerb = idcFixVerb(isValidVerb);
            % idcVerbFix = idcVerbFix(isValidVerb);
            isFixSubject = fix.Id(idcFixVerb)==graphVerb.Subject.Id(idcVerbFix) & fix.Id(idcFixVerb)~=0;
            isFixObject = fix.Id(idcFixVerb)==graphVerb.Object.Id(idcVerbFix) & fix.Id(idcFixVerb)~=0;
            fix.Data.Role = categorical(NaN(nFix, 1));
            fix.Role(idcFixVerb(isFixSubject)) = "Subject";
            fix.Role(idcFixVerb(isFixObject)) = "Object";
            isAction = graphVerb.Predicate.Type(idcVerbFix)=="Action" & ...
                ~ismember(graphVerb.Predicate.Name(idcVerbFix), ["Walk" "Wait"]);
            fix.Data.OtherRole = categorical(NaN(nFix, 1));
            fix.OtherRole(idcFixVerb(isAction & isFixSubject)) = "Object";
            fix.OtherRole(idcFixVerb(isAction & isFixObject)) = "Subject";
            fix.Data.Verb = categorical(NaN(nFix, 1));
            fix.Verb(idcFixVerb) = graphVerb.Predicate.Name(idcVerbFix);
            fix.Data.Action = fix.Verb;
            fix.Action(ismember(fix.Action, ["Walk" "Wait" "Idle"])) = missing;
            fix.Role(ismissing(fix.Action)) = missing;
            fix.Verb(ismissing(fix.Verb)) = "Wait";
            fix.Data.ActionRole = categorical(string(fix.Action)+string(fix.Role));
            fix.Data.VerbRole = fix.ActionRole;
            fix.VerbRole(ismember(fix.Action, "Idle")) = "IdleSubject";
            fix.Data.OtherActionRole = categorical(string(fix.Action)+string(fix.OtherRole));
            prevVerb = categorical(NaN(nFix, 1));
            prevVerb(2:end) = fix.Verb(1:end-1);
            prevVerb(~hasPrevFix) = missing;
            fix.Data.PrevVerb = prevVerb;
            %% Find fixated actionadj
            graphActionAdj = obj.Data.Graph(obj.Data.Graph.IsActionAdj, :).interpById(fix.Id, fix.Start+0.02);
            graphActionAdjTarget = obj.Data.Graph(obj.Data.Graph.IsAttribute & ...
                obj.Data.Graph.Subject.Type=="Object").interpById(graphActionAdj.Object.Id);
            fix.Data.ActionAdj = graphActionAdj.Predicate.Name;
            fix.Data.ActionAdjTarget = graphActionAdjTarget.Subject.Name;
            fix.Data.ActionAdjTargetAdj = graphActionAdjTarget.Object.Name;
            isOther = fix.OtherId~=0;
            graphActionAdjOther = obj.Data.Graph(obj.Data.Graph.IsActionAdj, :).interpById(...
                fix.OtherId(isOther), fix.Start(isOther)+0.02);
            graphActionAdjOtherTarget = obj.Data.Graph(obj.Data.Graph.IsAttribute & ...
                obj.Data.Graph.Subject.Type=="Object").interpById(graphActionAdjOther.Object.Id);
            fix.Data.OtherActionAdj = categorical(NaN(nFix, 1));
            fix.OtherActionAdj(isOther) = graphActionAdjOther.Predicate.Name;
            fix.Data.OtherActionAdjTarget = categorical(NaN(nFix, 1));
            fix.OtherActionAdjTarget(isOther) = graphActionAdjOtherTarget.Subject.Name;
            fix.Data.OtherActionAdjTargetAdj = categorical(NaN(nFix, 1));
            fix.OtherActionAdjTargetAdj(isOther) = graphActionAdjOtherTarget.Object.Name;
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
            %% Randomize role for systematic actions (HandShake)
            idcSym = find(ismember(fix.Action, ["HandShake"]));
            nSym = numel(idcSym);
            if nSym>0
                idcSwap = rand(nSym, 1)<0.5;
                fix.Role(idcSym(idcSwap)) = "Object";
                fix.Role(idcSym(~idcSwap)) = "Subject";
                fix.OtherRole(idcSym(idcSwap)) = "Subject";
                fix.OtherRole(idcSym(~idcSwap)) = "Object";
                fix.ActionRole = categorical(string(fix.Action)+string(fix.Role));
                fix.OtherActionRole = categorical(string(fix.Action)+string(fix.OtherRole));
                idcSym = find(ismember(fix.ActionBeforeAction, ["HandShake"]));
                nSym = numel(idcSym);
                idcSwap = rand(nSym, 1)<0.5;
                fix.RoleBeforeAction(idcSym(idcSwap)) = "Object";
                fix.RoleBeforeAction(idcSym(~idcSwap)) = "Subject";
                idcSym = find(ismember(fix.ActionAfterAction, ["HandShake"]));
                nSym = numel(idcSym);
                idcSwap = rand(nSym, 1)<0.5;
                fix.RoleAfterAction(idcSym(idcSwap)) = "Object";
                fix.RoleAfterAction(idcSym(~idcSwap)) = "Subject";
            end
            %%
            obj.Data.Fix = fix;
            %% Fixation sequences
            fixSeq = fix(fix.IdcInSeq==1, :);
            fixSeq.Time(:, 2) = fix(fix.IdcInSeq==fix.SeqLength, :).End;
            obj.Data.FixSeq = fixSeq;
        end

        function fr = getActionFr(obj, spikes, t, options)
            arguments
                obj spiky.par.ActionTheater
                spikes spiky.core.Spikes
                t (:, 1) double = -0.3:0.1:1.8
                options.HalfWidth (1, 1) double = 0.15
                options.MaxGap (1, 1) double = 0.3
            end
            idcStart = obj.Data.Fix.IdcInSeq==1;
            idcEnd = obj.Data.Fix.IdcInSeq==obj.Data.Fix.SeqLength;
            fixSeq = obj.Data.Fix(idcStart, :);
            fixSeq.Time(:, 2) = obj.Data.Fix.Time(idcEnd, 2);
            graphAction = obj.Data.Graph.getActions();
            nT = numel(t);
            nTrials = height(graphAction);
            itvCenter = graphAction.Start'+t;
            itvCenter = itvCenter(:);
            itv = spiky.core.Intervals(itvCenter+[-0.01 0.01]);
            idcTrial = repelem((1:nTrials)', nT, 1);
            idcT = repmat((1:nT)', nTrials, 1);
            graphItv = repelem(graphAction, nT, 1);
            [~, idcInItv, idcInFix] = fixSeq.haveIntervals(itv);
            itvCenter = itvCenter(idcInItv);
            nValid = numel(idcInItv);
            idcTrial = idcTrial(idcInItv);
            idcT = idcT(idcInItv);
            graphItv = graphItv(idcInItv, :);
            fixInItv = fixSeq(idcInFix);
            isViewSubject = fixInItv.Id==graphItv.Subject.Id;
            isViewObject = fixInItv.Id==graphItv.Object.Id;
            tbl = table();
            tbl.Trial = graphItv.TrialStart;
            tbl.IdcT = idcT;
            tbl.TimeAfterAction = t(idcT);
            tbl.Id = fixInItv.Id;
            tbl.Name = fixInItv.Name;
            tbl.Role = categorical(NaN(nValid, 1));
            tbl.Role(isViewSubject) = "Subject";
            tbl.Role(isViewObject) = "Object";
            tbl.Action = graphItv.Predicate.Name;
            idcValid = isViewSubject | isViewObject;
            tbl = tbl(idcValid, :);
            et = spiky.core.EventsTable(itvCenter(idcValid), tbl);
            fr = spikes.trigFr(et, 0, HalfWidth=options.HalfWidth, ...
                Kernel="box", Normalize=true);
        end

        function et = getActionView(obj, window)
            %GETACTIONVIEW Get the flattened scene graph and fixation target at each time point during action
            arguments
                obj spiky.par.ActionTheater
                window (1, :) double = -0.3:0.1:1.8
            end
            graphAction = obj.Data.Graph.getActions();
            fix = obj.Data.FixSeq;
            nPoints = numel(window);
            nTrials = height(graphAction);
            n = nPoints*nTrials;
            idcInTrial = repelem((1:nTrials)', nPoints, 1);
            t = graphAction.Start+window;
            t = t';
            t = t(:);
            tbl = table();
            tbl.Trial = graphAction.TrialStart(idcInTrial);
            tbl.TrialTime = repmat(window', nTrials, 1);
            tbl.Action = graphAction.Predicate.Name(idcInTrial);
            tbl.Subject = graphAction.Subject.Name(idcInTrial);
            tbl.SubjectId = graphAction.Subject.Id(idcInTrial);
            tbl.Object = graphAction.Object.Name(idcInTrial);
            tbl.ObjectId = graphAction.Object.Id(idcInTrial);
            [~, idcInFix, idcFix] = fix.haveEvents(t);
            isValid = fix.Id(idcFix)==tbl.SubjectId(idcInFix) | ...
                fix.Id(idcFix)==tbl.ObjectId(idcInFix);
            idcInFix = idcInFix(isValid);
            idcFix = idcFix(isValid);
            tbl.FixName = categorical(NaN(n, 1));
            tbl.FixName(idcInFix) = fix.Name(idcFix);
            tbl.FixId = zeros(n, 1, "int32");
            tbl.FixId(idcInFix) = fix.Id(idcFix);
            tbl.FixRole = categorical(NaN(n, 1));
            tbl.FixRole(tbl.FixId==tbl.SubjectId) = "Subject";
            tbl.FixRole(tbl.FixId==tbl.ObjectId) = "Object";
            et = spiky.core.EventsTable(t, tbl);
        end

        function et = getIdleViewFlat(obj, tWindow)
            %GETIDLEVIEWFLAT Get the flattened scene graph and fixation target at each time point during idle actions
            arguments
                obj spiky.par.ActionTheater
                tWindow (1, :) double = -0.3:0.1:1.5
            end
            et = obj.getActionViewFlat(tWindow, Exclude="Walk");
            et = et(ismember(et.Action, ["Idle" "Idle|Idle"]) | et.TrialTime<0, :);
        end

        function et = getActionViewFlat(obj, tWindow, options)
            %GETACTIONVIEWFLAT Get the flattened scene graph and fixation target at each time point during actions,
            %   accounted for multiple actions in the same trial
            arguments
                obj spiky.par.ActionTheater
                tWindow (1, :) double = -0.3:0.1:1.5
                options.Exclude (1, :) string = ["Idle" "Walk"]
            end
            graphAction = obj.Data.Graph.getAllActions(Exclude=options.Exclude);
            % tWait = obj.Data.Vars.WaitTime.get();
            % tAction = obj.Data.Vars.ActionTime.get();
            % tWindow = -tWait:res:tAction;
            fix = obj.Data.Fix;
            nPoints = numel(tWindow);
            nTrials = height(graphAction);
            n = nPoints*nTrials;
            idcInTrial = repelem((1:nTrials)', nPoints, 1);
            t = graphAction.Start+tWindow;
            t = t';
            t = t(:);
            tbl = table();
            tbl.Trial = graphAction.Trial(idcInTrial);
            tbl.TrialTime = repmat(tWindow', nTrials, 1);
            tbl.Actions = graphAction.Actions(idcInTrial);
            tbl.Action = graphAction.Action(idcInTrial);
            tbl.Subjects = graphAction.Subjects(idcInTrial);
            tbl.Subject = graphAction.Subject(idcInTrial);
            tbl.SubjectIds = graphAction.SubjectIds(idcInTrial);
            tbl.Objects = graphAction.Objects(idcInTrial);
            tbl.Object = graphAction.Object(idcInTrial);
            tbl.ObjectIds = graphAction.ObjectIds(idcInTrial);
            tbl.Sentence = graphAction.Sentence(idcInTrial);
            tbl.NActors = graphAction.NActors(idcInTrial);
            [~, idcInFix, idcFix] = fix.haveEvents(t);
            isValid = arrayfun(@(id, c1, c2) ismember(id, c1{1}) || ismember(id, c2{1}), ...
                fix.Id(idcFix), tbl.SubjectIds(idcInFix), tbl.ObjectIds(idcInFix));
            idcInFix = idcInFix(isValid);
            idcFix = idcFix(isValid);
            tbl.FixTime = nan(n, 1);
            tbl.FixTime(idcInFix) = t(idcInFix)-fix.Start(idcFix);
            tbl.FixName = categorical(NaN(n, 1));
            tbl.FixName(idcInFix) = fix.Name(idcFix);
            tbl.OtherName = categorical(NaN(n, 1));
            tbl.OtherName(idcInFix) = fix.OtherName(idcFix);
            tbl.FixId = zeros(n, 1, "int32");
            tbl.FixId(idcInFix) = fix.Id(idcFix);
            tbl.OtherId = zeros(n, 1, "int32");
            tbl.OtherId(idcInFix) = fix.OtherId(idcFix);
            tbl.FixRole = categorical(NaN(n, 1));
            tbl.OtherRole = categorical(NaN(n, 1));
            fun = @(id, c) ismember(id, c{1});
            tbl.FixRole(arrayfun(fun, tbl.FixId, tbl.SubjectIds) & tbl.TrialTime>=0) = "Subject";
            tbl.FixRole(arrayfun(fun, tbl.FixId, tbl.ObjectIds) & tbl.TrialTime>=0) = "Object";
            tbl.FixRole(tbl.FixId==0) = missing;
            tbl.OtherRole(arrayfun(fun, tbl.OtherId, tbl.SubjectIds) & tbl.TrialTime>=0) = "Subject";
            tbl.OtherRole(arrayfun(fun, tbl.OtherId, tbl.ObjectIds) & tbl.TrialTime>=0) = "Object";
            tbl.OtherRole(tbl.OtherId==0) = missing;
            tbl.FixVerb = categorical(NaN(n, 1));
            tbl.OtherVerb = categorical(NaN(n, 1));
            % tbl.FixVerb(tbl.FixId~=0 & tbl.TrialTime<0) = "Idle";
            % tbl.OtherVerb(tbl.OtherId~=0 & tbl.TrialTime<0) = "Idle";
            fun = @(id, ids, verbs) verbs{1}(id==ids{1});
            isFixSubject = tbl.FixRole=="Subject";
            if any(isFixSubject)
                tbl.FixVerb(isFixSubject) = arrayfun(fun, tbl.FixId(isFixSubject), tbl.SubjectIds(isFixSubject), tbl.Actions(isFixSubject));
            end
            isFixObject = tbl.FixRole=="Object";
            if any(isFixObject)
                tbl.FixVerb(isFixObject) = arrayfun(fun, tbl.FixId(isFixObject), tbl.ObjectIds(isFixObject), tbl.Actions(isFixObject));
            end
            isOtherSubject = tbl.OtherRole=="Subject";
            if any(isOtherSubject)
                tbl.OtherVerb(isOtherSubject) = arrayfun(fun, tbl.OtherId(isOtherSubject), tbl.SubjectIds(isOtherSubject), tbl.Actions(isOtherSubject));
            end
            isOtherObject = tbl.OtherRole=="Object";
            if any(isOtherObject)
                tbl.OtherVerb(isOtherObject) = arrayfun(fun, tbl.OtherId(isOtherObject), tbl.ObjectIds(isOtherObject), tbl.Actions(isOtherObject));
            end
            et = spiky.core.EventsTable(t, tbl);
        end

        function writeCaptions(obj, minos)
            %% Transitions
            trans = obj.Data.Graph.getTransitions();
            capTrans = strings(height(trans), 1);
            capTrans(trans.IsAdd) = compose("%s enter", trans.Change(trans.IsAdd));
            capTrans(~trans.IsAdd) = compose("%s leave", trans.Change(~trans.IsAdd));
            capTrans = groupsummary(capTrans, trans.Trial, @(s) join(s, ", "));
            [~, idcTrans] = unique(trans.Trial, "stable");
            tTrans = trans.Time(idcTrans, 1);
            tTrans = tTrans+[-0.1 0.5];
            %% Actions
            graphAction = obj.Data.Graph.getActions();
            capAction = compose("%s %s", string(graphAction.Subject.Name), lower(string(graphAction.Predicate.Name)));
            hasObject = ~ismissing(graphAction.Object.Name);
            capAction(hasObject) = capAction(hasObject)+...
                compose(" %s", string(graphAction.Object.Name(hasObject)));
            capAction = groupsummary(capAction, graphAction.TrialStart, @(s) join(s, ", "));
            [~, idcAction] = unique(graphAction.TrialStart, "stable");
            tAction = graphAction.Time(idcAction, 1);
            tAction = tAction+[0.2 1.5];
            %% Combine and write to minos
            tCap = [tTrans; tAction];
            [tCap, idcSort] = sortrows(tCap);
            cap = [capTrans; capAction];
            cap = cap(idcSort);
            sc = minos.getScreenCapture();
            sc.writeSrt(tCap, cap);
        end

        function labels = getLabels(obj, t)
            %GETLABELS Get labels for GLM
            arguments
                obj spiky.par.ActionTheater
                t (:, 1) double
            end
            labels = spiky.stat.Labels(t);
            %% Add counts and identity states
            counts = obj.Data.Graph.getCounts();
            names = obj.Data.Graph.getIdenties();
            labels = labels.addLabel(counts, Name="Count", Mode="state", Categorize=true);
            labels = labels.addLabel(names, Name="Name", Mode="state");
            %% Add transitions
            trans = obj.Data.Graph.getTransitions();
            labels = labels.addLabel(trans(trans.IsAdd, "Change"), Name="EnterStart", Mode="trigger");
            labels = labels.addLabel(trans(trans.IsAdd, "Change"), Name="EnterName");
            labels = labels.addLabel(trans(~trans.IsAdd, "Change"), Name="LeaveStart", Mode="trigger");
            labels = labels.addLabel(trans(~trans.IsAdd, "Change"), Name="LeaveName");
            %% Add verbs
            verbs = obj.Data.Graph.getVerbs();
            % labels = labels.addLabel(verbs, Name="Verb", Mode="state");
            labels = labels.addLabel(verbs(verbs.Data~="Idle", :), Name="ActionStart", Mode="trigger");
            labels = labels.addLabel(verbs(verbs.Data~="Idle", :), Name="Action");
            %% Add action roles
            actions = obj.Data.Graph.Predicates.Name(obj.Data.Graph.Predicates.Name~="Walk" & ...
                obj.Data.Graph.Predicates.Type=="Verb");
            isAction = ismember(obj.Data.Graph.Predicate.Name, actions);
            ttSubjects = obj.Data.Graph(isAction, "Subject").toEventsTable("start");
            ttSubjects.Data = ttSubjects.Subject.Name;
            ttObjects = obj.Data.Graph(isAction, "Object").toEventsTable("start");
            ttObjects.Data = ttObjects.Object.Name;
            dataActions = obj.Data.Graph.Predicate.Name(isAction);
            for ii = 1:numel(actions)
                labels = labels.addLabel(ttSubjects(dataActions==actions(ii), :), ...
                    Name=string(actions(ii))+"SubjectName");
                labels = labels.addLabel(ttObjects(dataActions==actions(ii), :), ...
                    Name=string(actions(ii))+"ObjectName");
            end
            %% Add fixations
            fix = obj.Data.Fix(obj.Data.Fix.IsFace, :);
            fix.Data.ActionRole = categorical(string(fix.Verb)+string(fix.Role));
            labels = labels.addLabel(obj.Data.Fix.Start, Name="FixStart", Mode="trigger");
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
            fpth = obj.Data.Session.getFpth("ActionTheater.Zeta.mat");
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
                idcVis = find(obj.Data.Graph.IsVisibility);
                idcVis = idcVis(1:min(end, options.MaxEvents));
                zetaTests.Enter = spikes.zeta(obj.Data.Graph.Time(idcVis, 1), 1);
                zetaTests.Leave = spikes.zeta(obj.Data.Graph.Time(idcVis, 2), 1);
                idcWalk = find(obj.Data.Graph.IsVerb & obj.Data.Graph.Predicate.Name=="Walk");
                idcWalk = idcWalk(1:min(end, options.MaxEvents));
                zetaTests.Walk = spikes.zeta(obj.Data.Graph.Predicate.Time(idcWalk, 1), 1);
                idcAction = find(obj.Data.Graph.IsVerb & obj.Data.Graph.Predicate.Name~="Walk");
                idcAction = idcAction(1:min(end, options.MaxEvents));
                zetaTests.Action = spikes.zeta(obj.Data.Graph.Predicate.Time(idcAction, 1), 1);
                idcFix = find(obj.Data.Fix.IsFace);
                idcFix = idcFix(1:min(end, options.MaxEvents));
                zetaTests.Fix = spikes.zeta(obj.Data.Fix.Time(idcFix), 1);
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
            t1 = ceil(obj.Data.Intervals.Time(1)/res)*res;
            t = t1:res:obj.Data.Intervals.Time(end);
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
            
            t1 = ceil(obj.Data.Intervals.Time(1)/res)*res;
            t = t1:res:obj.Data.Intervals.Time(end);
            [t2, idcT] = obj.Data.Intervals.haveEvents(t);
            parFr = spikes.trigFr(t1, t, HalfWidth=halfWidth, Kernel=kernel, Normalize=normalize);
            trigFr = parFr(idcT, :, :);
            trigFr.Data = permute(trigFr.Data, [2 1 3]);
            trigFr.Time = 0;
            trigFr.Events_ = t2;
            trigFr.Window = [0 res];
        end
    end
end