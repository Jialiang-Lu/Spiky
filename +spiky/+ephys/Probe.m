classdef Probe
    %PROBE Class representing probe

    properties
        Name (1, 1) string = "Probe"
        ChanMap (:, 1) double
        YCoords (:, 1) double
        XCoords (:, 1) double
        KCoords (:, 1) double
        Connected (:, 1) logical
    end
    
    properties (Dependent)
        NChannels
    end
    
    methods (Static)
        function objs = load(s)
            if (ischar(s) || isStringScalar(s)) && exist(s, "file")
                s = load(s);
            end
            
            names = split(string(s.name), "+");
            nGroups = numel(names);
            kcoords = s.kcoords(s.kcoords>0);
            [~, ~, idc] = unique(kcoords);
            ns = groupcounts(idc);
            offsets = [0; cumsum(ns)];
            objs = cell(nGroups, 1);
            for iGroup = nGroups:-1:1
                idx = idc==iGroup;
                objs{iGroup} = spiky.ephys.Probe(names(iGroup), s.chanMap(idx)-offsets(iGroup), ...
                    s.ycoords(idx), s.xcoords(idx)-(iGroup-1)*1000, s.kcoords(idx)-(iGroup-1), s.connected(idx));
            end
            objs = cat(1, objs{:});
        end

    end
    
    methods
        function obj = Probe(name, chanMap, yCoords, xCoords, kCoords, connected)
            arguments
                name (1, 1) string = "Probe"
                chanMap (:, 1) double = []
                yCoords (:, 1) double = []
                xCoords (:, 1) double = []
                kCoords (:, 1) double = []
                connected (:, 1) logical = []
            end
            obj.Name = name;
            obj.ChanMap = chanMap;
            obj.YCoords = yCoords;
            obj.XCoords = xCoords;
            obj.KCoords = kCoords;
            obj.Connected = connected;
        end
        
        function NChannels = get.NChannels(obj)
            NChannels = numel(obj.ChanMap);
        end

        function obj = resample(obj)
            obj.ChanMap = 1:obj.NChannels;
        end

        function s = toStruct(obj, nChTotal, resample)
            arguments
                obj spiky.ephys.Probe
                nChTotal double = []
                resample logical = false
            end
            if numel(obj)>1
                obj = obj(:);
                nProbes = numel(obj);
                s1 = arrayfun(@toStruct, obj);
                nChannels = [obj.NChannels];
                nShanks = cellfun(@max, {obj.KCoords});
                nChannelsCum = [0, cumsum(nChannels)];
                nShanksCum = [0, cumsum(nShanks)];
                for ii = 1:nProbes
                    s1(ii).oeMap = s1(ii).oeMap + nChannelsCum(ii);
                    s1(ii).kcoords = s1(ii).kcoords + nShanksCum(ii);
                    s1(ii).xcoords = s1(ii).xcoords + (ii-1)*1000;
                    s1(ii).chanMap = s1(ii).chanMap + nChannelsCum(ii);
                    s1(ii).chanMap0ind = s1(ii).chanMap0ind + nChannelsCum(ii);
                end
                s.name = strjoin({s1.name}, '+');
                s.oeMap = cat(1, s1.oeMap);
                s.ycoords = cat(1, s1.ycoords);
                s.xcoords = cat(1, s1.xcoords);
                s.kcoords = cat(1, s1.kcoords);
                s.connected = cat(1, s1.connected);
                s.chanMap = cat(1, s1.chanMap);
                s.chanMap0ind = cat(1, s1.chanMap0ind);
                if ~isempty(nChTotal)
                    nOld = length(s.oeMap);
                    s.oeMap = [s.oeMap; (nOld+1:nChTotal)'];
                    s.ycoords = [s.ycoords; zeros(nChTotal-nOld, 1)];
                    s.xcoords = [s.xcoords; zeros(nChTotal-nOld, 1)];
                    s.kcoords = [s.kcoords; zeros(nChTotal-nOld, 1)];
                    s.connected = [s.connected; false(nChTotal-nOld, 1)];
                    s.chanMap = [s.chanMap; (nOld+1:nChTotal)'];
                    s.chanMap0ind = [s.chanMap0ind; (nOld:nChTotal-1)'];
                end
                if resample
                    s.chanMap = (1:length(s.chanMap))';
                    s.chanMap0ind = s.chanMap-1;
                end
                return
            end
            s.name = obj.Name{1};
            s.ycoords = obj.YCoords;
            s.xcoords = obj.XCoords;
            s.kcoords = obj.KCoords;
            s.connected = obj.Connected;
            s.chanMap = obj.ChanMap;
            s.chanMap0ind = obj.ChanMap-1;
            s.oeMap = obj.ChanMap;
            if ~isempty(nChTotal)
                nOld = length(s.oeMap);
                s.ycoords = [s.ycoords; zeros(nChTotal-nOld, 1)];
                s.xcoords = [s.xcoords; zeros(nChTotal-nOld, 1)];
                s.kcoords = [s.kcoords; zeros(nChTotal-nOld, 1)];
                s.connected = [s.connected; false(nChTotal-nOld, 1)];
                s.chanMap = [s.chanMap; (nOld+1:nChTotal)'];
                s.chanMap0ind = [s.chanMap0ind; (nOld:nChTotal-1)'];
                s.oeMap = [s.oeMap; (nOld+1:nChTotal)'];
            end
            if resample
                s.chanMap = (1:length(s.chanMap))';
                s.chanMap0ind = s.chanMap-1;
            end
        end

        function s = save(obj, fpth, nChTotal, resample)
            arguments
                obj spiky.ephys.Probe
                fpth string = ""
                nChTotal double = []
                resample logical = false
            end
            s = obj.toStruct(nChTotal, resample);
            if fpth~=""
                save(fpth, "-struct", "s");
            end
        end
    end
end