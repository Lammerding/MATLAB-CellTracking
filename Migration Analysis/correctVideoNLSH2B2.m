function [message, timePoints] = correctVideoNLSH2B2(video, v, v2, section, constr, loc, scaled)
    %some code for the user interface courtesy of João Filipe Henriques
    if scaled
        scaled = 0.5;
    else
        scaled = 1;
    end
    timePoints = size(video, 4);
    message = {''};
    width = size(video, 2);
    height = size(video, 1);
    fs = 12;
    ls = 4;
    screenSize = get(groot, 'Screensize');
    timePoints = size(video, 4);
    
    %initialize figure
    fig = figure('Position', [(screenSize(3) - width)/2 (screenSize(4)-height)/2 width-1 height+19], 'Resize', 'off', 'MenuBar', 'none', 'KeyPressFcn', @keyPress, 'WindowScrollWheelFcn', @scrollWheel, 'WindowButtonDownFcn', @pressButton, 'WindowButtonUpFcn', @releaseButton, 'WindowButtonMotionFcn', @mouseMove);

    %axes for scroll bar
    scrollAxes = axes('Units', 'Pixels', 'Parent', fig, 'Position', [0 0 width 20]);
    axis([0 1 0 1]);
    axis off

    scrollAxes.Units = 'Normalized';
    
    %scroll bar
    scrollWidth = max(1 / timePoints, 0.01);
    scrollBar = patch([0 1 1 0] * scrollWidth, [0 0 1 1], [.8 .8 .8], 'Parent', scrollAxes);

    %main drawing axes for video display
    axesHandle = axes('Units', 'Pixels', 'Position', [0 20 width height]);
    
    global finishedCells
    
    selectedCell = 0;
    selectedFrame = 0;
    pos1 = [0 0 0 0];
    pos2 = [0 0 0 0];
    r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
    finishedCellsSave = [];
    videoSave = zeros(size(video));
    
    newRupture = false;
    buttonDown = false;
    frame = 0;
    scroll(1)
    
    %pause code execution until user closes figure window
    uiwait(fig)
    
    function keyPress(~, event)
        %% press left or right arrow keys to scroll through video
        switch event.Key
            case 'leftarrow'
                scroll(frame - 1)
            case 'rightarrow'
                scroll(frame + 1)
        end
    end

    function scrollWheel(~, event)
        %% use mouse wheel to scroll through video
        scroll(frame + event.VerticalScrollCount)
    end

    function scroll(newFrame)
        %% scroll to position newFrame
        if newFrame >= 1 && newFrame <= timePoints && frame ~= newFrame
            
            frame = newFrame;

            %convert frame number to appropriate x-coordinate of scroll bar
            scroll_x = (frame - 1) / timePoints;

            %move scroll bar to new position
            scrollBar.XData = scroll_x + [0 1 1 0] * scrollWidth;
            
            %set to the right axes and call the custom redraw function
            fig.CurrentAxes = axesHandle;
            imshow(video(:, :, :, newFrame), 'Parent', axesHandle);
          
            fig.Name = ['Section ' num2str(section) ', Frame ' num2str(newFrame) ' / ' num2str(timePoints)];

            r = rectangle('Position', pos1, 'LineWidth', 3, 'EdgeColor', 'white');
            r2 = rectangle('Position', pos2, 'LineWidth', 3, 'EdgeColor', 'white');
            
            %used to be "drawnow", but when called rapidly and the CPU is busy
            %it didn't let Matlab process events properly (ie, close figure).
            %pause(0.001)
            drawnow
        end
    end

    function mouseMove(source, ~)
        if buttonDown
            source.Units = 'Normalized';
            p = source.CurrentPoint;
            scroll(floor(1 + p(1) * timePoints))
        end
    end

    function releaseButton(~, ~)
       buttonDown = false; 
    end

    function pressButton(source, ~)
        %% find the cell the user clicked in
        source.Units = 'Pixels';
        p = source.CurrentPoint;
        if p(2) <= 20
            buttonDown = true;
            mouseMove(source)
        else
            p(2) = height - p(2) + 20;
            p = p ./ scaled;
            if newRupture
                if frame < timePoints
                    if strcmp(questdlg(['Nucleus ruptures from time ' num2str(min(selectedFrame, frame)) ' to ' num2str(max(frame, selectedFrame)) '?'], 'Accuracy Check', 'Yes', 'No', 'Yes'), 'Yes')
                        finishedCellsSave = finishedCells;
                        videoSave = video;
                        finishedCells(selectedCell).Rupture((min(selectedFrame, frame) + 1):(max(frame, selectedFrame) - 1)) = deal(0.5);
                        finishedCells(selectedCell).Rupture(min(selectedFrame, frame)) = 1;
                        for p = min(selectedFrame, frame):min(max(frame, selectedFrame) - 1, find(finishedCells(selectedCell).Alive, 1, 'last'))
                            if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CR', 'FontSize', fs, 'BoxColor', 'white');
                            else
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'R', 'FontSize', fs, 'BoxColor', 'white');
                            end
                        end
                    end
                else
                    p = questdlg('Does this rupture finish here or continue past the end of the video?', 'Accuracy Check', 'Ends here', 'Continues', 'Cancel', 'Ends here');
                    if strcmp(p, 'Continues')
                        finishedCellsSave = finishedCells;
                        videoSave = video;
                        finishedCells(selectedCell).Rupture((min(selectedFrame, frame) + 1):max(frame, selectedFrame)) = deal(0.5);
                        finishedCells(selectedCell).Rupture(min(selectedFrame, frame)) = 1;
                        for p = min(selectedFrame, frame):min(max(frame, selectedFrame), find(finishedCells(selectedCell).Alive, 1, 'last'))
                            if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CR', 'FontSize', fs, 'BoxColor', 'white');
                            else
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'R', 'FontSize', fs, 'BoxColor', 'white');
                            end
                        end
                    elseif strcmp(p, 'Ends here')
                        finishedCellsSave = finishedCells;
                        videoSave = video;
                        finishedCells(selectedCell).Rupture((min(selectedFrame, frame) + 1):(max(frame, selectedFrame) - 1)) = deal(0.5);
                        finishedCells(selectedCell).Rupture(min(selectedFrame, frame)) = 1;
                        for p = min(selectedFrame,frame):min(max(frame, selectedFrame) - 1, find(finishedCells(selectedCell).Alive, 1, 'last'))
                            if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CR', 'FontSize', fs, 'BoxColor', 'white');
                            else
                                video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'R', 'FontSize', fs, 'BoxColor', 'white');
                            end
                        end
                    end
                end
                imshow(video(:, :, :, frame))
                selectedCell = 0;
                selectedFrame = 0;
                newRupture = false;
                pos1 = [0 0 0 0];
                r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
            elseif selectedCell == 0
                %% nothing is currently selected. select cell if one was clicked on
                for i = 1:length(finishedCells)
                    if finishedCells(i).Alive(frame) && inpolygon(p(1), p(2), [finishedCells(i).BoundingBox(frame, 1) finishedCells(i).BoundingBox(frame, 1) finishedCells(i).BoundingBox(frame, 1)+finishedCells(i).BoundingBox(frame, 3) finishedCells(i).BoundingBox(frame, 1)+finishedCells(i).BoundingBox(frame, 3)], [finishedCells(i).BoundingBox(frame, 2) finishedCells(i).BoundingBox(frame, 2)+finishedCells(i).BoundingBox(frame, 4) finishedCells(i).BoundingBox(frame, 2)+finishedCells(i).BoundingBox(frame, 4) finishedCells(i).BoundingBox(frame, 2)])
                        selectedCell = i;
                        selectedFrame = frame;
                        pos1 = finishedCells(i).BoundingBox(frame, :) .* scaled;
                        r = rectangle('Position', pos1, 'LineWidth', 3, 'EdgeColor', 'white');
                        break
                    end
                end
                if strcmp(fig.SelectionType, 'alt')
                    if selectedCell == 0
                        if isempty(finishedCellsSave)
                            c = questdlg('What do you want to do?', 'Accuracy Check', 'Delete Whole Section', 'Delete Future Time Points', 'Delete Whole Section');
                        else
                            c = questdlg('What do you want to do?', 'Accuracy Check', 'Undo Last Change', 'Restart Section', 'Remove Time Points', 'Undo Last Change');
                            if strcmp(c, 'Remove Time Points')
                                c = questdlg('What do you want to do?', 'Accuracy Check', 'Delete Whole Section', 'Delete Future Time Points', 'Delete Whole Section');
                            end
                        end
                        if strcmp(c, 'Undo Last Change')
                            temp = finishedCells;
                            finishedCells = finishedCellsSave;
                            finishedCellsSave = temp;
                            temp = video;
                            video = videoSave;
                            videoSave = temp;
                            message = {''};
                            imshow(video(:, :, :, frame));
                        elseif strcmp(c, 'Restart Section')
                            timePoints = -1;
                            close(gcf);
                            fprintf('\n\t\tRestarting...')
                            return
                        elseif strcmp(c, 'Delete Whole Section')
                            finishedCellsSave = finishedCells;
                            finishedCells = [];
                            videoSave = video;
                            message = inputdlg('Why delete the section?', 'Accuracy Check', 1, {'Cells going under'});
                            if isempty(message{1})
                                message = {' '};
                            end
                            video(:, :, :, frame) = insertText(video(:, :, :, frame), [0 0], 'D', 'FontSize', fs * 2.5, 'BoxColor', 'black', 'TextColor', 'white');
                            imshow(video(:, :, :, frame))
                        elseif strcmp(c, 'Delete Future Time Points')
                            finishedCellsSave = finishedCells;
                            videoSave = video;
                            for c = length(finishedCells):-1:1
                                finishedCells(c).Alive(frame:end) = 0;
                                if ~any(finishedCells(c).Alive)
                                    finishedCells(c) = [];
                                elseif finishedCells(c).Rupture(frame)
                                    p = frame;
                                    while finishedCells(c).Rupture(p) > 0
                                        finishedCells(c).Rupture(p) = 0;
                                        if finishedCells(c).Constriction(p) == floor(finishedCells(c).Constriction(p))
                                            video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(c).BoundingBox(p, 1:2) .* scaled, 'CX', 'FontSize', fs, 'BoxColor', 'magenta');
                                        else
                                            video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(c).BoundingBox(p, 1:2) .* scaled, 'X', 'FontSize', fs);
                                        end
                                        p = p - 1;
                                    end
                                end
                            end
                            video(:, :, :, (frame + 1):end) = zeros(height, width, 3, timePoints - frame);
                            video(:, :, :, frame) = insertText(video(:, :, :, frame), [0 0], 'E', 'FontSize', fs * 2.5, 'BoxColor', 'black', 'TextColor', 'white');
                            imshow(video(:, :, :, frame))
                        end
                    elseif finishedCells(selectedCell).Rupture(frame) <= 0
                        c = questdlg('What do you want to do?', 'Accuracy Check', 'Start Rupture', 'Leave Note', 'Start Rupture');
                        if strcmp(c, 'Start Rupture')
                            newRupture = true;
                        else
                            if strcmp(c, 'Leave Note')
                                finishedCells(selectedCell).Note = inputdlg('Note:', 'Accuracy Check');
                            end
                            selectedCell = 0;
                            selectedFrame = 0;
                            pos1 = [0 0 0 0];
                            r.Position = [0 0 0 0];
                        end
                    else
                        c = questdlg('What do you want to do?', 'Accuracy Check', 'Cancel Rupture', 'End Rupture Early', 'Leave Note', 'Cancel Rupture');
                        if strcmp(c, 'Cancel Rupture')
                            finishedCellsSave = finishedCells;
                            videoSave = video;
                            p = frame;
                            while p <= timePoints && finishedCells(selectedCell).Alive(p) && finishedCells(selectedCell).Rupture(p) > 0
                                finishedCells(selectedCell).Rupture(p) = -1;
                                if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CX', 'FontSize', fs, 'BoxColor', 'magenta');
                                else
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'X', 'FontSize', fs);
                                end
                                p = p + 1;
                            end
                            p = frame - 1;
                            while p > 0 && finishedCells(selectedCell).Rupture(p) > 0
                                finishedCells(selectedCell).Rupture(p) = -1;
                                if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CX', 'FontSize', fs, 'BoxColor', 'magenta');
                                else
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'X', 'FontSize', fs);
                                end
                                p = p - 1;
                            end
                        elseif strcmp(c, 'End Rupture Early')
                            finishedCellsSave = finishedCells;
                            videoSave = video;
                            p = frame + 1;
                            while p <= timePoints && finishedCells(selectedCell).Alive(p) && finishedCells(selectedCell).Rupture(p) > 0
                                finishedCells(selectedCell).Rupture(p) = -1;
                                if finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CX', 'FontSize', fs, 'BoxColor', 'magenta');
                                else
                                    video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'X', 'FontSize', fs);
                                end
                                p = p + 1;
                            end
                        elseif strcmp(c, 'Leave Note')
                            finishedCells(selectedCell).Note = inputdlg('Note:');
                        end
                        imshow(video(:, :, :, frame))
                        selectedCell = 0;
                        selectedFrame = 0;
                        pos1 = [0 0 0 0];
                        r = rectangle('Position', pos1, 'LineWidth', 3, 'EdgeColor', 'white');
                    end
                end
            else
                for i = 1:length(finishedCells)
                    if finishedCells(i).Alive(frame) && inpolygon(p(1), p(2), [finishedCells(i).BoundingBox(frame, 1) finishedCells(i).BoundingBox(frame, 1) finishedCells(i).BoundingBox(frame, 1)+finishedCells(i).BoundingBox(frame, 3) finishedCells(i).BoundingBox(frame, 1)+finishedCells(i).BoundingBox(frame, 3)], [finishedCells(i).BoundingBox(frame, 2) finishedCells(i).BoundingBox(frame, 2)+finishedCells(i).BoundingBox(frame, 4) finishedCells(i).BoundingBox(frame, 2)+finishedCells(i).BoundingBox(frame, 4) finishedCells(i).BoundingBox(frame, 2)])
                        pos2 = finishedCells(i).BoundingBox(frame, :) .* scaled;
                        r2 = rectangle('Position', pos2, 'LineWidth', 3, 'EdgeColor', 'white');
                        if frame == selectedFrame
                            if selectedCell == i
                                if frame > 1 && finishedCells(i).Alive(frame - 1)
                                    c = questdlg('What do you want to do with this cell?', 'Accuracy Check', 'Delete', 'Disconnect', 'Split', 'Delete');
                                else
                                    c = questdlg('What do you want to do with this cell?', 'Accuracy Check', 'Delete', 'Split', 'Delete');
                                end
                                if strcmp(c, 'Delete')
                                    finishedCellsSave = finishedCells;
                                    videoSave = video;
                                    %% cell was clicked on twice. see if it should be deleted
                                    for p = find(finishedCells(i).Alive, 1):find(finishedCells(i).Alive, 1, 'last')
                                        video(:, :, :, p) = insertShape(video(:, :, :,p), 'Line', [finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1), p - 10):(p - 1), :) finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1) + 1, p - 9):p, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'FilledCircle', [finishedCells(i).Centroid(p, :) ls] .* scaled, 'Color', 'black');
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Rectangle', finishedCells(i).BoundingBox(p, :) .* scaled, 'LineWidth', ls, 'Color', 'black');
                                    end
                                    imshow(video(:, :, :, frame))
                                    finishedCells(i) = [];
                                    selectedCell = 0;
                                    selectedFrame = 0;
                                    pos1 = [0 0 0 0];
                                    pos2 = [0 0 0 0];
                                    r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    return
                                elseif strcmp(c, 'Disconnect')
                                    finishedCellsSave = finishedCells;
                                    videoSave = video;
                                    %% see if its track should be cut (cell actually disappeared but track went to a new cell)
                                    for p = frame:min([find(finishedCells(i).Alive, 1, 'last') frame+10 timePoints])
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1) + 1, p - 9):frame, :) finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1), p - 10):(frame - 1), :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                    end
                                    finishedCells(end + 1) = finishedCells(i);
                                    finishedCells(end).Area = finishedCells(i).Area;
                                    finishedCells(end).Centroid = finishedCells(i).Centroid;
                                    finishedCells(end).BoundingBox = finishedCells(i).BoundingBox;
                                    finishedCells(end).RedIntensity = finishedCells(i).RedIntensity;
                                    finishedCells(end).GreenIntensity = finishedCells(i).GreenIntensity;
                                    finishedCells(end).Rupture = finishedCells(i).Rupture;
                                    finishedCells(end).Alive = finishedCells(i).Alive;
                                    finishedCells(end).Constriction = finishedCells(i).Constriction;
                                    finishedCells(end).Perimeter = finishedCells(i).Perimeter;
                                    finishedCells(end).Area(1:(frame - 1)) = deal(0);
                                    finishedCells(end).Centroid(1:(frame - 1), :) = deal(0);
                                    finishedCells(end).BoundingBox(1:(frame - 1), :) = deal(0);
                                    finishedCells(end).RedIntensity(1:(frame - 1)) = deal(0);
                                    finishedCells(end).GreenIntensity(1:(frame - 1)) = deal(0);
                                    finishedCells(end).Rupture(1:(frame - 1)) = deal(0);
                                    finishedCells(end).Alive(1:(frame - 1)) = deal(0);
                                    finishedCells(end).Constriction(1:(frame - 1)) = deal(0);
                                    finishedCells(end).Perimeter(1:(frame - 1)) = deal(0);
                                    finishedCells(end).TimeAppearing = frame;
                                    finishedCells(end).Parent = 0;
                                    finishedCells(i).Area = finishedCells(i).Area(1:(frame - 1));
                                    finishedCells(i).Centroid = finishedCells(i).Centroid(1:(frame - 1), :);
                                    finishedCells(i).BoundingBox = finishedCells(i).BoundingBox(1:(frame - 1), :);
                                    finishedCells(i).RedIntensity = finishedCells(i).RedIntensity(1:(frame - 1));
                                    finishedCells(i).GreenIntensity = finishedCells(i).GreenIntensity(1:(frame - 1));
                                    finishedCells(i).Rupture(frame:end) = deal(0);
                                    finishedCells(i).Alive(frame:end) = deal(0);
                                    finishedCells(i).Constriction = finishedCells(i).Constriction(1:(frame - 1));
                                    finishedCells(i).Perimeter = finishedCells(i).Perimeter(1:(frame - 1));
                                    imshow(video(:, :, :, frame))
                                    selectedCell = 0;
                                    selectedFrame = 0;
                                    pos1 = [0 0 0 0];
                                    pos2 = [0 0 0 0];
                                    r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    return
                                elseif strcmp(c, 'Split')
                                    finishedCellsSave = finishedCells;
                                    videoSave = video;
                                    %% see if it's two objects touching that need to be split
                                    color = reshape(video(round(finishedCells(i).BoundingBox(frame, 2) .* scaled), round(finishedCells(i).BoundingBox(frame, 1) .* scaled), :, frame), 1, 3);
                                    im = v(:, :, frame);

                                    minObjectSize = round(width * height / 2050);
                                    imb = ~bwareaopen(~bwareaopen(imopen(imbinarize(imfilter(medfilt2(im), fspecial('gaussian', [10 10], 2), 'same'), 'adaptive', 'Sensitivity', 0.5), strel('disk', 1)), round(minObjectSize / 2), 4), round(minObjectSize / 4), 4);
                                    imbsmall = imb(round(max(1, finishedCells(i).BoundingBox(frame, 2) - 1):min(size(v, 1), (finishedCells(i).BoundingBox(frame, 2) + finishedCells(i).BoundingBox(frame, 4)) + 1)), round(max(1, finishedCells(i).BoundingBox(frame, 1) - 1):min(size(v, 2), (finishedCells(i).BoundingBox(frame, 1) + finishedCells(i).BoundingBox(frame, 3)) + 1)));
                                    D = -bwdist(~imbsmall);
                                    L = watershed(imhmin(D, 5));
                                    imbsmall(L == 0) = 0;
                                    c = bwconncomp(imbsmall);

                                    if c.NumObjects == 1
                                        L = watershed(imhmin(D, 1));
                                        imbsmall(L == 0) = 0;
                                        c = bwconncomp(imbsmall);
                                        if c.NumObjects > 2
                                            imbsmall = imb(round(max(1, finishedCells(i).BoundingBox(frame, 2) - 1):min(size(v, 1), finishedCells(i).BoundingBox(frame, 2) + finishedCells(i).BoundingBox(frame, 4) + 1)), round(max(1, finishedCells(i).BoundingBox(frame, 1) - 1):min(size(v, 2), finishedCells(i).BoundingBox(frame, 1) + finishedCells(i).BoundingBox(frame, 3) + 1)));
                                            D = -bwdist(~imbsmall);
                                            L = watershed(imhmin(D, 3));
                                            imbsmall(L == 0) = 0;
                                            c = bwconncomp(imbsmall);
                                        end
                                    end

                                    if c.NumObjects > 1
                                        if frame > 1 && finishedCells(i).Alive(frame - 1)
                                            video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Line', [finishedCells(i).Centroid(frame - 1, :) finishedCells(i).Centroid(frame, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        end
                                        video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Rectangle', finishedCells(i).BoundingBox(frame, :) .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        if frame < timePoints && finishedCells(i).Alive(frame + 1)
                                            video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Line', [finishedCells(i).Centroid(frame, :) finishedCells(i).Centroid(frame + 1, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        end
                                        grn = v2(:, :, frame);
                                        d = regionprops(c, 'Area', 'Centroid', 'BoundingBox', 'Perimeter');
                                        for j = 1:length(d)
                                            d(j).RedIntensity = mean(im(c.PixelIdxList{j}));
                                            d(j).GreenIntensity = mean(grn(c.PixelIdxList{j}));
                                        end
                                        if frame > 1 && finishedCells(i).Alive(frame - 1) && sum((finishedCells(i).Centroid(frame - 1, :) - d(1).Centroid) .^ 2) > sum((finishedCells(i).Centroid(frame - 1, :) - d(2).Centroid) .^ 2)
                                            temp = d(1);
                                            d(1) = d(2);
                                            d(2) = temp;
                                        end
                                        finishedCells(end + 1).Area(frame) = finishedCells(i).Area(frame) * d(2).Area / (d(1).Area + d(2).Area);
                                        finishedCells(end).Centroid(frame, :) = finishedCells(i).BoundingBox(frame, 1:2) + d(2).Centroid;
                                        finishedCells(end).BoundingBox(frame, :) = [finishedCells(i).BoundingBox(frame, 1:2) 0 0] + d(2).BoundingBox;
                                        finishedCells(end).RedIntensity(frame) = d(2).RedIntensity;
                                        finishedCells(end).GreenIntensity(frame) = d(2).GreenIntensity;
                                        finishedCells(end).Ratio(frame) = finishedCells(end).RedIntensity(frame) / finishedCells(end).GreenIntensity(frame);
                                        finishedCells(end).Perimeter(frame) = d(2).Perimeter;
                                        finishedCells(end).TimeAppearing = frame;
                                        finishedCells(end).Rupture = zeros(1, timePoints);
                                        finishedCells(end).Alive = [zeros(1, frame - 1) 1 zeros(1, timePoints - frame)];
                                        finishedCells(end).Parent = 0;
                                        finishedCells(end).Touching = 0;
                                        finishedCells(end).CombinedCentroid = [];
                                        finishedCells(end).Constriction = zeros(1, frame);
                                        finishedCells(end).Note = {''};
                                        finishedCells(i).Area(frame) = finishedCells(i).Area(frame) - finishedCells(end).Area(frame);
                                        finishedCells(i).Centroid(frame, :) = finishedCells(i).BoundingBox(frame, 1:2) + d(1).Centroid;
                                        finishedCells(i).BoundingBox(frame, :) = [finishedCells(i).BoundingBox(frame, 1:2) 0 0] + d(1).BoundingBox;
                                        finishedCells(i).RedIntensity(frame) = d(1).RedIntensity;
                                        finishedCells(i).GreenIntensity(frame) = d(1).GreenIntensity;
                                        finishedCells(i).Ratio(frame) = finishedCells(i).RedIntensity(frame) / finishedCells(i).GreenIntensity(frame);
                                        finishedCells(i).Perimeter(frame) = d(1).Perimeter;
                                        video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Rectangle', finishedCells(i).BoundingBox(frame, :) .* scaled, 'LineWidth', ls, 'Color', color);
                                        video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Rectangle', finishedCells(end).BoundingBox(frame, :) .* scaled, 'LineWidth', ls, 'Color', uint8([255 255 255]) - color);
                                        video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'FilledCircle', [finishedCells(i).Centroid(frame, :) ls] .* scaled, 'Color', color);
                                        video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'FilledCircle', [finishedCells(end).Centroid(frame, :) ls] .* scaled, 'Color', uint8([255 255 255]) - color);
                                        if frame > 1 && finishedCells(i).Alive(frame - 1)
                                            video(:, :, :, frame) = insertShape(video(:, :, :, frame), 'Line', [finishedCells(i).Centroid(frame - 1, :) finishedCells(i).Centroid(frame, :)] .* scaled, 'LineWidth', ls, 'Color', color);
                                        end
                                        if frame < timePoints && finishedCells(i).Alive(frame + 1)
                                            video(:, :, :, frame + 1) = insertShape(video(:, :, :, frame + 1), 'Line', [finishedCells(i).Centroid(frame, :) finishedCells(i).Centroid(frame + 1, :)] .* scaled, 'LineWidth', ls, 'Color', color);
                                        end
                                        imshow(video(:, :, :, frame))
                                        selectedCell = 0;
                                        selectedFrame = 0;
                                        pos1 = [0 0 0 0];
                                        pos2 = [0 0 0 0];
                                        r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                        r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                        return
                                    end
                                end
                            else
                                if ~(finishedCells(i).TimeAppearing == frame && finishedCells(selectedCell).TimeAppearing == frame)
                                    c = questdlg('What do you want to do with these cells?', 'Accuracy Check', 'Switch', 'Merge', 'Switch');
                                else
                                    c = questdlg('Merge these cells?', 'Accuracy Check', 'Yes', 'No', 'Yes');
                                end
                                %% different cell was clicked on. ask what to do
                                if strcmp(c, 'Switch')
                                    finishedCellsSave = finishedCells;
                                    videoSave = video;
                                    %% switch cell tracks
                                    temp = finishedCells(selectedCell);
                                    if find(finishedCells(i).Alive, 1) < frame
                                        for p = frame:min(frame + 10, timePoints)
                                            video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(i).Centroid(frame, :) finishedCells(i).Centroid(frame - 1, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        end
                                    end
                                    if find(temp.Alive, 1) < frame
                                        for p = frame:min(frame + 10, timePoints)
                                            video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [temp.Centroid(frame, :) temp.Centroid(frame - 1, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        end
                                    end
                                    color1 = reshape(video(round(finishedCells(i).BoundingBox(frame, 2) .* scaled), round(finishedCells(i).BoundingBox(frame, 1) .* scaled), :, frame), 1, 3);
                                    color2 = reshape(video(round(temp.BoundingBox(frame, 2) .* scaled), round(temp.BoundingBox(frame, 1) .* scaled), :, frame), 1, 3);
                                    p = frame:find(finishedCells(i).Alive, 1, 'last');
                                    %put cell i's data in cell selectedCell
                                    finishedCells(selectedCell).Area(p) = finishedCells(i).Area(p);
                                    finishedCells(selectedCell).Centroid(p, :) = finishedCells(i).Centroid(p, :);
                                    finishedCells(selectedCell).BoundingBox(p, :) = finishedCells(i).BoundingBox(p, :);
                                    finishedCells(selectedCell).RedIntensity(p) = finishedCells(i).RedIntensity(p);
                                    finishedCells(selectedCell).GreenIntensity(p) = finishedCells(i).GreenIntensity(p);
                                    finishedCells(selectedCell).Rupture(p) = finishedCells(i).Rupture(p);
                                    finishedCells(selectedCell).Alive(p) = finishedCells(i).Alive(p);
                                    finishedCells(selectedCell).Constriction(p) = finishedCells(i).Constriction(p);
                                    finishedCells(selectedCell).Perimeter(p) = finishedCells(i).Perimeter(p);
                                    finishedCells(selectedCell).Ratio(p) = finishedCells(i).Ratio(p);
                                    %delete leftover selectedCell data
                                    p = find(finishedCells(i).Alive, 1, 'last');
                                    finishedCells(selectedCell).Area = finishedCells(selectedCell).Area(1:p);
                                    finishedCells(selectedCell).Centroid = finishedCells(selectedCell).Centroid(1:p, :);
                                    finishedCells(selectedCell).BoundingBox = finishedCells(selectedCell).BoundingBox(1:p, :);
                                    finishedCells(selectedCell).RedIntensity = finishedCells(selectedCell).RedIntensity(1:p);
                                    finishedCells(selectedCell).GreenIntensity = finishedCells(selectedCell).GreenIntensity(1:p);
                                    if p < timePoints
                                        finishedCells(selectedCell).Rupture((p + 1):timePoints) = deal(0);
                                        finishedCells(selectedCell).Alive((p + 1):timePoints) = deal(0);
                                    end
                                    finishedCells(selectedCell).Constriction = finishedCells(selectedCell).Constriction(1:p);
                                    finishedCells(selectedCell).Perimeter = finishedCells(selectedCell).Perimeter(1:p);
                                    finishedCells(selectedCell).Ratio = finishedCells(selectedCell).Ratio(1:p);
                                    p = frame:find(temp.Alive, 1, 'last');
                                    %put cell selectedCell's data in cell i
                                    finishedCells(i).Area(p) = temp.Area(p);
                                    finishedCells(i).Centroid(p, :) = temp.Centroid(p, :);
                                    finishedCells(i).BoundingBox(p, :) = temp.BoundingBox(p, :);
                                    finishedCells(i).RedIntensity(p) = temp.RedIntensity(p);
                                    finishedCells(i).GreenIntensity(p) = temp.GreenIntensity(p);
                                    finishedCells(i).Rupture(p) = temp.Rupture(p);
                                    finishedCells(i).Alive(p) = temp.Alive(p);
                                    finishedCells(i).Constriction(p) = temp.Constriction(p);
                                    finishedCells(i).Perimeter(p) = temp.Perimeter(p);
                                    finishedCells(i).Ratio(p) = temp.Ratio(p);
                                    %delete leftover cell i data
                                    p = find(temp.Alive, 1, 'last');
                                    finishedCells(i).Area = finishedCells(i).Area(1:p);
                                    finishedCells(i).Centroid = finishedCells(i).Centroid(1:p, :);
                                    finishedCells(i).BoundingBox = finishedCells(i).BoundingBox(1:p, :);
                                    finishedCells(i).RedIntensity = finishedCells(i).RedIntensity(1:p);
                                    finishedCells(i).GreenIntensity = finishedCells(i).GreenIntensity(1:p);
                                    if p < timePoints
                                        finishedCells(i).Rupture(length((p + 1):timePoints)) = deal(0);
                                        finishedCells(i).Alive((p + 1):timePoints) = deal(0);
                                    end
                                    finishedCells(i).Constriction = finishedCells(i).Constriction(1:p);
                                    finishedCells(i).Perimeter = finishedCells(i).Perimeter(1:p);
                                    finishedCells(i).Ratio = finishedCells(i).Ratio(1:p);
                                    %draw new tracks
                                    for p = frame:find(finishedCells(i).Alive, 1, 'last')
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1), p - 10):(p - 1), :) finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1) + 1, p - 9):p, :)] .* scaled, 'LineWidth', ls, 'Color', color1);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'FilledCircle', [finishedCells(i).Centroid(p, :) ls] .* scaled, 'Color', color1);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Rectangle', finishedCells(i).BoundingBox(p, :) .* scaled, 'LineWidth', ls, 'Color', color1);
                                    end
                                    for p = frame:find(finishedCells(selectedCell).Alive, 1, 'last')
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1), p - 10):(p - 1), :) finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1) + 1, p - 9):p, :)] .* scaled, 'LineWidth', ls, 'Color', color2);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'FilledCircle', [finishedCells(selectedCell).Centroid(p, :) ls] .* scaled, 'Color', color2);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Rectangle', finishedCells(selectedCell).BoundingBox(p, :) .* scaled, 'LineWidth', ls, 'Color', color2);
                                    end
                                    imshow(video(:, :, :, frame))
                                    selectedCell = 0;
                                    selectedFrame = 0;
                                    pos1 = [0 0 0 0];
                                    pos2 = [0 0 0 0];
                                    r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    return
                                elseif strcmp(c, 'Merge') || strcmp(c, 'Yes')
                                    finishedCellsSave = finishedCells;
                                    videoSave = video;
                                    %% merge nuclei
                                    color = mean([reshape(video(round(finishedCells(i).BoundingBox(frame, 2) .* scaled), round(finishedCells(i).BoundingBox(frame, 1) .* scaled), :, frame), 1, 3); reshape(video(round(finishedCells(selectedCell).BoundingBox(frame, 2) .* scaled), round(finishedCells(selectedCell).BoundingBox(frame, 1) .* scaled), :, frame), 1, 3)]);
                                    for j = find(finishedCells(i).Alive)
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'Line', [finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1), j - 10):(j - 1), :) finishedCells(i).Centroid(max(find(finishedCells(i).Alive, 1) + 1, j - 9):j, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'Rectangle', finishedCells(i).BoundingBox(j, :) .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'FilledCircle', [finishedCells(i).Centroid(j, :) ls] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                    end
                                                                        
                                    p = finishedCells(selectedCell).Alive & finishedCells(i).Alive;
                                    for j = find(p)
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'Line', [finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1), j - 10):(j - 1), :) finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1) + 1, j - 9):j, :)] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'Rectangle', finishedCells(selectedCell).BoundingBox(j, :) .* scaled, 'LineWidth', ls, 'Color', 'black');
                                        video(:, :, :, j) = insertShape(video(:, :, :, j), 'FilledCircle', [finishedCells(selectedCell).Centroid(j, :) ls] .* scaled, 'LineWidth', ls, 'Color', 'black');
                                    end
                                    finishedCells(selectedCell).RedIntensity(p) = (finishedCells(selectedCell).RedIntensity(p) .* finishedCells(selectedCell).Area(p) + finishedCells(i).RedIntensity(p) .* finishedCells(i).Area(p)) ./ (finishedCells(selectedCell).Area(p) + finishedCells(i).Area(p));
                                    finishedCells(selectedCell).GreenIntensity(p) = (finishedCells(selectedCell).GreenIntensity(p) .* finishedCells(selectedCell).Area(p) + finishedCells(i).GreenIntensity(p) .* finishedCells(i).Area(p)) ./ (finishedCells(selectedCell).Area(p) + finishedCells(i).Area(p));
                                    finishedCells(selectedCell).Ratio(p) = finishedCells(selectedCell).RedIntensity(p) ./ finishedCells(selectedCell).GreenIntensity(p);
                                    finishedCells(selectedCell).Centroid(p, :) = (finishedCells(selectedCell).Centroid(p, :) .* [finishedCells(selectedCell).Area(p); finishedCells(selectedCell).Area(p)]' + finishedCells(i).Centroid(p, :) .* [finishedCells(i).Area(p); finishedCells(i).Area(p)]') ./ ([finishedCells(selectedCell).Area(p)+finishedCells(i).Area(p); finishedCells(selectedCell).Area(p)+finishedCells(i).Area(p)]');
                                    finishedCells(selectedCell).BoundingBox(p, :) = [min(finishedCells(selectedCell).BoundingBox(p, 1), finishedCells(i).BoundingBox(p, 1)) min(finishedCells(selectedCell).BoundingBox(p, 2), finishedCells(i).BoundingBox(p, 2)) max(finishedCells(selectedCell).BoundingBox(p, 1) + finishedCells(selectedCell).BoundingBox(p, 3), finishedCells(i).BoundingBox(p, 1) + finishedCells(i).BoundingBox(p, 3))-min(finishedCells(selectedCell).BoundingBox(p, 1), finishedCells(i).BoundingBox(p, 1)) max(finishedCells(selectedCell).BoundingBox(p, 2) + finishedCells(selectedCell).BoundingBox(p, 4), finishedCells(i).BoundingBox(p, 2) + finishedCells(i).BoundingBox(p, 4))-min(finishedCells(selectedCell).BoundingBox(p, 2), finishedCells(i).BoundingBox(p, 2))];
                                    finishedCells(selectedCell).Area(p) = finishedCells(selectedCell).Area(p) + finishedCells(i).Area(p);
                                    finishedCells(selectedCell).Rupture(p) = finishedCells(selectedCell).Rupture(p) > 0 | finishedCells(i).Rupture(p) > 0;
                                    finishedCells(selectedCell).Perimeter(p) = finishedCells(selectedCell).Perimeter(p) + finishedCells(i).Perimeter(p);
                                    for p = find(p)
                                        if any(finishedCells(i).Constriction(p) == [1 2 3])
                                            finishedCells(selectedCell).Constriction(p) = finishedCells(i).Constriction(p);
                                        else
                                            finishedCells(selectedCell).Constriction(p) = max(finishedCells(selectedCell).Constriction(p), finishedCells(i).Constriction(p));
                                        end
                                    end
                                    
                                    p = ~finishedCells(selectedCell).Alive & finishedCells(i).Alive;
                                    finishedCells(selectedCell).Alive(p) = finishedCells(i).Alive(p);
                                    finishedCells(selectedCell).RedIntensity(p) = finishedCells(i).RedIntensity(p);
                                    finishedCells(selectedCell).GreenIntensity(p) = finishedCells(i).GreenIntensity(p);
                                    finishedCells(selectedCell).Ratio(p) = finishedCells(selectedCell).RedIntensity(p) ./ finishedCells(selectedCell).GreenIntensity(p);
                                    finishedCells(selectedCell).Perimeter(p) = finishedCells(i).Perimeter(p);
                                    finishedCells(selectedCell).Centroid(p, :) = finishedCells(i).Centroid(p, :);
                                    finishedCells(selectedCell).BoundingBox(p, :) = finishedCells(i).BoundingBox(p, :);
                                    finishedCells(selectedCell).Area(p) = finishedCells(i).Area(p);
                                    finishedCells(selectedCell).Rupture(p) = finishedCells(i).Rupture(p);
                                    finishedCells(selectedCell).Constriction(p) = finishedCells(i).Constriction(p);
                                    
                                    for p = find(finishedCells(selectedCell).Alive)
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1), p - 10):(p - 1), :) finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1) + 1, p - 9):p, :)] .* scaled, 'LineWidth', ls, 'Color', color);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'FilledCircle', [finishedCells(selectedCell).Centroid(p, :) ls] .* scaled, 'Color', color);
                                        video(:, :, :, p) = insertShape(video(:, :, :, p), 'Rectangle', finishedCells(selectedCell).BoundingBox(p, :) .* scaled, 'LineWidth', ls, 'Color', color);
                                    end
                                    finishedCells(selectedCell).TimeAppearing = min(finishedCells(selectedCell).TimeAppearing, finishedCells(i).TimeAppearing);
                                    finishedCells(i) = [];
                                    imshow(video(:, :, :, frame))
                                    selectedCell = 0;
                                    selectedFrame = 0;
                                    pos1 = [0 0 0 0];
                                    pos2 = [0 0 0 0];
                                    r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                    return
                                end
                            end
                        elseif all(~(finishedCells(selectedCell).Alive == 1 & finishedCells(i).Alive == 1))
                            if strcmp(questdlg('Connect these objects'' tracks?', 'Accuracy Check', 'Yes', 'No', 'Yes'), 'Yes')
                                finishedCellsSave = finishedCells;
                                videoSave = video;
                                %% ask if the two cells are the same and their line should be connected
                                color = mean([reshape(video(round(finishedCells(i).BoundingBox(frame, 2) .* scaled), round(finishedCells(i).BoundingBox(frame, 1) .* scaled), :, frame), 1, 3); reshape(video(round(finishedCells(selectedCell).BoundingBox(selectedFrame, 2) .* scaled), round(finishedCells(selectedCell).BoundingBox(selectedFrame, 1) .* scaled), :, selectedFrame), 1, 3)]);
                                if find(finishedCells(i).Alive, 1) < find(finishedCells(selectedCell).Alive, 1)
                                    j = i;
                                else
                                    j = selectedCell;
                                    selectedCell = i;
                                end
                                finishedCells(selectedCell).TimeAppearing = finishedCells(j).TimeAppearing;
                                finishedCells(selectedCell).Parent = finishedCells(j).Parent;
                                k = (find(finishedCells(j).Alive, 1, 'last') + 1):(find(finishedCells(selectedCell).Alive, 1) - 1);
                                p = find(finishedCells(j).Alive);
                                finishedCells(selectedCell).Area(p) = finishedCells(j).Area(p);
                                finishedCells(selectedCell).Centroid(p, :) = finishedCells(j).Centroid(p, :);
                                finishedCells(selectedCell).BoundingBox(p, :) = finishedCells(j).BoundingBox(p, :);
                                finishedCells(selectedCell).RedIntensity(p) = finishedCells(j).RedIntensity(p);
                                finishedCells(selectedCell).GreenIntensity(p) = finishedCells(j).GreenIntensity(p);
                                finishedCells(selectedCell).Ratio(p) = finishedCells(selectedCell).RedIntensity(p) ./ finishedCells(selectedCell).GreenIntensity(p);
                                finishedCells(selectedCell).Rupture(p) = finishedCells(j).Rupture(p);
                                finishedCells(selectedCell).Alive(p) = finishedCells(j).Alive(p);
                                finishedCells(selectedCell).Constriction(p) = finishedCells(j).Constriction(p);
                                finishedCells(selectedCell).Perimeter(p) = finishedCells(j).Perimeter(p);
                                for p = k
                                    finishedCells(selectedCell).Area(p) = finishedCells(selectedCell).Area(p - 1) + (finishedCells(selectedCell).Area(k(end) + 1) - finishedCells(selectedCell).Area(k(1) - 1)) ./ (k(end) - k(1) + 2);
                                    finishedCells(selectedCell).Centroid(p, :) = finishedCells(selectedCell).Centroid(p - 1, :) + (finishedCells(selectedCell).Centroid(k(end) + 1, :) - finishedCells(selectedCell).Centroid(k(1) - 1, :)) ./ (k(end) - k(1) + 2);
                                    finishedCells(selectedCell).BoundingBox(p, :) = finishedCells(selectedCell).BoundingBox(p - 1, :) + (finishedCells(selectedCell).BoundingBox(k(end) + 1, :) - finishedCells(selectedCell).BoundingBox(k(1) - 1, :)) ./ (k(end) - k(1) + 2);
                                    finishedCells(selectedCell).RedIntensity(p) = finishedCells(selectedCell).RedIntensity(p - 1) + (finishedCells(selectedCell).RedIntensity(k(end) + 1) - finishedCells(selectedCell).RedIntensity(k(1) - 1)) ./ (k(end) - k(1) + 2);
                                    finishedCells(selectedCell).GreenIntensity(p) = finishedCells(selectedCell).GreenIntensity(p - 1) + (finishedCells(selectedCell).GreenIntensity(k(end) + 1) - finishedCells(selectedCell).GreenIntensity(k(1) - 1)) ./ (k(end) - k(1) + 2);
                                    finishedCells(selectedCell).Perimeter(p) = finishedCells(selectedCell).Perimeter(p - 1) + (finishedCells(selectedCell).Perimeter(k(end) + 1) - finishedCells(selectedCell).Perimeter(k(1) - 1)) ./ (k(end) - k(1) + 2);
                                    ratio1 = finishedCells(selectedCell).RedIntensity(p) / finishedCells(selectedCell).GreenIntensity(p);
                                    finishedCells(selectedCell).Ratio(p) = ratio1;
                                    if (finishedCells(selectedCell).BoundingBox(p, 2) > loc(section, 6) - 140 && finishedCells(selectedCell).BoundingBox(p, 2) + finishedCells(selectedCell).BoundingBox(p, 4) < loc(section, 1) + 140) || finishedCells(selectedCell).Rupture(p - 1)
                                       ratio2 = finishedCells(selectedCell).Ratio(p - 1);
                                       if (ratio1 - ratio2) / ratio2 > 0.2
                                           finishedCells(selectedCell).Rupture(p) = 1;
                                       elseif finishedCells(selectedCell).Rupture(p - 1) == 1
                                           if (ratio1 - ratio2) / ratio2 > 0.175
                                               finishedCells(selectedCell).Rupture(p) = 1;
                                           elseif (ratio2 - ratio1) / ratio1 > 0.075 
                                               finishedCells(selectedCell).Rupture(p) = 0.5;
                                           else
                                               finishedCells(selectedCell).Rupture(p) = 1;
                                           end
                                       elseif finishedCells(selectedCell).Rupture(p - 1) == 0.5
                                           if (ratio1 - ratio2) / ratio2 > 0.1
                                               finishedCells(selectedCell).Rupture(p) = 1;
                                           elseif (ratio2 - ratio1) / ratio1 > 0.03
                                               finishedCells(selectedCell).Rupture(p) = 0.5;
                                           else
                                               finishedCells(selectedCell).Rupture(p) = 0.25;
                                           end
                                       elseif finishedCells(selectedCell).Rupture(p - 1) == 0.25
                                           if (ratio1 - ratio2) / ratio2 > 0.125
                                               finishedCells(selectedCell).Rupture(p) = 0.1;
                                           elseif (ratio2 - ratio1) / ratio1 > 0.05
                                               finishedCells(selectedCell).Rupture(p) = 0.5;
                                           elseif (ratio2 - ratio1) / ratio1 > 0.03
                                               finishedCells(selectedCell).Rupture(p) = 0.25;
                                           end
                                       end
                                    end
                                    finishedCells(selectedCell).Alive(p) = 0.5;
                                    if constr ~= 0
                                        %top of cell below bottom of constriction 1
                                        if finishedCells(selectedCell).BoundingBox(p, 2) > loc(section, 1)
                                            finishedCells(selectedCell).Constriction(p) = 0.2;
                                        %bottom of cell below top of constriction 1
                                        elseif finishedCells(selectedCell).BoundingBox(p, 2) + finishedCells(selectedCell).BoundingBox(p, 4) > loc(section, 2)
                                            finishedCells(selectedCell).Constriction(p) = 1;
                                        %top of cell below bottom of constriction 2
                                        elseif finishedCells(selectedCell).BoundingBox(p, 2) > loc(section, 3)
                                            finishedCells(selectedCell).Constriction(p) = 1.2;
                                        %bottom of cell below top of constriction 2
                                        elseif finishedCells(selectedCell).BoundingBox(p, 2) + finishedCells(selectedCell).BoundingBox(p, 4) > loc(section, 4)
                                            finishedCells(selectedCell).Constriction(p) = 2;
                                        %top of cell below bottom of constriction 3
                                        elseif finishedCells(selectedCell).BoundingBox(p, 2) > loc(section, 5)
                                            finishedCells(selectedCell).Constriction(p) = 2.2;
                                        %bottom of cell below top of constriction 3
                                        elseif finishedCells(selectedCell).BoundingBox(p, 2) + finishedCells(selectedCell).BoundingBox(p, 4) > loc(section, 6)
                                            finishedCells(selectedCell).Constriction(p) = 3;
                                        %bottom of cell above top of constriction 3
                                        else
                                            finishedCells(selectedCell).Constriction(p) = 3.2;
                                        end
                                    end
                                    if finishedCells(selectedCell).Rupture(p) && finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                        video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'CR', 'FontSize', fs, 'BoxColor', 'white');
                                    elseif finishedCells(selectedCell).Rupture(p)
                                        video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'R', 'FontSize', fs, 'BoxColor', 'white');
                                    elseif finishedCells(selectedCell).Constriction(p) == floor(finishedCells(selectedCell).Constriction(p))
                                        video(:, :, :, p) = insertText(video(:, :, :, p), finishedCells(selectedCell).BoundingBox(p, 1:2) .* scaled, 'C', 'FontSize', fs, 'BoxColor', 'magenta');
                                    end
                                end
                                for p = find(finishedCells(selectedCell).Alive)
                                    video(:, :, :, p) = insertShape(video(:, :, :, p), 'Line', [finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1), p - 10):(p - 1), :) finishedCells(selectedCell).Centroid(max(find(finishedCells(selectedCell).Alive, 1) + 1, p - 9):p, :)] .* scaled, 'LineWidth', ls, 'Color', color);
                                    video(:, :, :, p) = insertShape(video(:, :, :, p), 'FilledCircle', [finishedCells(selectedCell).Centroid(p, :) ls] .* scaled, 'Color', color);
                                    video(:, :, :, p) = insertShape(video(:, :, :, p), 'Rectangle', finishedCells(selectedCell).BoundingBox(p, :) .* scaled, 'LineWidth', ls, 'Color', color);
                                end
                                finishedCells(j) = [];
                                imshow(video(:, :, :, frame))
                                selectedCell = 0;
                                selectedFrame = 0;
                                pos1 = [0 0 0 0];
                                pos2 = [0 0 0 0];
                                r = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                                return
                            end
                        end
                    end
                end
                selectedCell = 0;
                selectedFrame = 0;
                r.Position = [0 0 0 0];
                try
                    r2.Position = [0 0 0 0];
                catch
                    r2 = rectangle('Position', [0 0 0 0], 'LineWidth', 3, 'EdgeColor', 'white');
                end
                pos1 = [0 0 0 0];
                pos2 = [0 0 0 0];
            end
        end
    end
end