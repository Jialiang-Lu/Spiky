classdef ActionTheater < spiky.par.Paradigm
    % ACTIONTHEATER represents a paradigm for the Action Theater

    properties
        Graph spiky.scene.SceneGraph
    end

    methods
        function obj = ActionTheater(par, tr)
            % ACTIONTHEATER represents a paradigm for the Action Theater
            arguments
                par spiky.minos.Paradigm
                tr spiky.minos.Transform
            end
            
            obj@spiky.par.Paradigm(par);
            %% Clean up the data and convert indices to names
            tr = tr([tr.IsHuman]');
            ti = par.TrialInfo;
            trials = par.Trials;
            ti = ti(ismember(ti.Number, trials.Number), :);
            t1 = ti.Time(1);
            actors = categorical(extractBefore(par.Vars.Actors.get(t1)', " "));
            targets = categorical(extractBefore(par.Vars.Targets.get(t1)', " "));
            actions1 = extractBefore(par.Vars.SingleActions.get(t1)', " ");
            actions2 = extractBefore(par.Vars.Actions.get(t1)', " ");
            adjs = extractBefore(par.Vars.Adjs.get(t1)', " ");
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
                actions3 = extractBefore(par.Vars.IndirectActions.get(t1)', " ");
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
            pb = spiky.plot.ProgressBar(nVis, "Calculating visibility", Parallel=true);
            parfor ii = 1:nVis
                idx1 = idcStart(ii);
                idx2 = idcEnd(ii);
                per(ii, :) = tr(ii).Time([idx1 idx2]);
                pos(ii, :) = tr(ii).Pos(idx1, :, 1);
                rot(ii, :) = tr(ii).Rot(idx1, :, 1);
                proj(ii, :) = tr(ii).Proj(idx1, :, 1);
                pb.step
            end
            nodesVis = spiky.scene.SceneNode(per(:, 1), names, types, [tr.Id]', pos, rot, proj);
            graphVis = spiky.scene.SceneGraph(per, nodesVis);
            graphVis.Time = graphVis.Time+par.Latency;
            %% Walk
            idcWalk = find(isHumanRole | isKill);
            nWalk = numel(idcWalk);
            trialsWalk = trials(ismember(trials.Number, ti.Number(idcWalk)), :);
            [~, idcWalkTrial] = ismember(ti.Number(idcWalk), trialsWalk.Number);
            per = trialsWalk(idcWalkTrial, ["Move" "Wait"]).Data{:, :};
            tiWalk = ti(idcWalk, :);
            [~, idcWalkInVis] = ismember(nodesVis.Id, tiWalk.Id);
            per(idcWalkInVis, 1) = graphVis.Time;
            nodesWalk = spiky.scene.SceneNode(per(:, 1), tiWalk.Actor, "Humanoid", tiWalk.Id, ...
                tiWalk.Pos, tiWalk.Rot, tiWalk.Proj);
            nodesWalkVerb = spiky.scene.SceneNode(per(:, 1), "Walk", "Verb", 0, ...
                tiWalk.Pos, tiWalk.Rot, tiWalk.Proj);
            graphWalk = spiky.scene.SceneGraph(per, nodesWalk, nodesWalkVerb);
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
            nodesSubject = spiky.scene.SceneNode(per(:, 1), ti.Actor(idcSource), "Humanoid", ...
                ti.Id(idcSource), ti.Pos(idcSource, :), ti.Rot(idcSource, :), ti.Proj(idcSource, :));
            nodesObject = spiky.scene.SceneNode(per(:, 1), ti.Actor(idcTarget), "Humanoid", ...
                ti.Id(idcTarget), ti.Pos(idcTarget, :), ti.Rot(idcTarget, :), ti.Proj(idcTarget, :));
            nodesVerb = spiky.scene.SceneNode(per(:, 1), tiActions.Action, "Verb", ...
                tiActions.Id, tiActions.Pos, tiActions.Rot, tiActions.Proj);
            graphAction = spiky.scene.SceneGraph(per, nodesSubject, nodesVerb, nodesObject);
            %%
            obj.TrialInfo = ti;
            obj.Graph = [graphVis graphWalk graphAction];
            obj.Graph = obj.Graph.sort();
        end

        function [trigFr, parFr] = trigFr(obj, spikes, res, halfWidth, kernel, normalize)
            % TRIGFR Firing rate during the paradigm
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
            
            t1 = ceil(obj.Periods.Time(1)/res)*res;
            t = t1:res:obj.Periods.Time(end);
            [t2, idcT] = obj.Periods.haveEvents(t);
            parFr = spikes.trigFr(t1, t, HalfWidth=halfWidth, Kernel=kernel, Normalize=normalize);
            trigFr = parFr(idcT, :, :);
            trigFr.Data = permute(trigFr.Data, [2 1 3]);
            trigFr.Time = 0;
            trigFr.Events_ = t2;
            trigFr.Window = [0 res];
        end
    end
end