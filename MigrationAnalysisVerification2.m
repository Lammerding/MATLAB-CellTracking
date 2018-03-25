%% Instructions
% 1. Open the folder you chose to save the data to when using the analysis2 program
%        Select the folder with the name of the experiment you analyzed

% 2. Correct the image sequences one at a time
%     Move through the video by clicking and dragging the scroll bar, using the mouse's scroll whell, or pressing arrow keys
%     The colors of the boxes are important
%         Gray nuclei don't do anything
%         Light blue ones rupture
%         Magenta ones attempt constrictions
%         Dark blue ones rupture and attempt constrictions
%         No information will be recorded for gray ones, you don't need to spend time making them perfect
%     Commands you can use to correct the image sequences:
%         Left click the same nucleus twice in the same frame:
%             Delete the cell
%                 Useful if an identified object isn't a nucleus
%             Split the object identified by the program into two nuclei
%                 Useful if two nuclei touched and were only seen as one object
%             Disconnect the nucleus in a frame from its track in previous frames
%                 Useful if a cell died as another reappeared and they were mistakenly thought to be the same cell
%                 Can only be done if the nucleus did not appear in the current frame
%         Left click two different nuclei in the same frame:
%             Merge two program identified objects into one nucleus
%                 Useful if the program mistakenly split one nucleus in two
%             Switch tracks of nuclei from the current frame forward
%                 Useful if two nuclei are mistakenly switched by the program during tracking
%                 Can't be done if both nuclei first appeared in the current frame
%         Left click two different objects in different frames:
%             Connect the two nuclei's tracks
%                 Useful if a nucleus disappears and later reappears
%                 Can't be done if the two selected objects are ever present during the same frame
%         Right click a cell:
%             Leave a note about the cell
%                 Useful if the cell does something interesting or abnormal
%                 The note will appear in the excel file
%                 Only the most recent note will be saved
%             Start a rupture
%                 Then scroll forward and click in the frame where it ends
%                 Useful if an incidence of rupture is not identified
%                 * Only if both NLS and H2B are present
%             End a rupture early
%                 Useful if a rupture is idnetified as continuing longer than it should
%                 Can only be done if the nucleus is currently identified as ruptured
%                 * Only if both NLS and H2B are present
%             Cancel a rupture entirely
%                 Useful if an identified rupture never actually happened
%                 Can only be done if the nucleus is currently identified as ruptured
%                 * Only if both NLS and H2B are present
%         Right click not on a cell:
%             Delete entire section
%                 Write a note as to why it's being deleted (for example, cells going under)
%                 The note will ppear in the excel file
%             Undo last action taken
%                 Can only be done if at least one edit has been made so far
%                 Can only undo the most recent action (which may have been an undo)

% 3. You're finished
%        An excel file with the data from the experiment is in the folder you selected during analysis2

%%
warning('off', 'all')
addpath('Migration Analysis')
fprintf('Getting user input...')

%% user selects folder to load data from
loadFolder = uigetdir('D:\', 'Please select folder to load data from');
if loadFolder == 0
    fprintf('\nNo file selected\n')
    return
end

channels3 = loadFolder(end - 1) == 'B';

if ispc
    files = dir([loadFolder '\*.mat']);
else
    files = dir([loadFolder '/*.mat']);
end
for f = length(files):-1:1
    if strfind(files(f).name, 'error message (section ')
        files(f) = [];
    end
end

if isempty(files)
    fprintf('\nNo .mat files found in directory %s.\n', loadFolder)
    return
end

f = inputdlg('Which section do you want to start analyzing from?', 'Accuracy Check', 1, {'1'});
if ~isempty(f)
    f = str2double(f);
    for i = 1:length(files)
        firstPos = str2double(files(i).name(1:(end - 4)));
        if isnan(firstPos)
            firstPos = str2double(files(i).name(2:(end - 4)));
        end
        if firstPos >= f
            files(1:(i - 1)) = [];
            break
        end
    end
end

name = loadFolder((find(loadFolder == '\', 1, 'last') + 1):end);

global finishedCells

fprintf('\nLoading data...')

%% print headers into save file
if ispc
    f = [loadFolder '\row 1.csv'];
else
    f = [loadFolder '/row 1.csv'];
end
if exist(f, 'file')
    f = [f(1:(end - 4)) ' (2).csv'];
    i = 3;
    while exist(f, 'file') && i < 10
        f(end - 5) = num2str(i);
        i = i + 1;
    end
end
fid = fopen(f, 'w+');
if ispc
    f = [loadFolder '\row 2.csv'];
else
    f = [loadFolder '/row 2.csv'];
end
if exist(f, 'file')
    f = [f(1:(end - 4)) ' (2).csv'];
    i = 3;
    while exist(f, 'file') && i < 10
        f(end - 5) = num2str(i);
        i = i + 1;
    end
end
fid2 = fopen(f, 'w+');
if ispc
    f = [loadFolder '\row 3.csv'];
else
    f = [loadFolder '/row 3.csv'];
end
if exist(f, 'file')
    f = [f(1:(end - 4)) ' (2).csv'];
    i = 3;
    while exist(f, 'file') && i < 10
        f(end - 5) = num2str(i);
        i = i + 1;
    end
end
fid3 = fopen(f, 'w+');
if ispc
    f = [loadFolder '\successes.csv'];
else
    f = [loadFolder '/successes.csv'];
end
if exist(f, 'file')
    f = [f(1:(end - 4)) ' (2).csv'];
    i = 3;
    while exist(f, 'file') && i < 10
        f(end - 5) = num2str(i);
        i = i + 1;
    end
end
fidS = fopen(f, 'w+');
fprintf(fid, ',,,,,,,,,Constriction Passage\nDate,Position number,Duration of movie,Cell #, Initial time point,Initial X,Initial Y,Constriction size?,Notes,Constriction #,Time starting,Time finishing,Duration,Successful? (1 or 0)');
fprintf(fid2, ',,,,,,,,,Constriction Passage\nDate,Position number,Duration of movie,Cell #, Initial time point,Initial X,Initial Y,Constriction size?,Notes,Constriction #,Time starting,Time finishing,Duration,Successful? (1 or 0)');
fprintf(fid3, ',,,,,,,,,Constriction Passage\nDate,Position number,Duration of movie,Cell #, Initial time point,Initial X,Initial Y,Constriction size?,Notes,Constriction #,Time starting,Time finishing,Duration,Successful? (1 or 0)');
fprintf(fidS, ',,,,,,,,,Constriction Passage\nDate,Position number,Duration of movie,Cell #, Initial time point,Initial X,Initial Y,Constriction size?,Notes,Constriction #,Time starting,Time finishing,Duration,Successful? (1 or 0),,Nucleus total movement until top edge reaches center of constrictions,Nucleus average speed until top edge reaches center of constrictions,Nucleus time until top edge reaches center of constrictions');
if channels3
    rmpath('analysis with NLS only')
    addpath('analysis with NLS and H2B')
    if ispc
        f = [loadFolder '\rupture.csv'];
    else
        f = [loadFolder '/rupture.csv'];
    end
    if exist(f, 'file')
        f = [f(1:(end - 4)) ' (2).csv'];
        i = 3;
        while exist(f, 'file') && i < 10
            f(end - 5) = num2str(i);
            i = i + 1;
        end
    end
    fidR = fopen(f, 'w+');
    fprintf(fidR, ',,,,,,,,,,,,,Rupture 1,,,,,,,,,Rupture 2,,,,,,,,,Rupture 3,,,,,,,,,Rupture 4,,,,,,,,,Rupture 5,,,,,,,,,Rupture 6\nDate,Position number,Duration of movie,Cell #,Initial time point,Initial X,Initial Y,Does cell rupture? (1 or 0),Total rupture events,Cell dies due to rupture? (1 or 0),Does cell divide? (1 or 0),Constriction size?,Notes,Rupture due to constriction? (1 or 0),Which constriction? (1 2 or 3),Rupture without visible cause? (1 or 0),Intensity of rupture,Time of rupture,Time repaired,Duration,Rerupture? (1 or 0),Deformed post rupture (1 or 0)?');
    for i = 1:5
        fprintf(fidR, ',Rupture due to constriction?,Constriction size,Rupture without visible cause?,Intensity of rupture,Time of rupture,Time repaired,Duration of rupture,Rerupture?,Deformed post rupture?');
    end
    if ispc
        f = [loadFolder '\rupture2.csv'];
    else
        f = [loadFolder '/rupture2.csv'];
    end
    if exist(f, 'file')
        f = [f(1:(end - 4)) ' (2).csv'];
        i = 3;
        while exist(f, 'file') && i < 10
            f(end - 5) = num2str(i);
            i = i + 1;
        end
    end
    fidR2 = fopen(f, 'w+');
    fprintf(fidR2, 'Position,Cell,,10 frames before rupture,,,,,,,,,,Start of rupture,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,60 frames after rupture starts');
    if ispc
        f = [loadFolder '\unfinished ruptures.csv'];
    else
        f = [loadFolder '/unfinished ruptures.csv'];
    end
    if exist(f, 'file')
        f = [f(1:(end - 4)) ' (2).csv'];
        i = 3;
        while exist(f, 'file') && i < 10
            f(end - 5) = num2str(i);
            i = i + 1;
        end
    end
    fidR3 = fopen(f, 'w+');
    fprintf(fidR3, 'Ruptures not completed by end of video\nPosition Number,Cell Number,Rupture due to constriction?,Which constriction?,Constriction size,Rupture without visible cause?,Intensity of rupture,Time of rupture,Time repaired');
else
    rmpath('analysis with NLS and H2B')
    addpath('analysis with NLS only')
end

fprintf('\nCorrecting images...')
%% go through .mat files and display videos and let user correct them
unfinishedRuptures = struct();
for f = 1:length(files)
    s = str2double(files(f).name(1:(end - 4)));
    if isnan(s)
        s = str2double(files(f).name(2:(end - 4)));
    end
    fprintf('\n\tSection %g...', s)
    
    if ispc
        o = matfile([loadFolder '\' files(f).name], 'Writable', true);
    else
        o = matfile([loadFolder '/' files(f).name], 'Writable', true);
    end
    
    frameRate = o.frameRate;
    c = o.c;
    loc = o.loc;
    
    timePoints = -1;
    fprintf('\n\t\tGetting user input...')
    if channels3
        while timePoints == -1
            finishedCells = o.finishedCells;
            [finishedCells.Note] = deal({''});
            try
                [message, timePoints] = correctVideoNLSH2B2(o.video5, o.v, o.v2, s, c, loc, o.scaled);
            catch e
                save([loadFolder '\error message (section ' num2str(s) ').mat']);
                fprintf('Warning: An error occurred!');
                timePoints = 0;
            end
        end
        fprintf('\n\t\tSaving results...')
        try
            % save nuclei positions
            if ispc
                mkdir([loadFolder '\nucleus positions'])
                fLoc = [loadFolder '\nucleus positions\section ' num2str(s) ' (constriction size ' num2str(c) ').csv'];
            else
                mkdir([loadFolder '/nucleus positions'])
                fLoc = [loadFolder '/nucleus positions/section ' num2str(s) ' (constriction size ' num2str(c) ').csv'];
            end
            fidLoc = fopen(fLoc, 'w+');
            % print column headers
            fprintf(fidLoc, 'Timepoints');
            for i = 1:length(finishedCells)
                fprintf(fidLoc, ',Nucleus %g X,Nucleus %g Y', i, i);
            end
            % print data
            for i = 1:timePoints
                fprintf(fidLoc, '\n%g', i);
                for j = 1:length(finishedCells)
                    if finishedCells(j).Alive(i)
                        fprintf(fidLoc, ',%f,%f', finishedCells(j).Centroid(i, 1), finishedCells(j).Centroid(i, 2));
                    else
                        fprintf(fidLoc, ',,');
                    end
                end
            end
            fclose(fidLoc);
            saveSectionDataNLSH2B
        catch e
            save([loadFolder '\error message (section ' num2str(s) ').mat']);
            fprintf('Warning: An error occurred!');
            timePoints = 0;
        end
    else
        while timePoints == -1
            finishedCells = o.finishedCells;
            [finishedCells.Note] = deal({''});
            try
                timePoints = correctVideoNLS2(o.video5, o.v, s, o.c, loc, o.scaled);
            catch e
                save([loadFolder '\error message (section ' num2str(s) ').mat']);
                fprintf('Warning: An error occurred!');
            end
        end
        fprintf('\n\t\tSaving results...')
        try
            % save nuclei positions
            if ispc
                mkdir([loadFolder '\nucleus positions'])
                fLoc = [loadFolder '\nucleus positions\section ' num2str(s) ' (constriction size ' num2str(c) ').csv'];
            else
                mkdir([loadFolder '/nucleus positions'])
                fLoc = [loadFolder '/nucleus positions/section ' num2str(s) ' (constriction size ' num2str(c) ').csv'];
            end
            fidLoc = fopen(fLoc, 'w+');
            % print column headers
            fprintf(fidLoc, 'Timepoints');
            for i = 1:length(finishedCells)
                fprintf(fidLoc, ',Nucleus %g X,Nucleus %g Y', i, i);
            end
            % print data
            for i = 1:timePoints
                fprintf(fidLoc, '\n%g', i);
                for j = 1:length(finishedCells)
                    if finishedCells(j).Alive(i)
                        fprintf(fidLoc, ',%f,%f', finishedCells(j).Centroid(i, 1), finishedCells(j).Centroid(i, 2));
                    else
                        fprintf(fidLoc, ',,');
                    end
                end
            end
            fclose(fidLoc);
            saveSectionDataNLS
        catch e
            save([loadFolder '\error message (section ' num2str(s) ').mat']);
            fprintf('Warning: An error occurred!');
        end
    end
    
    o.finishedCellsNew = finishedCells;
end

fclose('all');
fprintf('\nFinished.\n')
if ispc
    winopen(loadFolder)
end