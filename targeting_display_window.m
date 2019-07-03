function targeting_display_window(hobject, eventdata)

    persistent targeting_window
    Resource = evalin('base','Resource');
    
    % Create the figure if it doesn’t exist.
    if isempty(targeting_window)||~ishandle(targeting_window)
        imWidth = Resource.DisplayWindow(1).Position(3); % Position(3) is imWidth, not figure width.
        imHeight = Resource.DisplayWindow(1).Position(4);
        figure('Name','Target Selection',...
            'Colormap',Resource.DisplayWindow(1).Colormap,...
            'NumberTitle','off',...
            'Position',[Resource.DisplayWindow(1).Position(1)+imWidth+110, ... % left edge
            Resource.DisplayWindow(1).Position(2), ... % bottom
            imWidth + 100, imHeight + 150])            % width, height + border);
        targeting_window = axes('Units','pixels','Position',[60,90,imWidth,imHeight],...
            'NextPlot','replacechildren');
        set(gca, 'Units','normalized','YDir','reverse');
        axis equal tight;

        
    end
    try
    
    %set(Resource.DisplayWindow(1).figureHandle,'Visible','off');
    [x,y,I] = getimage(Resource.DisplayWindow.figureHandle);
    imagesc(targeting_window, x,y,I); hold on;
    target_pos = Resource.parameters.target_position;
    Resource.parameters.target_point=impoint(targeting_window, target_pos(1), target_pos(2)); hold on;
%     bringToFront(point)
    assignin('base','Resource',Resource);
    drawnow
    catch e
        disp(e.message);
    end
end