waitbar(0, h, 'Initializing...');
set(h, 'Name', ['Section ' num2str(s)]);
planes = reader.getImageCount;

%% prepare values for image stabilization
pixelMargin = round(25 / double(omeMeta.getPixelsPhysicalSizeY(0).value));
searchSizeFraction = 5;
lastImage = bfGetPlane(reader, 1 + dic);
xMin = size(lastImage, 2) * (1 - 1 / searchSizeFraction) / 2;
xMax = size(lastImage, 2) - xMin;
yMin = size(lastImage, 1) * (1 - 1 / searchSizeFraction) / 2;
yMax = size(lastImage, 1) - yMin;
minObjectSize = round(reader.getSizeX * reader.getSizeY / 1500); %this value was based off of a 2000 pixel size in a 1460x1940 image, is now smaller
l2 = reader.getSizeX;
offset = [0 0];

p = size(imrotate(lastImage, angle(s)));
v = zeros(p(1), p(2), planes / channels, 'uint16');
video4 = zeros(p(1), p(2), 3, planes / channels, 'uint8');
g = fspecial('gaussian', [10 10], 2);
activeCells = struct();
finishedCells = struct('Area', 0, 'Centroid', 0, 'BoundingBox', 0, 'MeanIntensity', 0, 'Visibility', 0, 'TimeAppearing', 0, 'Rupture', 0, 'Constriction', 0, 'Alive', 0, 'Parent', 0, 'Divided', false, 'CombinedCentroid', 0);

%%
for p = 1:channels:planes
    waitbar(p / planes, h, ['Working on frame ' num2str((p + channels - 1) / channels) '/' num2str(planes / channels) '...']);
    %% use background images for stabilization
    bg = im2uint16(bfGetPlane(reader, p + dic));
    %use gfp image to make sure this is a decent image
    im = im2uint16(bfGetPlane(reader, p + nls));
    pixels = bwconncomp(bwareaopen(imbinarize(im, 'adaptive'), 1000));
    if pixels.NumObjects > 0
        % Area that is being matched:
        searchArea = lastImage(yMin:yMax, xMin:xMax);
        % Area to be matched:
        imageArea = bg((yMin - pixelMargin):(yMax + pixelMargin), (xMin - pixelMargin):(xMax + pixelMargin)); 
        crossCorrelation = normxcorr2(searchArea, imageArea);
        [~, iMax] = max(abs(crossCorrelation(:)));
        [yPeak, xPeak] = ind2sub(size(crossCorrelation), iMax(1));
        offset = [(yPeak - size(imageArea,1) + pixelMargin) (xPeak - size(imageArea,2) + pixelMargin)];
        lastImage = ShiftImage(bg, -offset(2), -offset(1), 0);
    end
    
    %% find nuclei using the GFP channel
    imavg = double(median(reshape(im, 1, numel(im))));
    
    %filter out noise and convert to black and white 
    bw = imbinarize(imfilter(medfilt2(im), g, 'same'), 'adaptive', 'Sensitivity', 0.4);
    
    bw(1:end, [1:3 end-2:end]) = true;
    bw([1:3 end-2:end], 1:end) = true;

    bw = imrotate(ShiftImage(imclearborder(bwareaopen(~bwareaopen(~imopen(bw, strel('disk', 1)), round(minObjectSize / 10)), minObjectSize)), -offset(2), -offset(1), 0), angle(s));
    im = imrotate(ShiftImage(im, -offset(2), -offset(1), 0), angle(s));
    
    if isempty(fieldnames(activeCells))
        pixels = bwconncomp(bw);
    else
        pixelsX = bwconncomp(bw);

        %separate objects composed of multiple nuclei into individual objects
        D = -bwdist(~bw);
        L = watershed(imhmin(D, 5));
        if ~any(c == [0 15])
            L(round([loc(s, 6):loc(s, 5) loc(s, 4):loc(s, 3) loc(s, 2):loc(s, 1)]), :) = 1;
        end
        bw(L == 0) = 0;
        bw = bwareaopen(~bwareaopen(~bw, round(minObjectSize / 10)), minObjectSize);

        %save data for each cell
        pixels = bwconncomp(bw);

        %go through connected components from before/after segmentation
        %ignore small segments since they cause issues and aren't actually
        %different objects (they're usually short protrusion from the main cell
        %body)
        i = 1;
        j = 1;
        while i <= pixels.NumObjects && j <= pixelsX.NumObjects
            if ~ismember(pixels.PixelIdxList{i}(1), pixelsX.PixelIdxList{j})
                j = j + 1;
            else
                k = i;
                i = i + 1;
                while i <= pixels.NumObjects && ismember(pixels.PixelIdxList{i}(1), pixelsX.PixelIdxList{j})
                    i = i + 1;
                end
                maxSize = 0;
                for i = k:(i - 1)
                    maxSize = max(maxSize, length(pixels.PixelIdxList{i}));
                end
                for k = i:-1:k
                    if maxSize / length(pixels.PixelIdxList{k}) > 4
                        pixels.PixelIdxList(k) = [];
                        pixels.NumObjects = pixels.NumObjects - 1;
                        i = i - 1;
                    end
                end
            end
            i = i + 1;
            j = j + 1;
        end
    end
    
    cellData = regionprops(pixels, 'Area', 'Centroid', 'BoundingBox', 'Perimeter');
    
    %remove objects not shaped at all like nuclei or that are too dim
    for i = length(cellData):-1:1
        cellData(i).MeanIntensity = mean(im(pixels.PixelIdxList{i}));
        cellData(i).Visibility = cellData(i).MeanIntensity / imavg;
        if (4 * pi * cellData(i).Area / (cellData(i).Perimeter ^ 2)) < 0.17 || cellData(i).Area > 8 * minObjectSize || cellData(i).Visibility < 1.265
            cellData(i) = [];
            bw(pixels.PixelIdxList{i}) = false;
            pixels.PixelIdxList(i) = [];
            pixels.NumObjects = pixels.NumObjects - 1;
        end
    end
    cellData = rmfield(cellData, 'Perimeter');
    
    %cellData is now a structural array containing the size,
    %flourescent intensity, and location of each nucleus. locations
    %should be used to track cells over time and then the other data
    %should be used to determine rupture
    
    v(:, :, (p + channels - 1) / channels) = im;
    bg = imrotate(ShiftImage(bg, -offset(2), -offset(1), 0), angle(s));
    video4(:, :, :, (p + channels - 1) / channels) = im2uint8(cat(3, bg .* uint16(50000 ./ (max(bg(:)))), bg .* uint16(50000 ./ (max(bg(:)))) + imadjust(im) .* uint16(bw), bg .* uint16(50000 ./ (max(bg(:))))));
    
    %% cells have been located in current frame. assign them to cells from previous frame
    if isempty(fieldnames(activeCells))
        %if this is the first frame cells have been identified in
        if ~isempty(cellData)
            for i = 1:length(cellData)
                activeCells(i).Area((p + channels - 1) / channels) = cellData(i).Area;
                activeCells(i).Centroid((p + channels - 1) / channels, :) = cellData(i, :).Centroid;
                activeCells(i).BoundingBox((p + channels - 1) / channels, :) = cellData(i, :).BoundingBox;
                activeCells(i).MeanIntensity((p + channels - 1) / channels) = cellData(i).MeanIntensity;
                activeCells(i).Visibility((p + channels - 1) / channels) = cellData(i).Visibility;
            end
            [activeCells.TimeAppearing] = deal((p + channels - 1) / channels);
            [activeCells.Rupture] = deal(zeros(1, planes / channels));
            [activeCells.Constriction] = deal(zeros(1, planes / channels));
            [activeCells.Alive] = deal([zeros(1, (p - 1) / channels) 1 zeros(1, (planes - p + 1 - channels) / channels)]);
            [activeCells.Parent] = deal(0);
            [activeCells.Divided] = deal(false);
            activeCells(1).CombinedCentroid = [];

            checkConstrictionPassageNLS
        end
    else
        %% if there are no nuclei this frame, it may be because the image had
        %no fluorescence, in this case copy over the data for each cell
        %from the previous image
        if isempty(cellData)
            for i = 1:length(activeCells)
                activeCells(i).Area((p + channels - 1) / channels) = activeCells(i).Area((p - 1) / channels);
                activeCells(i).Centroid((p + channels - 1) / channels, :) = activeCells(i).Centroid((p - 1) / channels, :);
                activeCells(i).BoundingBox((p + channels - 1) / channels, :) = activeCells(i).BoundingBox((p - 1) / channels, :);
                activeCells(i).MeanIntensity((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p - 1) / channels);
                activeCells(i).Rupture((p + channels - 1) / channels) = activeCells(i).Rupture((p - 1) / channels);
                activeCells(i).Alive((p + channels - 1) / channels) = activeCells(i).Alive((p - 1) / channels);
                activeCells(i).Constriction((p + channels - 1) / channels) = activeCells(i).Constriction((p - 1) / channels);
                activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).Visibility((p - 1) / channels);
            end
            continue
        end

        %% caluclate error (in this case, distance squared, difference in
        %intensity, or difference in area) of each prediction to each cell in
        %the current frame
        error1 = zeros(length(activeCells), length(cellData));
        error2 = zeros(length(activeCells), length(cellData));
        error3 = zeros(length(activeCells), length(cellData));
        for i = 1:length(activeCells)
            for j = 1:length(cellData)
                error1(i, j) = sum((activeCells(i).Centroid((p - 1) / channels, :) - cellData(j).Centroid) .^ 2);
                error2(i, j) = abs(activeCells(i).MeanIntensity((p - 1) / channels) - cellData(j).MeanIntensity) .* 2;
                error3(i, j) = abs(activeCells(i).Area((p - 1) / channels) - cellData(j).Area) .* 2;
            end
        end

        %determine which active cells have been assigned a current cell. used
        %to tell which cells have died or divided
        unassignedCells = true(1, length(activeCells));

        m = min(min(error1));
        %% match cells based on lowest distance error. this is in case the area
        %or intensity errors were high due to rupture
        k3 = [activeCells.Rupture];
        k3 = any(k3((p - 1):(planes / channels):end));
        while ~isempty(m) && m ~= 0 && m < 0.0074 * l2 ^ 2 && (k3 || any(unassignedCells))
            [i, j] = find(error1 == m);

            %check for other cells within close proximity for area and mean
            %intensity
            i2 = find(error1(:, j) < m + 0.00265 * l2 ^ 2 & error1(:, j) < 0.0074 * l2 ^ 2);
            j2 = find(error1(i, :) < m + 0.00265 * l2 ^ 2 & error1(i, :) < 0.0074 * l2 ^ 2); 
            i3 = i2(error1(i2, j) + error2(i2, j) + error3(i2, j) == min(error1(i2, j) + error2(i2, j) + error3(i2, j)));
            j3 = j2(error1(i, j2) + error2(i, j2) + error3(i, j2) == min(error1(i, j2) + error2(i, j2) + error3(i, j2)));

            if i3 == i && j3 == j
                i2(i3 == i2) = [];
                j2(j3 == j2) = [];
                if ~isempty(i2) && ~isempty(j2)
                    i3 = i2(error1(i2, j) + error2(i2, j) + error3(i2, j) == min(error1(i2, j) + error2(i2, j) + error3(i2, j)));
                    j3 = j2(error1(i, j2) + error2(i, j2) + error3(i, j2) == min(error1(i, j2) + error2(i, j2) + error3(i, j2)));
                    if error1(i3, j) + error2(i3, j) + error3(i3, j) + error1(i, j3) + error2(i, j3) + error3(i, j3) < error1(i, j) + error2(i, j) + error3(i, j) + error1(i3, j3) + error2(i3, j3) + error3(i3, j3)
                        i = i3;
                    end
                end
            else
                if error1(i3, j) + error2(i3, j) + error3(i3, j) < error1(i, j3) + error2(i, j3) + error3(i, j3)
                    i = i3;
                else
                    j = j3;
                end
            end
            
            error1(i, j) = inf;
            if unassignedCells(i)
                if activeCells(i).BoundingBox((p - 1) / channels, 2) < sqrt(m) / 4 || activeCells(i).BoundingBox((p - 1) / channels, 2) + activeCells(i).BoundingBox((p - 1) / channels, 4) > size(bw, 1) - sqrt(m) / 4
                    %cell may have left image
                    activeCells(i).Alive((p + channels - 1) / channels) = 3;
                elseif  cellData(j).BoundingBox(2) < sqrt(m) / 4 || cellData(j).BoundingBox(2) + cellData(j).BoundingBox(4) > size(bw, 1) - sqrt(m) / 4
                    activeCells(end + 1).TimeAppearing = (p + channels - 1) / channels;
                    activeCells(end).Area((p + channels - 1) / channels) = cellData(j).Area;
                    activeCells(end).Centroid((p + channels - 1) / channels, :) = cellData(j).Centroid;
                    activeCells(end).BoundingBox((p + channels - 1) / channels, :) = cellData(j).BoundingBox;
                    activeCells(end).MeanIntensity((p + channels - 1) / channels) = cellData(j).MeanIntensity;
                    activeCells(end).Visibility((p + channels - 1) / channels) = cellData(j).Visibility;
                    activeCells(end).Rupture = zeros(1, planes / channels);
                    activeCells(end).Alive = [zeros(1, (p - 1) / channels) 1 zeros(1, (planes - p + 1 - channels) / channels)];
                    activeCells(end).CombinedCentroid = [];
                    activeCells(end).Parent = 0;
                    activeCells(end).Constriction = zeros(1, planes / channels);
                    activeCells(end).Divided = false;
                    cellData(j) = [];
                    error1(:, j) = [];
                    error2(:, j) = [];
                    error3(:, j) = [];
                else
%                     found = false;
%                     if (activeCells(i).Visibility((p - 1) / channels) < 1.75 && m > 1500) || m > 10000
%                         %cell may have disappeared due to dimness
%                         box = activeCells(i).BoundingBox((p - 1) / channels, :);
%                         imtemp = imfilter(medfilt2(im), g, 'same');
%                         imtemp = imtemp(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60));
%                         imtemp = imfill(bwareaopen(imclose(imclearborder(imopen(imbinarize(imtemp, 'adaptive', 'Sensitivity', 0.6), strel('disk', 1))), strel('disk', 1)), 1000), 'holes');
%                         t2 = false(size(im));
%                         t2(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)) = imtemp;
%                         pix = bwconncomp(t2);
%                         cx = regionprops(pix);
%                         for k = pix.NumObjects:-1:1
%                             for k2 = 1:pixels.NumObjects
%                                if ~isempty(intersect(pix.PixelIdxList{k}, pixels.PixelIdxList{k2})) || bboxOverlapRatio(cx(k).BoundingBox, activeCells(i).BoundingBox((p - 1) / channels, :), 'min') < 0.5
%                                   pix.PixelIdxList(k) = [];
%                                   pix.NumObjects = pix.NumObjects - 1;
%                                   cx(k) = [];
%                                   break
%                                end
%                             end
%                         end
%                         if pix.NumObjects > 0
%                             found = true;
%                             dist = zeros(1, length(cx));
%                             for j = 1:length(cx)
%                                dist(j) = sum((cx(j).Centroid - activeCells(i).Centroid((p - 1) / channels)) .^ 2); 
%                             end
%                             j = find(dist == min(dist));
%                             pixels.NumObjects = pixels.NumObjects + 1;
%                             pixels.PixelIdxList(end + 1) = pix.PixelIdxList(j);
%                             activeCells(i).Alive((p + channels - 1) / channels) = 1;
%                             activeCells(i).Area((p + channels - 1) / channels) = cx(j).Area;
%                             activeCells(i).Centroid((p + channels - 1) / channels, :) = cx(j).Centroid;
%                             activeCells(i).BoundingBox((p + channels - 1) / channels, :) = cx(j).BoundingBox;
%                             activeCells(i).MeanIntensity((p + channels - 1) / channels) = mean(im(pix.PixelIdxList{j}));
%                             activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p + channels - 1) / channels) / imavg;
%                         end
%                     end
%                     if ~found
                        %update active cell i with current cell j's data
                        activeCells(i).Area((p + channels - 1) / channels) = cellData(j).Area;
                        activeCells(i).Centroid((p + channels - 1) / channels, :) = cellData(j).Centroid;
                        activeCells(i).BoundingBox((p + channels - 1) / channels, :) = cellData(j).BoundingBox;
                        activeCells(i).MeanIntensity((p + channels - 1) / channels) = cellData(j).MeanIntensity;
                        activeCells(i).Visibility((p + channels - 1) / channels) = cellData(j).Visibility;
                        activeCells(i).Alive((p + channels - 1) / channels) = 1;
                        activeCells(i).CombinedCentroid = [];
                        cellData(j) = [];
                        error1(:, j) = [];
                        error2(:, j) = [];
                        error3(:, j) = [];
%                     end
                    unassignedCells(i) = false;
                end
            elseif activeCells(i).Rupture((p - 1) / channels) && m < 0.004 * l2 ^ 2
                %this cell is a new daughter cell
                activeCells(end + 1).TimeAppearing = (p + channels - 1) / channels;
                activeCells(end).Area((p + channels - 1) / channels) = cellData(j).Area;
                activeCells(end).Centroid((p + channels - 1) / channels, :) = cellData(j).Centroid;
                activeCells(end).BoundingBox((p + channels - 1) / channels, :) = cellData(j).BoundingBox;
                activeCells(end).MeanIntensity((p + channels - 1) / channels) = cellData(j).MeanIntensity;
                activeCells(end).Visibility((p + channels - 1) / channels) = cellData(j).Visibility;
                activeCells(end).Rupture = zeros(1, planes / channels);
                activeCells(end).Alive = [zeros(1, (p - 1) / channels) 1 zeros(1, (planes - p + 1 - channels) / channels)];
                activeCells(end).CombinedCentroid = [];
                activeCells(end).Parent = i + 0.5;
                activeCells(end).Constriction = zeros(1, planes / channels);
                activeCells(end).Divided = false;
                if activeCells(i).Alive((p + channels - 1) / channels) ~= 2
                    %other cell added to active cell i is a new daughter cell
                    activeCells(end + 1).TimeAppearing = (p + channels - 1) / channels;
                    activeCells(end).Area((p + channels - 1) / channels) = activeCells(i).Area((p + channels - 1) / channels);
                    activeCells(end).Centroid((p + channels - 1) / channels, :) = activeCells(i).Centroid((p + channels - 1) / channels, :);
                    activeCells(end).BoundingBox((p + channels - 1) / channels, :) = activeCells(i).BoundingBox((p + channels - 1) / channels, :);
                    activeCells(end).MeanIntensity((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p + channels - 1) / channels);
                    activeCells(end).Visibility((p + channels - 1) / channels) = activeCells(i).Visibility((p + channels - 1) / channels);
                    activeCells(end).Rupture = zeros(1, planes / channels);
                    activeCells(end).Alive = [zeros(1, (p - 1) / channels) 1 zeros(1, (planes - p + 1 - channels) / channels)];
                    activeCells(end).Parent = i + 0.5;
                    activeCells(end).CombinedCentroid = [];
                    activeCells(end).Constriction = zeros(1, planes / channels);
                    activeCells(end).Divided = false;
                    %active cell i is no longer around
                    activeCells(i).Alive((p + channels - 1) / channels) = 2;
                end
                cellData(j) = [];
                error1(:, j) = [];
                error2(:, j) = [];
                error3(:, j) = [];
            end
            m = min(min(error1));
        end

        %% check distance from unassigned active cells to current cells. it's
        %possible two active cells began touching and only one current cell was
        %registered for it
        dist = zeros(find(~unassignedCells, 1, 'last'), find(unassignedCells, 1, 'last'));
        for i = find(~unassignedCells)
            for j = find(unassignedCells)
                dist(i, j) = (activeCells(i).Centroid((p + channels - 1) / channels, 1) - activeCells(j).Centroid((p - 1) / channels, 1)) ^ 2 + (activeCells(i).Centroid((p + channels - 1) / channels, 2) - activeCells(j).Centroid((p - 1) / channels, 2)) ^ 2;
            end
        end
        for j = find(unassignedCells)
            i = dist(:, j);
            i = min(i(i > 0));
            if i < 0.0055 * l2 ^ 2
                %try to split touching cells into separate objects
                i = find(dist(:, j) == i);
                D = -bwdist(~bw);
                L = watershed(imhmin(D, 1));
                if c ~= 0
                    L(round([loc(s, 6):loc(s, 5) loc(s, 4):loc(s, 3) loc(s, 2):loc(s, 1)]), :) = 1;
                end
                temp = bw;
                temp(L == 0) = 0;
                box = activeCells(i).BoundingBox((p + channels - 1) / channels, :);
                pix = bwconncomp(bwareaopen(imclearborder(temp(round(max(1, box(2) - 1):min(size(bw, 1), box(2) + box(4) + 1)), round(max(1, box(1) - 1):min(size(bw, 2), box(1) + box(3) + 1)))), 1000));
                if pix.NumObjects == 2
                    cx = regionprops(pix);
                    activeCells(j).Alive((p + channels - 1) / channels) = 1;
                    if sqrt(sum((cx(1).Centroid + [box(1) box(2)] - activeCells(i).Centroid((p - 1) / channels, :)) .^ 2)) + sqrt(sum((cx(2).Centroid + [box(1) box(2)] - activeCells(j).Centroid((p - 1) / channels, :)) .^ 2)) > sqrt(sum((cx(1).Centroid + [box(1) box(2)] - activeCells(j).Centroid((p - 1) / channels, :)) .^ 2)) + sqrt(sum((cx(2).Centroid + [box(1) box(2)] - activeCells(i).Centroid((p - 1) / channels, :)) .^ 2))
                        temp = i;
                        i = j;
                        j = temp;
                    end
                    activeCells(i).Area((p + channels - 1) / channels) = cx(1).Area;
                    activeCells(j).Area((p + channels - 1) / channels) = cx(2).Area;
                    activeCells(i).Centroid((p + channels - 1) / channels, :) = cx(1).Centroid + [box(1) box(2)];
                    activeCells(j).Centroid((p + channels - 1) / channels, :) = cx(2).Centroid + [box(1) box(2)];
                    activeCells(i).BoundingBox((p + channels - 1) / channels, :) = cx(1).BoundingBox + [box(1) box(2) 0 0];
                    activeCells(j).BoundingBox((p + channels - 1) / channels, :) = cx(2).BoundingBox + [box(1) box(2) 0 0];
                    activeCells(i).MeanIntensity((p + channels - 1) / channels) = mean(im(pix.PixelIdxList{1}));
                    activeCells(j).MeanIntensity((p + channels - 1) / channels) = mean(im(pix.PixelIdxList{2}));
                    activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p + channels - 1) / channels) / imavg;
                    activeCells(j).Visibility((p + channels - 1) / channels) = activeCells(j).MeanIntensity((p + channels - 1) / channels) / imavg;
%                 elseif (~isempty(activeCells(j).CombinedCentroid) && 1.5 * activeCells(i).Area((p + channels - 1) / channels) > activeCells(i).Area((p - 1) / channels) + activeCells(j).Area((p - 1) / channels)) || 1.25 * activeCells(i).Area((p + channels - 1) / channels) > activeCells(j).Area((p - 1) / channels) + activeCells(i).Area((p - 1) / channels)
%                     displacement = activeCells(j).CombinedCentroid;
%                     box = activeCells(i).BoundingBox((p + channels - 1) / channels, :);
%                     if isempty(displacement)
%                         displacement = activeCells(i).Centroid((p + channels - 1) / channels, :) - (activeCells(i).Centroid((p - 1) / channels, :) + activeCells(j).Centroid((p - 1) / channels, :)) ./ 2;
%                         activeCells(j).BoundingBox((p + channels - 1) / channels, :) = activeCells(j).BoundingBox((p - 1) / channels, :) + [displacement 0 0];
%                         activeCells(i).BoundingBox((p + channels - 1) / channels, :) = activeCells(i).BoundingBox((p - 1) / channels, :) + [displacement 0 0];
%                     else
%                         displacement = activeCells(i).Centroid((p + channels - 1) / channels, :) - displacement;
%                         activeCells(j).BoundingBox((p + channels - 1) / channels, :) = activeCells(j).BoundingBox((p - 1) / channels, :) + [displacement 0 0];
%                         activeCells(i).BoundingBox((p + channels - 1) / channels, :) = activeCells(i).BoundingBox((p - 1) / channels, :) + [displacement 0 0];
%                     end
%                     activeCells(j).CombinedCentroid = activeCells(i).Centroid((p + channels - 1) / channels, :);
%                     activeCells(i).CombinedCentroid = activeCells(i).Centroid((p + channels - 1) / channels, :);
%                     activeCells(i).Centroid((p + channels - 1) / channels, :) = [(activeCells(i).BoundingBox((p + channels - 1) / channels, 1) + activeCells(i).BoundingBox((p + channels - 1) / channels, 3) / 2) (activeCells(i).BoundingBox((p + channels - 1) / channels, 2) + activeCells(i).BoundingBox((p + channels - 1) / channels, 4) / 2)];
%                     activeCells(j).Centroid((p + channels - 1) / channels, :) = [(activeCells(j).BoundingBox((p + channels - 1) / channels, 1) + activeCells(j).BoundingBox((p + channels - 1) / channels, 3) / 2) (activeCells(j).BoundingBox((p + channels - 1) / channels, 2) + activeCells(j).BoundingBox((p + channels - 1) / channels, 4) / 2)];
%                     activeCells(j).Area((p + channels - 1) / channels) = activeCells(j).Area((p - 1) / channels);
%                     activeCells(j).Visibility((p + channels - 1) / channels) = activeCells(j).Visibility((p - 1) / channels);
%                     activeCells(j).MeanIntensity((p + channels - 1) / channels) = activeCells(j).MeanIntensity((p - 1) / channels);
%                     activeCells(j).Alive((p + channels - 1) / channels) = 1;
%                     unassignedCells(j) = false;
%                     activeCells(i).Area((p + channels - 1) / channels) = activeCells(i).Area((p - 1) / channels);
%                     activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).Visibility((p - 1) / channels);
%                     activeCells(i).MeanIntensity((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p - 1) / channels);
%                     if activeCells(i).Centroid((p + channels - 1) / channels, 1) > activeCells(j).Centroid((p + channels - 1) / channels, 1)
%                         temp = i;
%                         i = j;
%                         j = temp;
%                     end
%                     activeCells(i).Centroid((p + channels - 1) / channels, 1) = activeCells(i).Centroid((p + channels - 1) / channels, 1) + box(1) - activeCells(i).BoundingBox((p + channels - 1) / channels, 1);
%                     activeCells(i).BoundingBox((p + channels - 1) / channels, 1) = box(1);
%                     activeCells(j).Centroid((p + channels - 1) / channels, 1) = activeCells(j).Centroid((p + channels - 1) / channels, 1) + box(1) + box(3) - activeCells(j).BoundingBox((p + channels - 1) / channels, 1) - activeCells(j).BoundingBox((p + channels - 1) / channels, 3);
%                     activeCells(j).BoundingBox((p + channels - 1) / channels, 1) = box(1) + box(3) - activeCells(j).BoundingBox((p + channels - 1) / channels, 3);
%                     if activeCells(i).Centroid((p + channels - 1) / channels, 2) > activeCells(j).Centroid((p + channels - 1) / channels, 2)
%                         temp = i;
%                         i = j;
%                         j = temp;
%                     end
%                     activeCells(i).Centroid((p + channels - 1) / channels, 2) = activeCells(i).Centroid((p + channels - 1) / channels, 2) + box(2) - activeCells(i).BoundingBox((p + channels - 1) / channels, 2);
%                     activeCells(i).BoundingBox((p + channels - 1) / channels, 2) = box(2);
%                     activeCells(j).Centroid((p + channels - 1) / channels, 2) = activeCells(j).Centroid((p + channels - 1) / channels, 2) + box(2) + box(4) - activeCells(j).BoundingBox((p + channels - 1) / channels, 2) - activeCells(j).BoundingBox((p + channels - 1) / channels, 4);
%                     activeCells(j).BoundingBox((p + channels - 1) / channels, 2) = box(2) + box(4) - activeCells(j).BoundingBox((p + channels - 1) / channels, 4);
                end
            end
        end

        %% current cells that are leftover must be new or a nucleus mistakenly split in two
        for i = 1:length(cellData)
            temp = true;
            for j = find(~unassignedCells)
                if activeCells(j).Area((p + channels - 1) / channels) + cellData(i).Area < activeCells(j).Area((p - 1) / channels) * 2 && sum((activeCells(j).Centroid((p + channels - 1) / channels, :) - cellData(i).Centroid) .^ 2) < 0.0055 * l2 ^ 2
                    imtemp = imclose(imclearborder(bw(round(max(1, min(activeCells(j).BoundingBox((p + channels - 1) / channels, 2), cellData(i).BoundingBox(2)) - 1):min(size(bw, 1), max(activeCells(j).BoundingBox((p + channels - 1) / channels, 2) + activeCells(j).BoundingBox((p + channels - 1) / channels, 4), cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4)) + 1)), round(max(1, min(activeCells(j).BoundingBox((p + channels - 1) / channels, 1), cellData(i).BoundingBox(1)) - 1):min(size(bw, 2), max(activeCells(j).BoundingBox((p + channels - 1) / channels, 1) + activeCells(j).BoundingBox((p + channels - 1) / channels, 3), cellData(i).BoundingBox(1) + cellData(i).BoundingBox(3)) + 1)))), strel('disk', 1));
                    D = -bwdist(~imtemp);
                    L = watershed(imhmin(D, 12));
                    imtemp(L == 0) = 0;
                    cx = bwconncomp(imtemp);
                    if cx.NumObjects == 1
                        temp = false;
                        activeCells(j).Centroid((p + channels - 1) / channels, :) = (activeCells(j).Area((p + channels - 1) / channels) .* activeCells(j).Centroid((p + channels - 1) / channels, :) + cellData(i).Area .* cellData(i).Centroid) ./ (activeCells(j).Area((p + channels - 1) / channels) + cellData(i).Area);
                        activeCells(j).MeanIntensity((p + channels - 1) / channels) = (activeCells(j).Area((p + channels - 1) / channels) * activeCells(j).MeanIntensity((p + channels - 1) / channels) + cellData(i).Area * cellData(i).MeanIntensity) / (activeCells(j).Area((p + channels - 1) / channels) + cellData(i).Area);
                        activeCells(j).Visibility((p + channels - 1) / channels) = activeCells(j).MeanIntensity((p + channels - 1) / channels) / imavg;
                        activeCells(j).Area((p + channels - 1) / channels) = activeCells(j).Area((p + channels - 1) / channels) + cellData(i).Area;
                        activeCells(j).BoundingBox((p + channels - 1) / channels, :) = [min(activeCells(j).BoundingBox((p + channels - 1) / channels, 1), cellData(i).BoundingBox(1)) min(activeCells(j).BoundingBox((p + channels - 1) / channels, 2), cellData(i).BoundingBox(2)) max(activeCells(j).BoundingBox((p + channels - 1) / channels, 1) + activeCells(j).BoundingBox((p + channels - 1) / channels, 3), cellData(i).BoundingBox(1) + cellData(i).BoundingBox(3))-min(activeCells(j).BoundingBox((p + channels - 1) / channels, 1), cellData(i).BoundingBox(1)) max(activeCells(j).BoundingBox((p + channels - 1) / channels, 2) + activeCells(j).BoundingBox((p + channels - 1) / channels, 4), cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4))-min(activeCells(j).BoundingBox((p + channels - 1) / channels, 2), cellData(i).BoundingBox(2))];
                    end
                end
            end
            if temp
                activeCells(end + 1).TimeAppearing = (p + channels - 1) / channels;
                activeCells(end).Area((p + channels - 1) / channels) = cellData(i).Area;
                activeCells(end).Centroid((p + channels - 1) / channels, :) = cellData(i).Centroid;
                activeCells(end).BoundingBox((p + channels - 1) / channels, :) = cellData(i).BoundingBox;
                activeCells(end).MeanIntensity((p + channels - 1) / channels) = cellData(i).MeanIntensity;
                activeCells(end).Visibility((p + channels - 1) / channels) = cellData(i).Visibility;
                activeCells(end).Rupture = zeros(1, planes / channels);
                activeCells(end).Constriction = zeros(1, planes / channels);
                activeCells(end).Alive = zeros(1, planes / channels);
                activeCells(end).Alive((p + channels - 1) / channels) = 1;
                activeCells(end).Parent = 0;
                activeCells(end).Divided = false;
            end
        end

        %% remove cells that are gone from the active list
        %but make sure to check that "disappeared" cells didn't just rupture and are too dim now
        for i = length(activeCells):-1:1
            if activeCells(i).Alive((p + channels - 1) / channels) == 0
                if all(activeCells(i).Alive(max(1, (p + channels - 1) / channels - 3):((p - 1) / channels)) == 0.5)
                    finishedCells(end + 1) = activeCells(i);
                    activeCells(i) = [];
                    for j = 1:length(activeCells)
                        if activeCells(j).Parent > i && activeCells(j).Parent ~= floor(activeCells(j).Parent)
                            activeCells(j).Parent = activeCells(j).Parent - 1;
                        end
                    end
                else
%                     %check for a cell that became dim
%                     box = activeCells(i).BoundingBox((p - 1) / channels, :);
%                     imtemp = imfilter(medfilt2(im), g, 'same');
%                     imtemp = imtemp(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60));
%                     imtemp = imfill(bwareaopen(imclose(imclearborder(imopen(imbinarize(imtemp, 'adaptive', 'Sensitivity', 0.6), strel('disk', 1))), strel('disk', 1)), 1000), 'holes');
%                     t2 = false(size(im));
%                     t2(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)) = imtemp;
%                     pix = bwconncomp(t2);
%                     cx = regionprops(pix);
%                     for k = pix.NumObjects:-1:1
%                         for j = 1:pixels.NumObjects
%                            if ~isempty(intersect(pix.PixelIdxList{k}, pixels.PixelIdxList{j})) || bboxOverlapRatio(cx(k).BoundingBox, activeCells(i).BoundingBox((p - 1) / channels, :), 'min') < 0.5
%                               pix.PixelIdxList(k) = [];
%                               pix.NumObjects = pix.NumObjects - 1;
%                               cx(k) = [];
%                               break
%                            end
%                         end
%                     end
%                     if pix.NumObjects == 0
                        activeCells(i).Alive((p + channels - 1) / channels) = 0.5;
                        activeCells(i).Area((p + channels - 1) / channels) = activeCells(i).Area((p - 1) / channels);
                        activeCells(i).Centroid((p + channels - 1) / channels, :) = activeCells(i).Centroid((p - 1) / channels, :);
                        activeCells(i).BoundingBox((p + channels - 1) / channels, :) = activeCells(i).BoundingBox((p - 1) / channels, :);
                        activeCells(i).MeanIntensity((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p - 1) / channels);
                        activeCells(i).Rupture((p + channels - 1) / channels) = activeCells(i).Rupture((p - 1) / channels);
                        activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).Visibility((p - 1) / channels);
%                     else
%                         dist = zeros(1, length(cx));
%                         for j = 1:length(cx)
%                            dist(j) = sum((cx(j).Centroid - activeCells(i).Centroid((p - 1) / channels)) .^ 2); 
%                         end
%                         j = find(dist == min(dist));
%                         pixels.NumObjects = pixels.NumObjects + 1;
%                         pixels.PixelIdxList(end + 1) = pix.PixelIdxList(j);
%                         activeCells(i).Alive((p + channels - 1) / channels) = 1;
%                         activeCells(i).Area((p + channels - 1) / channels) = cx(j).Area;
%                         activeCells(i).Centroid((p + channels - 1) / channels, :) = cx(j).Centroid;
%                         activeCells(i).BoundingBox((p + channels - 1) / channels, :) = cx(j).BoundingBox;
%                         activeCells(i).MeanIntensity((p + channels - 1) / channels) = mean(im(pix.PixelIdxList{j}));
%                         activeCells(i).Visibility((p + channels - 1) / channels) = activeCells(i).MeanIntensity((p + channels - 1) / channels) / imavg;
%                     end
                end
            end
        end

        %% remove cells that have divided or left the image from the active list
        for i = length(activeCells):-1:1
            if any(activeCells(i).Alive((p + channels - 1) / channels) == [2 3])
                if activeCells(i).Alive((p + channels - 1) / channels) == 2
                   activeCells(i).Divided = true; 
                end
                activeCells(i).Alive((p + channels - 1) / channels) = 0;
                finishedCells(end + 1) = activeCells(i);
                activeCells(i) = [];
                for j = 1:length(activeCells)
                   if activeCells(j).Parent == i + 0.5
                      activeCells(j).Parent = length(finishedCells);
                   elseif activeCells(j).Parent > i && activeCells(j).Parent ~= floor(activeCells(j).Parent)
                      activeCells(j).Parent = activeCells(j).Parent - 1;
                   end
                end
            end
        end

        checkConstrictionPassageNLS

        %% a nucleus halfway through a constriction is often mistaken as separate
        %objects so check for that
%         if c ~= 15
%             for i = length(activeCells):-1:1
%                 if any(activeCells(i).Constriction((p + channels - 1) / channels) == [1 2 3]) && activeCells(i).TimeAppearing == (p + channels - 1) / channels
%                     k = [];
%                     for j = 1:(i - 1)
%                         if activeCells(i).Constriction((p + channels - 1) / channels) == activeCells(j).Constriction((p + channels - 1) / channels)
%                             k = [k j];
%                         end
%                     end
%                     k2 = 100;
%                     for k3 = k
%                         k2 = min(k2, abs(activeCells(i).Centroid((p + channels - 1) / channels, 1) - activeCells(k3).Centroid((p + channels - 1) / channels, 1)));
%                     end
%                     if k2 < 100
%                         for k3 = k
%                            if abs(activeCells(i).Centroid((p + channels - 1) / channels, 1) - activeCells(k3).Centroid((p + channels - 1) / channels, 1)) == k2
%                                break
%                            end
%                         end
%                         if activeCells(k3).TimeAppearing == (p + channels - 1) / channels && activeCells(k3).Parent ~= 0
%                             temp = finishedCells(activeCells(k3).Parent);
%                             finishedCells(activeCells(k3).Parent) = [];
%                             for j = 1:length(activeCells)
%                                 if activeCells(j).Parent > activeCells(k3).Parent
%                                     activeCells(j).Parent = activeCells(j).Parent - 1;
%                                 end
%                             end
%                             activeCells(k3).Parent = temp.Parent;
%                             activeCells(k3).TimeAppearing = temp.TimeAppearing;
%                             activeCells(k3).Centroid(1:(p - 1) / channels, :) = temp.Centroid(1:(p - 1) / channels, :);
%                             activeCells(k3).BoundingBox(1:(p - 1) / channels, :) = temp.BoundingBox(1:(p - 1) / channels, :);
%                             activeCells(k3).Alive(1:(p - 1) / channels) = temp.Alive(1:(p - 1) / channels);
%                             activeCells(k3).MeanIntensity(1:(p - 1) / channels) = temp.MeanIntensity(1:(p - 1) / channels);
%                             activeCells(k3).Visibility(1:(p - 1) / channels) = temp.Visibility(1:(p - 1) / channels);
%                             activeCells(k3).Area(1:(p - 1) / channels) = temp.Area(1:(p - 1) / channels);
%                         end
%                         activeCells(k3).Centroid((p + channels - 1) / channels, :) = (activeCells(k3).Centroid((p + channels - 1) / channels, :) + activeCells(i).Centroid((p + channels - 1) / channels, :)) ./ 2;
%                         activeCells(k3).BoundingBox((p + channels - 1) / channels, :) = [min(activeCells(k3).BoundingBox((p + channels - 1) / channels, 1), activeCells(i).BoundingBox((p + channels - 1) / channels, 1)) min(activeCells(k3).BoundingBox((p + channels - 1) / channels, 2), activeCells(i).BoundingBox((p + channels - 1) / channels, 2)) max(activeCells(k3).BoundingBox((p + channels - 1) / channels, 1) + activeCells(k3).BoundingBox((p + channels - 1) / channels, 3), activeCells(i).BoundingBox((p + channels - 1) / channels, 1) + activeCells(i).BoundingBox((p + channels - 1) / channels, 3))-min(activeCells(k3).BoundingBox((p + channels - 1) / channels, 1), activeCells(i).BoundingBox((p + channels - 1) / channels, 1)) max(activeCells(k3).BoundingBox((p + channels - 1) / channels, 2) + activeCells(k3).BoundingBox((p + channels - 1) / channels, 4), activeCells(i).BoundingBox((p + channels - 1) / channels, 2) + activeCells(i).BoundingBox((p + channels - 1) / channels, 4))-min(activeCells(k3).BoundingBox((p + channels - 1) / channels, 2), activeCells(i).BoundingBox((p + channels - 1) / channels, 2))];
%                         activeCells(k3).MeanIntensity((p + channels - 1) / channels) = (activeCells(k3).MeanIntensity((p + channels - 1) / channels) * activeCells(k3).Area((p + channels - 1) / channels) + activeCells(i).MeanIntensity((p + channels - 1) / channels) * activeCells(i).Area((p + channels - 1) / channels)) / (activeCells(k3).Area((p + channels - 1) / channels) + activeCells(i).Area((p + channels - 1) / channels));
%                         activeCells(k3).Visibility((p + channels - 1) / channels) = (activeCells(k3).Visibility((p + channels - 1) / channels) * activeCells(k3).Area((p + channels - 1) / channels) + activeCells(i).Visibility((p + channels - 1) / channels) * activeCells(i).Area((p + channels - 1) / channels)) / (activeCells(k3).Area((p + channels - 1) / channels) + activeCells(i).Area((p + channels - 1) / channels));
%                         activeCells(k3).Area((p + channels - 1) / channels) = activeCells(k3).Area((p + channels - 1) / channels) + activeCells(i).Area((p + channels - 1) / channels);
%                         activeCells(k3).Alive((p + channels - 1) / channels) = 1;
%                         activeCells(i) = [];
%                     end
%                 end
%             end
%         end
    end
end

waitbar(1, h, 'Making Video...');
if ~isempty(fieldnames(activeCells))
    for i = find([activeCells.Parent] ~= floor([activeCells.Parent]))
        activeCells(i).Parent = activeCells(i).Parent - 0.5 + length(finishedCells);
    end
    finishedCells = [finishedCells activeCells];
end

%% remove cells only around for a couple frames and remove the couple frames 
%after a cell leaves that a track stays around in case the cell returns.
%also remove cells that are dim
for i = length(finishedCells):-1:1
   if sum(finishedCells(i).Alive == 1) < 3 && ~finishedCells(i).Alive(end)
       finishedCells(i) = [];
       for j = 1:length(finishedCells)
          if finishedCells(j).Parent ~= 0 && finishedCells(j).Parent >= i
              finishedCells(j).Parent = finishedCells(j).Parent - 1;
          end
       end
   else
       if ~finishedCells(i).Divided
            finishedCells(i).Alive((find(finishedCells(i).Alive == 1, 1, 'last') + 1):end) = 0;
       end
   end
end

%% edit constriction passage to remove frames when a nucleus changes constriction without going below the line
centers = imfindcircles(bwareaopen(edge(imrotate(bfGetPlane(reader, 1 + dic), angle(s)), 'zerocross'), 10), round([1.135 1.816] .* l), 'Sensitivity', 0.9);
if ~isempty(centers)
    centers = (centers(1, 1) - 45 * l):(3 * l):(centers(1, 1) + 45 * l);
    for i = 1:length(finishedCells)
        p = find(finishedCells(i).Alive, 1);
        if finishedCells(i).Constriction(p) == floor(finishedCells(i).Constriction(p))
            j = p;
            k = find(finishedCells(i).Centroid(p, 1) >= centers, 1, 'last');
        else
            j = 0;
        end
        for p = find(finishedCells(i).Alive, 2):find(finishedCells(i).Alive, 1, 'last')
            if j == 0
                if finishedCells(i).Constriction(p) == floor(finishedCells(i).Constriction(p))
                    j = p;
                    k = find(finishedCells(i).Centroid(p, 1) >= centers, 1, 'last');
                end
            else
                if finishedCells(i).Constriction(p) == finishedCells(i).Constriction(j)
                    if c ~= 0 && (finishedCells(i).Centroid(p, 2) > loc(s, 2 * finishedCells(i).Constriction(p) - 1) && finishedCells(i).BoundingBox(p, 2) > loc(s, 2 * finishedCells(i).Constriction(p)) && (finishedCells(i).Centroid(p, 1) < centers(k) || finishedCells(i).Centroid(p, 1) > centers(k + 1)))
                        if j ~= 1
                            finishedCells(i).Constriction(j:(p - 1)) = deal(finishedCells(i).Constriction(j - 1));
                        elseif finishedCells(i).BoundingBox(p, 2) + finishedCells(i).BoundingBox(p, 4) > loc(s, 2 * finishedCells(i).Constriction(p) - 1)
                            finishedCells(i).Constriction(j) = finishedCells(i).Constriction(p) - 0.8;
                        else
                            finishedCells(i).Constriction(j) = finishedCells(i).Constriction(p) + 0.2;
                        end
                        j = p;
                        k = find(finishedCells(i).Centroid(p, 1) >= centers, 1, 'last');
                    end
                else
                    j = 0;
                end
            end
        end
    end
end

%% make a pretty video to check for accuracy of cell finding
group = ones(1, length(finishedCells));
for i = 1:length(finishedCells)
%     j = find(finishedCells(i).Rupture, 1);
%     if ~isempty(j) && (any(~finishedCells(i).Rupture(j:find(finishedCells(i).Alive, 1, 'last'))) || find(finishedCells(i).Alive, 1, 'last') < timePoints)
%         group(i) = 2;
%     end
    j = 0;
    p = find(finishedCells(i).Alive);
    for p = p(2:end)
        if j == 0 && finishedCells(i).Constriction(p) == floor(finishedCells(i).Constriction(p)) && finishedCells(i).Constriction(p) > finishedCells(i).Constriction(p - 1)
            j = 1;
        elseif j == 1 && finishedCells(i).Constriction(p) > finishedCells(i).Constriction(p - 1)
            group(i) = 3;
            break
        elseif j == 1 && finishedCells(i).Constriction(p) < finishedCells(i).Constriction(p - 1)
            group(i) = 2;
            j = 0;
        end
    end
end

fprintf('\n\t\tCompiling video for accuracy checking...')
i = size(bw);
%      gray         blue     cyan
col = [128 128 128; 0 0 255; 0 255 255];
a = [finishedCells.Alive]; 
r = [finishedCells.Rupture];
cx = [finishedCells.Constriction];
if any(i > 1400)
    k2 = 5;
    k3 = 24;
else
    k2 = 3;
    k3 = 12;
end
for p = 1:(planes / channels)
    im = video4(:, :, :, p);
    z = a(p:(planes / channels):end);
    r2 = r(p:(planes / channels):end);
    c2 = cx(p:(planes / channels):end);
    l2 = [];
    for j = find(z & r2 & c2 == floor(c2) & c ~= 0)
       l2 = [l2; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(l2)
        im = insertText(im, l2, 'CR', 'FontSize', 24, 'BoxColor', 'white');
    end
    l2 = [];
    for j = find(z & r2 & c2 ~= floor(c2))
       l2 = [l2; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(l2)
        im = insertText(im, l2, 'R', 'FontSize', k3, 'BoxColor', 'white');
    end
    l2 = [];
    for j = find(z & ~r2 & c2 == floor(c2) & c2 ~= 0)
       l2 = [l2; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(l2)
        im = insertText(im, l2, 'C', 'FontSize', k3, 'BoxColor', 'magenta');
    end
    colors = zeros(sum(z > 0), 3);
    lines = cell(1, 4);
    circles = zeros(sum(z > 0), 3);
    rectangles = zeros(sum(z > 0), 4);
    z = find(z);
    for j = 1:length(z)
        colors(j, :) = col(group(z(j)), :);
        circles(j, :) = [finishedCells(z(j)).Centroid(p, :) k2];
        rectangles(j, :) = finishedCells(z(j)).BoundingBox(p, :);
        lines{group(z(j))} = [lines{group(z(j))}; finishedCells(z(j)).Centroid(max(find(finishedCells(z(j)).Alive, 1), p - 10):(p - 1), :) finishedCells(z(j)).Centroid(max(find(finishedCells(z(j)).Alive, 1) + 1, p - 9):p, :)];
    end
    for j = 1:3
        im = insertShape(im, 'Line', lines{j}, 'LineWidth', k2, 'Color', col(j, :)); 
    end
    im = insertShape(im, 'Rectangle', rectangles, 'LineWidth', k2, 'Color', colors);
    im = insertShape(im, 'FilledCircle', circles, 'Color', colors);
    if c ~= 0
        im = insertShape(im, 'Line', [[1; 1; 1; 1; 1; 1] loc(s, :)' [i(2); i(2); i(2); i(2); i(2); i(2)] loc(s, :)'], 'LineWidth', 3, 'Color', 'white');
    end
    video4(:, :, :, p) = im;
end