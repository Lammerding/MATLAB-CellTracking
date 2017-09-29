%% Instructions
% 1. Select .czi file to analyze

% 2. Select folder to save data to
%        Use the D drive for faster write/read speed

% 3. Enter needed information
%     3.1 Constriction sizes, enter 1, 2, 15, or 0 for each section
%             Enter 0 if the section has no constrictions
%             Enter -1 to skip a section
%         If the constriction sizes repeat in a pattern (1, 2, 1, 15, 2, 1, 1, 2, 1, 15, 2, 1...)
%             you only need to enter the first iteration of the pattern
%     3.2 Which side of the device the cells migrate from
%             This is important, selecting the incorrect option will prevent constriction passage from being monitored properly

% 4. Manually rotate sections with 15 micron constrictions
%     4.1 Drag the endpoints of the line shown such that the line is parallel to the constrictions
%             I usually place the line so it just barely touches the top of one row of constrictions)
%             Press any key to continue
%     4.2 Click on the top and bottom of each constriction
%     4.3 Make sure the rotation and constriction locating was performed properly and redo if necessary

% 5. Check the automatic rotation and constriction iderntification
%     5.1 If there are any errors or sections that couldn't be completed (due to blurriness, for example)
%             or that were done wrong, manually correct them the same way as described in step 4

% 6. Wait. The program will run for a couple of hours

% 7. Run the MigrationAnalysisVerification program

% * Whether just NLS or NLS and H2B are used will be determined
%   automatically. Results are more accurate with both and rupture
%   detection is not supported for just NLS. If there are more than three
%   channels, you will need to specify which order they are in. 

%%
warning('off', 'all');
addpath('bfmatlab', 'Migration Analysis')
fprintf('Getting user input...')

%% user selects .czi file with data to analyze
[fileName, filePath] = uigetfile('N:\*.czi', 'Please select the .czi image file');
if fileName == 0
    fprintf('\nNo file selected.\n')
    return
end

%% user selects folder to save data to. use D drive for better writing/reading speed
saveFolder = uigetdir('D:\', 'Please select folder to save data to');
if saveFolder == 0
    fprintf('\n')
    return
end
saveFolder = [saveFolder '\' fileName(1:(min([find(fileName == '(', 1, 'last'), find(fileName == '.', 1, 'last')]) - 1))];

sections = questdlg('Analyze all device sections or a subset?', 'Accuracy Check', 'All', 'Subset', 'All');
if sections(1) == 'S'
    sections = unique(str2num(cell2mat(inputdlg('Enter which sections you want to analyze, separated by spaces or commas.')))); %#ok<ST2NM>
    if isempty(sections)
        fprintf('\n')
        return
    end
end

constrictionSize = cell2mat(inputdlg('Enter constriction sizes separated by spaces or commas. You only need to enter the sizes until they repeat in a cycle. Enter -1 to skip a section.', 'Accuracy Check', 1, {'1, 2, 15, 1, 2, 1'}));
if isempty(constrictionSize)
    fprintf('\n')
    return
end
constrictionSize = str2num(constrictionSize); %#ok<ST2NM>

cellsFromTop = questdlg('Which side are the cells coming from?', 'Accuracy Check', 'Bottom', 'Top', 'Bottom');
if isempty(cellsFromTop)
    fprintf('\n')
    return
end
cellsFromTop = strcmp(cellsFromTop, 'Top');

%% load and prepare image reader
fprintf('\nSetting up Bio-Formats reader...')
if exist([filePath fileName(1:(min([find(fileName == '(', 1, 'last'), find(fileName == '.', 1, 'last')]) - 1)) '.czi'], 'file')
    filePath = [filePath fileName(1:(min([find(fileName == '(', 1, 'last'), find(fileName == '.', 1, 'last')]) - 1)) '.czi'];
else
    filePath = [filePath fileName];
end
reader = bfGetReader();
reader = loci.formats.Memoizer(reader);
reader.setId(filePath);
%get number of sections
series = reader.getSeriesCount;
if sections(1) == 'A'
    sections = 1:series;
end
%get and sort the channels
omeMeta = reader.getMetadataStore;
t = max(4 * (reader.getSizeY > 2000), 2);

try
    frameRate = round((double(omeMeta.getPlaneDeltaT(0, omeMeta.getPlaneCount(0) - 1).value) - double(omeMeta.getPlaneDeltaT(0, 0).value)) / (reader.getSizeT - 1) / 60);
catch
    frameRate = round((double(omeMeta.getPlaneDeltaT(0, reader.getSizeT - 1).value) - double(omeMeta.getPlaneDeltaT(0, 0).value)) / (reader.getSizeT - 1) / 60);
end

channels = omeMeta.getChannelCount(0);
if channels > 2
    dic = str2num(cell2mat(inputdlg({'H2B', 'NLS'}, 'Accuracy Check', 1, {'0', '0'}))); %#ok<ST2NM>
    if any(dic == 0)
        saveFolder = [saveFolder ' (NLS)'];
        h2b = nan;
        nls = max(dic) - 1;
        for k = 0:(omeMeta.getPixelsSizeC(0).getValue - 1)
            if isempty(omeMeta.getChannelExcitationWavelength(0, k))
                dic = k;
                break
            end
        end
    else
        h2b = dic(1) - channels;
        nls = dic(2) - channels;
        for k = 0:(omeMeta.getPixelsSizeC(0).getValue - 1)
            if isempty(omeMeta.getChannelExcitationWavelength(0, k))
                dic = k + 1 - channels;
                break
            end
        end
        saveFolder = [saveFolder ' (NLS + H2B)'];
    end
    if length(unique([dic h2b nls])) < 3
        fprintf('\n')
        return
    end
else
    j = 0;
    for k = 0:(omeMeta.getPixelsSizeC(0).getValue - 1)
        i = omeMeta.getChannelExcitationWavelength(0, k);
        if isempty(i)
            dic = k;
        else
            nls = k;
        end
    end
    saveFolder = [saveFolder ' (NLS)'];
end
mkdir(saveFolder)

if channels > 2 && ~isnan(h2b)
    k = channels + dic;
else
    k = 1 + dic;
end

l = 10 / double(omeMeta.getPixelsPhysicalSizeY(0).value);
if length(sections) == 1
    fprintf('\nRotating image and locating constrictions...')
    reader.setSeries(sections - 1);
    clear im
    im(:, :, sections) = bfGetPlane(reader, k);
    s = sections;
    angle = zeros(sections, 1);
    loc = zeros(sections, 6);
    if constrictionSize(1) == 15
        rotate15
    elseif constrictionSize(1) > 0
        [bg, a, l2] = locateConstrictions(im(:, :, s), constrictionSize(1), cellsFromTop, l, t);
        checkRotation
    end
else
    fprintf('\nRotating images and locating constrictions...')
    %% get rotation angles and constriction heights
    angle = zeros(1, series);
    loc = zeros(series, 6);
    im = zeros(reader.getSizeY, reader.getSizeX, series, 'uint16');
    clear f
    for s = series:-1:1
        reader.setSeries(s - 1);
        im(:, :, s) = bfGetPlane(reader, k);
        f(s) = parfeval(@locateConstrictions, 3, im(:, :, s), constrictionSize(mod(s - sections(1), length(constrictionSize)) + 1) * ismember(s, sections), cellsFromTop, l, t);
    end

    %% ask user to manually rotate 15 micron sections
    for s = 1:series
        if ismember(s, sections) && constrictionSize(mod(s - sections(1), length(constrictionSize)) + 1) == 15
            rotate15
        end
    end

    %% ask user to check accuracy of auto-rotated sections
    for k = 1:series
        [s, bg, a, l2] = fetchNext(f);
        if ismember(s, sections) && constrictionSize(mod(s - sections(1), length(constrictionSize)) + 1) ~= 15 && constrictionSize(mod(s - sections(1), length(constrictionSize)) + 1) > 0
            checkRotation
        end
    end
end

%% analyze sections
tic
fprintf('\nAnalyzing images...')
h = waitbar(0, 'Initializing...', 'Name', ['Section ' num2str(sections(1))]);
h.CloseRequestFcn = '';
for s = sections
    c = constrictionSize(mod(s - sections(1), length(constrictionSize)) + 1);
    
    if c >= 0
        fprintf('\n\tSection %g...', s)   
        reader.setSeries(s - 1)

        fprintf('\n\t\tLocating and tracking cells...')
        if channels > 2 && ~isnan(h2b)
            findAndTrackCellsNLSH2BNew
        else
            findAndTrackCellsNLS
        end

        %this is so the files show up in chronological order. they normally
        %go in alphabetical order (1, 10, 11 ... 2, 3 ...)
        waitbar(1, h, 'Saving Video...');
        fprintf('\n\t\tSaving data...')
        if series == 1
            s = str2double(fileName((find(fileName == '(', 1, 'last') + 1):(find(fileName == ')', 1, 'last') - 1))); %#ok<FXSET>
			if isnan(s)
				s = 1;
			end
        end
        t = num2str(s);
        if s >= 10
            t = ['x' t]; %#ok<AGROW>
        end
        scaled = any([size(video4, 1) size(video4, 2)] > 1400);
        if scaled
            video5 = zeros(round(size(video4, 1) / 2), round(size(video4, 2) / 2), 3, size(video4, 4), 'uint8');
            for i = 1:size(video4, 4)
                video5(:, :, :, i) = imresize(video4(:, :, :, i), 0.5);
            end
        else
            video5 = video4;
        end
        if channels > 2 && ~isnan(h2b)
            save([saveFolder '\' t '.mat'], 'finishedCells', 'video5', 'v', 'v2', 'frameRate', 'c', 'loc', 'scaled')
        else
            save([saveFolder '\' t '.mat'], 'finishedCells', 'video5', 'v', 'frameRate', 'c', 'loc', 'scaled')
        end
    end
end
delete(h);
fprintf('\nFinished.\n')
toc