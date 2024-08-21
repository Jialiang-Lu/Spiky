function fout = timedWaitbar(x, varargin)
    %TIMEDWAITBAR waitbar with time estimate
    %
    %   H = TIMEDWAITBAR(X, "message", property, value, property, value, ...)
    %   creates and displays a waitbar of fractional length X. The
    %   handle to the waitbar figure is returned in H.
    %
    %   TIMEDWAITBAR(X) will set the length of the current bar to the fractional
    %   length X and caculated the estimated remaining time.
    %
    %   TIMEDWAITBAR(X, H) will set the length of the bar in waitbar H
    %   to the fractional length X and caculated the estimated remaining time..
    %
    %   TIMEDWAITBAR(X, H, "message") will update the message text in
    %   the waitbar figure, in addition to setting the fractional
    %   length to X and caculated the estimated remaining time.
    %
    %   TIMEDWAITBAR("Add", X, ...) will add the frational length to current X.
    %
    %   TIMEDWAITBAR([]) will close the waitbar.
    
    import spiky.plot.*
    mon = get(0, "MonitorPositions");
    % mon = [1 1 2048 1152
    %        2049 1 2048 1152];
    res = mon(end, 3:4);
    sz = [270 80];
    pos = [mon(end, 1:2)-1+res./[6 4]-sz/2 sz];
    if isempty(x)
        h = findobj(allchild(0),"flat","Tag","TMWWaitbar");
        delete(h);
        return
    end
    if strcmpi(x, "Add")
        if isempty(varargin)
            error("Pease provide the fractional length")
        elseif isscalar(varargin) % TIMEDWAITBAR("Add", X)
            x = varargin{1};
            h = findobj(allchild(0),"flat","Tag","TMWWaitbar");
            varargin = {};
        elseif legnth(varargin)>=2 % TIMEDWAITBAR("Add", X, H, ...);
            x = varargin{1};
            h = varargin{2};
            if ~isa(varargin{1}, "matlab.ui.Figure")
                error("%s is not a valid figure handle", h)
            end
            varargin(1:2) = [];
        end
        x = h.UserData{3}+x;
        % disp(x);
    end
    if x<=0
        h = waitbar(x, varargin{:}, "Position", pos);
        fixfig(h);
        msg = h.Children.Title.String;
        h.UserData = {tic, msg, x};
    else
        h = waitbar(x, varargin{:});
        h.UserData{3} = x;
        if ~isempty(h.UserData)
            if x<1
                h.Children.Title.String = sprintf("%s\n%s remaining", h.UserData{2}, ...
                    duration(0, 0, toc(h.UserData{1})/x*(1-x)));
            else
                h.Children.Title.String = sprintf("%s\nElapsed time %s", h.UserData{2}, ...
                    duration(0, 0, toc(h.UserData{1})));
            end
        end
    end
    drawnow
    if nargout>0
        fout = h;
    end
end
    