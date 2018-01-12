waitbar(0, h, 'Initializing...');
set(h, 'Name', ['Section ' num2str(s)]);
if isAVI
    lastImage = im2uint16(im);
    pixelMargin = 60;
    l2 = size(im, 1);
    minObjectSize = round(size(im, 1) * size(im, 2) / 2050); %this value was based off of a 2000 pixel size in a 1460x1940 image, is now smaller
else    
    timePoints = reader.getSizeT;
    lastImage = im2uint16(bfGetPlane(reader, channels + dic));
    pixelMargin = round(25 / double(omeMeta.getPixelsPhysicalSizeY(0).value));
    l2 = reader.getSizeX;
    minObjectSize = round(reader.getSizeX * reader.getSizeY / 2050); %this value was based off of a 2000 pixel size in a 1460x1940 image, is now smaller
end

%% prepare values for image stabilization
searchSizeFraction = 5;
stdev = std(double(lastImage(:)));
xMin = size(lastImage, 2) * (1 - 1 / searchSizeFraction) / 2;
xMax = size(lastImage, 2) - xMin;
yMin = size(lastImage, 1) * (1 - 1 / searchSizeFraction) / 2;
yMax = size(lastImage, 1) - yMin;
offset = [0 0];

imavg = zeros(1, timePoints);
imavgG = zeros(1, timePoints);
p = size(imrotate(lastImage, angle(s)));
video4 = zeros(p(1), p(2), 3, timePoints, 'uint8');
v = zeros(p(1), p(2), timePoints, 'uint16');
v2 = zeros(p(1), p(2), timePoints, 'uint16');
g = fspecial('gaussian', [10 10], 2);
activeCells = struct();
finishedCells = struct('Area', 0, 'Centroid', 0, 'BoundingBox', 0, 'RedIntensity', 0, 'GreenIntensity', 0, 'Perimeter', 0, 'Ratio', 0, 'TimeAppearing', 0, 'Rupture', 0, 'Constriction', 0, 'Alive', 0, 'Parent', 0, 'Divided', false, 'CombinedCentroid', 0);

%%
for p = 1:timePoints
    waitbar(p / timePoints, h, ['Working on frame ' num2str(p) '/' num2str(timePoints) '...']);
    if isAVI
        if p > 1
            im3 = readFrame(vidReader);
        end
        bg = im2uint16(im3(:, :, 3));
        im = im2uint16(im3(:, :, 1));
        grn = im2uint16(im3(:, :, 2));
    else
       %% use background images for stabilization
        bg = im2uint16(bfGetPlane(reader, channels * p + dic));
        %use h2b image to make sure this is a decent image
        im = im2uint16(bfGetPlane(reader, channels * p + h2b));
        grn = im2uint16(bfGetPlane(reader, channels * p + nls));
    end
    pixels = bwconncomp(bwareaopen(imbinarize(im, 'adaptive'), 1000, 4), 4);
    if pixels.NumObjects > 0 && c > 0 && std(double(bg(:))) < 3 * stdev
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
    
    %% find nuclei using the RFP channel
    imavg(p) = double(median(im(:)));
   
    imavgG(p) = double(median(grn(:)));
    
    %filter out noise and convert to black and white 
    bwR = ~bwareaopen(~bwareaopen(imopen(imbinarize(imfilter(medfilt2(im), g, 'same'), 'adaptive', 'Sensitivity', 0.5), strel('disk', 1)), round(minObjectSize / 2), 4), round(minObjectSize / 4), 4);
    bwG = ~bwareaopen(~bwareaopen(imopen(imbinarize(imfilter(medfilt2(grn), g, 'same'), 'adaptive', 'Sensitivity', 0.5), strel('disk', 1)), round(minObjectSize / 2), 4), round(minObjectSize / 4), 4);
    
%     bwR(1:end, [1:3 end-2:end]) = true;
%     bwR([1:3 end-2:end], 1:end) = true;
%     bwG(1:end, [1:3 end-2:end]) = true;
%     bwG([1:3 end-2:end], 1:end) = true;

    bwR = imrotate(ShiftImage(imclearborder(~bwareaopen(~imclose(bwR, strel('disk', 5)), round(minObjectSize / 4))), -offset(2), -offset(1), 0), angle(s));
    bwG = imrotate(ShiftImage(imclearborder(bwG), -offset(2), -offset(1), 0), angle(s));
    im = imrotate(ShiftImage(im, -offset(2), -offset(1), 0), angle(s));
    grn = imrotate(ShiftImage(grn, -offset(2), -offset(1), 0), angle(s));
    
    %separate objects composed of multiple nuclei into individual objects
%     wshed = watershed(imhmin(65535 - im .* uint16(bwR), 2000));
%     bwR(wshed == 0) = 0;
    
    dist = -bwdist(~bwR);
    wshed = watershed(imhmin(dist, 5 + (2 * (p == 1))));
    if ~any(c == [0 15])
        wshed(round([loc(s, 6):loc(s, 5) loc(s, 4):loc(s, 3) loc(s, 2):loc(s, 1)]), :) = 1;
    end
    bwR(wshed == 0) = 0;
    bwR = bwareaopen(~bwareaopen(~bwR, round(minObjectSize / 8), 4), minObjectSize, 4);
    
%     dist = -bwdist(~bwG);
%     wshed = watershed(imhmin(dist, 5));
%     if ~any(c == [0 15])
%         wshed(round([loc(s, 6):loc(s, 5) loc(s, 4):loc(s, 3) loc(s, 2):loc(s, 1)]), :) = 1;
%     end
%     bwG(wshed == 0) = 0;
%     bwG = bwareaopen(~bwareaopen(~bwG, 250, 4), 2000, 4);
    
    pixels = bwconncomp(bwR, 4);
    cellData = regionprops(pixels, 'Area', 'BoundingBox', 'Centroid', 'Perimeter');
    pixelsG = bwconncomp(bwG, 4);
    cellDataG = regionprops(pixelsG);
    
    %remove objects not shaped at all like nuclei or that are too dim
    for i = pixels.NumObjects:-1:1
        if mean(im(pixels.PixelIdxList{i})) < 2 * imavg(p) || cellData(i).Area > 8 * minObjectSize || (4 * pi * cellData(i).Area / (cellData(i).Perimeter ^ 2)) < 0.3 || ((4 * pi * cellData(i).Area / (cellData(i).Perimeter ^ 2)) < 0.4 && (cellData(i).BoundingBox(2) > loc(s, 1) || (cellData(i).BoundingBox(2) > loc(s, 3) && cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4) < loc(s, 2)) || (cellData(i).BoundingBox(2) > loc(s, 5) && cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4) < loc(s, 4)) || cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4) < loc(s, 6))) || sum(bwG(pixels.PixelIdxList{i})) / cellData(i).Area < 0.7
            bwR(pixels.PixelIdxList{i}) = false;
            pixels.NumObjects = pixels.NumObjects - 1;
            pixels.PixelIdxList(i) = [];
            cellData(i) = [];
        else
            cellData(i).RedIntensity = mean(im(pixels.PixelIdxList{i}));
            cellData(i).GreenIntensity = mean(grn(pixels.PixelIdxList{i}));
        end
    end
    
    centr = [cellData.Centroid];
    
%     for i = 1:length(cellData)
%         pair = [1 bboxOverlapRatio(cellData(i).BoundingBox, cellDataG(1).BoundingBox, 'min')];
%         for j = 2:length(cellDataG)
%             if bboxOverlapRatio(cellData(i).BoundingBox, cellDataG(j).BoundingBox, 'min') > pair(2)
%                 pair = [j bboxOverlapRatio(cellData(i).BoundingBox, cellDataG(j).BoundingBox, 'min')];
%             end
%         end
%         for j = 1:length(cellData)
%             if j ~= i && bboxOverlapRatio(cellData(j).BoundingBox, cellDataG(pair(1)).BoundingBox, 'min') > pair(2) / 2
%                 pair = 0;
%                 break
%             end
%         end
%         if pair == 0
%             cellData(i).GreenArea = nan;
%         else
%             cellData(i).GreenArea = cellDataG(pair(1)).Area;
%         end
%     end
    
    %cellData is now a structural array containing the size,
    %flourescent intensity, and location of each nucleus. locations
    %should be used to track cells over time and then the other data
    %should be used to determine rupture

    v(:, :, p) = im;
    v2(:, :, p) = grn;
%     video4(:, :, :, p) = im2uint8(cat(3, imadjust(grn) .* uint16(~bwR & ~bwG) + imadjust(im) .* uint16(bwR), imadjust(grn) .* uint16(~bwR & ~bwG) + imadjust(grn) .* uint16(bwG & ~bwR), imadjust(grn) .* uint16(~bwR & ~bwG)));     
    bg = imrotate(lastImage, angle(s));
%     video4(:, :, :, p) = im2uint8(cat(3, bg .* uint16(50000 ./ (max(bg(:)))) .* uint16(~bwR) + imadjust(im) .* uint16(bwR), (bg .* uint16(50000 ./ (max(bg(:)))) + grn .* uint16(250000 ./ (max(grn(:))))) .* uint16(~bwR), bg .* uint16(50000 ./ (max(bg(:)))) .* uint16(~bwR)));
%     video4(:, :, :, p) = im2uint8(cat(3, bg .* uint16(50000 ./ (max(bg(:)))) + imadjust(im) .* uint16(bwR), bg .* uint16(50000 ./ (max(bg(:)))) + grn .* uint16(250000 ./ (max(grn(:)))), bg .* uint16(50000 ./ (max(bg(:))))));
    video4(:, :, :, p) = im2uint8(cat(3, bg .* uint16(50000 ./ (max(bg(:)))) + im2uint16(bwR), bg .* uint16(50000 ./ (max(bg(:)))) + grn .* uint16(250000 ./ (max(grn(:)))), bg .* uint16(50000 ./ (max(bg(:))))));
        

    %% cells have been located in current frame. assign them to cells from previous frame
    if isempty(fieldnames(activeCells))
        %if this is the first frame cells have been identified in
        if ~isempty(cellData)
            for i = 1:length(cellData)
                activeCells(i).Area(p) = cellData(i).Area;
%                 activeCells(i).GreenArea(p) = cellData(i).GreenArea;
                activeCells(i).Centroid(p, :) = cellData(i, :).Centroid;
                activeCells(i).BoundingBox(p, :) = cellData(i, :).BoundingBox;
                activeCells(i).RedIntensity(p) = cellData(i).RedIntensity;
                activeCells(i).GreenIntensity(p) = cellData(i).GreenIntensity;
                activeCells(i).Perimeter(p) = cellData(i).Perimeter;
                activeCells(i).Ratio(p) = activeCells(i).RedIntensity(p) / activeCells(i).GreenIntensity(p);
            end
            [activeCells.TimeAppearing] = deal(p);
            [activeCells.Rupture] = deal(zeros(1, timePoints));
            [activeCells.Constriction] = deal(zeros(1, timePoints));
            [activeCells.Alive] = deal([zeros(1, p - 1) 1 zeros(1, timePoints - p)]);
            [activeCells.Parent] = deal(0);
            [activeCells.Divided] = deal(false);
            activeCells(1).CombinedCentroid = [];

            checkForRupture
            checkConstrictionPassageNLSH2B
        end
    else
        %% if there are no nuclei this frame, it may be because the image had
        %no fluorescence, in this case copy over the data for each cell
        %from the previous image
        if isempty(cellData)
            for i = 1:length(activeCells)
                activeCells(i).Area(p) = activeCells(i).Area(p - 1);
%                 activeCells(i).GreenArea(p) = activeCells(i).GreenArea(p - 1);
                activeCells(i).Centroid(p, :) = activeCells(i).Centroid(p - 1, :);
                activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :);
                activeCells(i).RedIntensity(p) = activeCells(i).RedIntensity(p - 1);
                activeCells(i).GreenIntensity(p) = activeCells(i).GreenIntensity(p - 1);
                activeCells(i).Rupture(p) = activeCells(i).Rupture(p - 1);
                activeCells(i).Alive(p) = activeCells(i).Alive(p - 1);
                activeCells(i).Constriction(p) = activeCells(i).Constriction(p - 1);
                activeCells(i).Ratio(p) = activeCells(i).Ratio(p - 1);
                activeCells(i).Perimeter(p) = activeCells(i).Perimeter(p - 1);
            end
        else
            %% caluclate error (in this case, distance squared, difference in
            %intensity, or difference in area) of each prediction to each cell in
            %the current frame
            error1 = zeros(length(activeCells), length(cellData));
            error2 = zeros(length(activeCells), length(cellData));
            error3 = zeros(length(activeCells), length(cellData));
            for i = 1:length(activeCells)
                for j = 1:length(cellData)
                    error1(i, j) = sum((activeCells(i).Centroid(p - 1, :) - cellData(j).Centroid) .^ 2);
                    error2(i, j) = abs(activeCells(i).RedIntensity(p - 1) - cellData(j).RedIntensity) .* 2;
                    error3(i, j) = abs(activeCells(i).Area(p - 1) - cellData(j).Area) .* 2;
                end
            end

            %determine which active cells have been assigned a current cell. used
            %to tell which cells have died or divided
            unassignedCells = true(1, length(activeCells));

            m = min(error1(:));
            k3 = [activeCells.Rupture];
            k3 = any(k3((p - 1):timePoints:end) > 0);
            %% match cells based on lowest distance error. this is in case the area
            %or intensity errors were high due to rupture
            while ~isempty(m) && m ~= 0 && m < 0.0074 * l2 ^ 2 && (k3 || any(unassignedCells))
                [i, j] = find(error1 == m);

                %check for other cells within close proximity for area and mean
                %intensity
                i2 = find(error1(:, j) < 0.0074 * l2 ^ 2);
                j2 = find(error1(i, :) < 0.0074 * l2 ^ 2); 
                i3 = i2(error1(i2, j) + error2(i2, j) + error3(i2, j) == min(error1(i2, j) + error2(i2, j) + error3(i2, j)));
                j3 = j2(error1(i3, j2) + error2(i3, j2) + error3(i3, j2) == min(error1(i3, j2) + error2(i3, j2) + error3(i3, j2)));

                if i3 == i && j3 == j
                    i2(i3 == i2) = [];
                    j2(j3 == j2) = [];
                    if ~isempty(i2) && ~isempty(j2)
                        i3 = i2(error1(i2, j) + error2(i2, j) + error3(i2, j) == min(error1(i2, j) + error2(i2, j) + error3(i2, j)));
                        j3 = j2(error1(i3, j2) + error2(i3, j2) + error3(i3, j2) == min(error1(i3, j2) + error2(i3, j2) + error3(i3, j2)));
                        if activeCells(i).Alive(p - 1) == 1 && activeCells(i3).Alive(p - 1) == 1 && error1(i3, j) + error2(i3, j) + error3(i3, j) == min(error1(i3, j2) + error2(i3, j2) + error3(i3, j2)) && error1(i3, j) + error2(i3, j) + error3(i3, j) + error1(i, j3) + error2(i, j3) + error3(i, j3) < error1(i, j) + error2(i, j) + error3(i, j) + error1(i3, j3) + error2(i3, j3) + error3(i3, j3)
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
                    if activeCells(i).BoundingBox(p - 1, 2) < sqrt(m) / 4 || activeCells(i).BoundingBox(p - 1, 2) + activeCells(i).BoundingBox(p - 1, 4) > size(bwR, 1) - sqrt(m) / 4 || (any(activeCells(i).Constriction(p - 1) == [0.2 3.2]) && (activeCells(i).BoundingBox(p - 1, 1) < sqrt(m) / 4 || activeCells(i).BoundingBox(p - 1, 1) + activeCells(i).BoundingBox(p - 1, 3) > size(bwR, 2) - sqrt(m) / 4))
                        %cell may have left image
                        activeCells(i).Alive(p) = 3;
                    elseif cellData(j).BoundingBox(2) < sqrt(m) / 2 || cellData(j).BoundingBox(2) + cellData(j).BoundingBox(4) > size(bwR, 1) - sqrt(m) / 2 || (any(activeCells(i).Constriction(p - 1) == [0.2 3.2]) && (cellData(j).BoundingBox(1) < sqrt(m) / 2 || cellData(j).BoundingBox(1) + cellData(j).BoundingBox(3) > size(bwR, 2) - sqrt(m) / 2))
                        activeCells(end + 1).TimeAppearing = p; %#ok<*SAGROW>
                        activeCells(end).Area(p) = cellData(j).Area;
%                         activeCells(end).GreenArea(p) = cellData(j).GreenArea;
                        activeCells(end).Centroid(p, :) = cellData(j).Centroid;
                        activeCells(end).BoundingBox(p, :) = cellData(j).BoundingBox;
                        activeCells(end).RedIntensity(p) = cellData(j).RedIntensity;
                        activeCells(end).GreenIntensity(p) = cellData(j).GreenIntensity;
                        activeCells(end).Perimeter(p) = cellData(j).Perimeter;
                        activeCells(end).Rupture = zeros(1, timePoints);
                        activeCells(end).Alive = [zeros(1, p - 1) 1 zeros(1, timePoints - p)];
                        activeCells(end).CombinedCentroid = [];
                        activeCells(end).Parent = 0;
                        activeCells(end).Constriction = zeros(1, timePoints);
                        activeCells(end).Divided = false;
                        cellData(j) = [];
                        error1(:, j) = [];
                        error2(:, j) = [];
                        error3(:, j) = [];
                    else
                        found = false;
                        if bboxOverlapRatio(activeCells(i).BoundingBox(p - 1, :), cellData(j).BoundingBox, 'min') == 0 || (activeCells(i).RedIntensity(p - 1) < 1.75 && m > 1500) || m > 10000
                            %cell may have disappeared due to dimness
                            box = activeCells(i).BoundingBox(p - 1, :);
                            imtemp = imfilter(medfilt2(im), g, 'same');
                            imtemp = imfill(bwareaopen(imclose(imclearborder(imopen(imbinarize(imtemp(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)), 'adaptive', 'Sensitivity', 0.6), strel('disk', 1))), strel('disk', 1)), 1000, 4), 'holes');
                            t2 = false(size(im));
                            t2(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)) = imtemp;
                            pix = bwconncomp(t2, 4);
                            cx = regionprops(pix);
                            for k = pix.NumObjects:-1:1
                                if cx(k).Area < 1500 || bboxOverlapRatio(cx(k).BoundingBox, box, 'min') < 0.5 || sum(bwG(pix.PixelIdxList{k})) / cx(k).Area < 0.1
                                  pix.PixelIdxList(k) = [];
                                  pix.NumObjects = pix.NumObjects - 1;
                                  cx(k) = [];
                                else
                                    for k2 = 1:pixels.NumObjects
                                       if ~isempty(intersect(pix.PixelIdxList{k}, pixels.PixelIdxList{k2}))
                                          pix.PixelIdxList(k) = [];
                                          pix.NumObjects = pix.NumObjects - 1;
                                          cx(k) = [];
                                          break
                                       end
                                    end
                                end
                            end
                            if pix.NumObjects > 0
                                dist = zeros(1, length(cx));
                                for k = 1:length(cx)
                                   dist(k) = sum((cx(k).Centroid - activeCells(i).Centroid(p - 1, :)) .^ 2); 
                                end
                                k = find(dist == min(dist));
                                if mean(im(pix.PixelIdxList{k})) > 1.5 * imavg(p)
                                    found = true;
                                    pixels.NumObjects = pixels.NumObjects + 1;
                                    pixels.PixelIdxList(end + 1) = pix.PixelIdxList(k);
                                    activeCells(i).Area(p) = activeCells(i).Area(p - 1);
%                                     activeCells(i).GreenArea(p) = activeCells(i).GreenArea(p - 1);
                                    activeCells(i).Centroid(p, :) = activeCells(i).Centroid(p - 1, :);
                                    activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :);
                                    activeCells(i).RedIntensity(p) = activeCells(i).RedIntensity(p - 1);
                                    activeCells(i).GreenIntensity(p) = activeCells(i).GreenIntensity(p - 1);
                                    activeCells(i).Alive(p) = 0;
                                    activeCells(i).Constriction(p) = activeCells(i).Constriction(p - 1);
                                    activeCells(i).Perimeter(p) = activeCells(i).Perimeter(p - 1);
                                    activeCells(i).Ratio(p) = activeCells(i).Ratio(p - 1);
                                end
                            end
                        end
                        if ~found
                            %update active cell i with current cell j's data
                            activeCells(i).Area(p) = cellData(j).Area;
%                             activeCells(i).GreenArea(p) = cellData(j).GreenArea;
                            activeCells(i).Centroid(p, :) = cellData(j).Centroid;
                            activeCells(i).BoundingBox(p, :) = cellData(j).BoundingBox;
                            activeCells(i).RedIntensity(p) = cellData(j).RedIntensity;
                            activeCells(i).GreenIntensity(p) = cellData(j).GreenIntensity;
                            activeCells(i).Perimeter(p) = cellData(j).Perimeter;
                            activeCells(i).Alive(p) = 1;
                            activeCells(i).CombinedCentroid = [];
                            cellData(j) = [];
                            error1(:, j) = [];
                            error2(:, j) = [];
                            error3(:, j) = [];
                        end
                        unassignedCells(i) = false;
                    end
                elseif activeCells(i).Rupture(p - 1) > 0 && m < 0.004 * l2 ^ 2
                    %make sure it isn't a mistakenly split nucleus
                    imtemp = imclearborder(bwR(round(max(1, min(activeCells(i).BoundingBox(p, 2), cellData(j).BoundingBox(2)) - 1):min(size(bwR, 1), max(activeCells(i).BoundingBox(p, 2) + activeCells(i).BoundingBox(p, 4), cellData(j).BoundingBox(2) + cellData(j).BoundingBox(4)) + 1)), round(max(1, min(activeCells(i).BoundingBox(p, 1), cellData(j).BoundingBox(1)) - 1):min(size(bwR, 2), max(activeCells(i).BoundingBox(p, 1) + activeCells(i).BoundingBox(p, 3), cellData(j).BoundingBox(1) + cellData(j).BoundingBox(3)) + 1))));
                    imtemp = imclose(imtemp, strel('disk', 1));
                    dist = -bwdist(~imtemp);
                    wshed = watershed(imhmin(dist, 16));
                    imtemp(wshed == 0) = 0;
                    cx = bwconncomp(imtemp, 4);
                    if cx.NumObjects == 1
                        activeCells(i).Centroid(p, :) = (activeCells(i).Area(p) .* activeCells(i).Centroid(p, :) + cellData(j).Area .* cellData(j).Centroid) ./ (activeCells(i).Area(p) + cellData(j).Area);
                        activeCells(i).RedIntensity(p) = (activeCells(i).Area(p) * activeCells(i).RedIntensity(p) + cellData(j).Area * cellData(j).RedIntensity) / (activeCells(i).Area(p) + cellData(j).Area);
                        activeCells(i).GreenIntensity(p) = (activeCells(i).Area(p) * activeCells(i).GreenIntensity(p) + cellData(j).Area * cellData(j).GreenIntensity) / (activeCells(i).Area(p) + cellData(j).Area);
                        activeCells(i).Perimeter(p) = activeCells(i).Perimeter(p) + cellData(j).Perimeter;
                        activeCells(i).Area(p) = activeCells(i).Area(p) + cellData(j).Area;
%                        activeCells(i).GreenArea(p) = activeCells(i).GreenArea(p) + cellData(j).GreenArea;
                        activeCells(i).BoundingBox(p, :) = [min(activeCells(i).BoundingBox(p, 1), cellData(j).BoundingBox(1)) min(activeCells(i).BoundingBox(p, 2), cellData(j).BoundingBox(2)) max(activeCells(i).BoundingBox(p, 1) + activeCells(i).BoundingBox(p, 3), cellData(j).BoundingBox(1) + cellData(j).BoundingBox(3))-min(activeCells(i).BoundingBox(p, 1), cellData(j).BoundingBox(1)) max(activeCells(i).BoundingBox(p, 2) + activeCells(i).BoundingBox(p, 4), cellData(j).BoundingBox(2) + cellData(j).BoundingBox(4))-min(activeCells(i).BoundingBox(p, 2), cellData(j).BoundingBox(2))];
                    else
                        %this cell is a new daughter cell
                        activeCells(end + 1).TimeAppearing = p;
                        activeCells(end).Area(p) = cellData(j).Area;
%                         activeCells(end).GreenArea(p) = cellData(j).GreenArea;
                        activeCells(end).Centroid(p, :) = cellData(j).Centroid;
                        activeCells(end).BoundingBox(p, :) = cellData(j).BoundingBox;
                        activeCells(end).RedIntensity(p) = cellData(j).RedIntensity;
                        activeCells(end).GreenIntensity(p) = cellData(j).GreenIntensity;
                        activeCells(end).Perimeter(p) = cellData(j).Perimeter;
                        activeCells(end).Rupture = zeros(1, timePoints);
                        activeCells(end).Alive = [zeros(1, p - 1) 1 zeros(1, timePoints - p)];
                        activeCells(end).CombinedCentroid = [];
                        activeCells(end).Parent = i + 0.5;
                        activeCells(end).Constriction = zeros(1, timePoints);
                        activeCells(end).Divided = false;
                        if activeCells(i).Alive(p) ~= 2
                            %other cell added to active cell i is a new daughter cell
                            activeCells(end + 1).TimeAppearing = p;
                            activeCells(end).Area(p) = activeCells(i).Area(p);
%                             activeCells(end).GreenArea(p) = activeCells(i).GreenArea(p);
                            activeCells(end).Centroid(p, :) = activeCells(i).Centroid(p, :);
                            activeCells(end).BoundingBox(p, :) = activeCells(i).BoundingBox(p, :);
                            activeCells(end).RedIntensity(p) = activeCells(i).RedIntensity(p);
                            activeCells(end).GreenIntensity(p) = activeCells(i).GreenIntensity(p);
                            activeCells(end).Perimeter(p) = activeCells(i).Perimeter(p);
                            activeCells(end).Rupture = zeros(1, timePoints);
                            activeCells(end).Alive = [zeros(1, p - 1) 1 zeros(1, timePoints - p)];
                            activeCells(end).Parent = i + 0.5;
                            activeCells(end).CombinedCentroid = [];
                            activeCells(end).Constriction = zeros(1, timePoints);
                            activeCells(end).Divided = false;
                            %active cell i is no longer around
                            activeCells(i).Alive(p) = 2;
                        end
                    end
                    cellData(j) = [];
                    error1(:, j) = [];
                    error2(:, j) = [];
                    error3(:, j) = [];
                end
                m = min(error1(:));
            end
            
            %% check distance from unassigned active cells to current cells. it's
            %possible two active cells began touching and only one current cell was
            %registered for it

            %but first make sure the unassigned cell didn't get not registered
            for i = find(unassignedCells)
                box = activeCells(i).BoundingBox(p - 1, :);
                imtemp = imfilter(medfilt2(im), g, 'same');
                imtemp = imfill(bwareaopen(imclose(imclearborder(imopen(imbinarize(imtemp(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)), 'adaptive', 'Sensitivity', 0.6), strel('disk', 1))), strel('disk', 1)), 500, 4), 'holes');
                t2 = false(size(im));
                t2(max(1, box(2) - 60):min(size(im, 1), box(2) + box(4) + 60), max(1, box(1) - 60):min(size(im, 2), box(1) + box(3) + 60)) = imtemp;
                pix = bwconncomp(t2, 4);
                cx = regionprops(pix);
                for k = pix.NumObjects:-1:1
                    if cx(k).Area < 1500 || bboxOverlapRatio(cx(k).BoundingBox, box, 'min') < 0.3 || sum(bwG(pix.PixelIdxList{k})) / cx(k).Area < 0.1
                      pix.PixelIdxList(k) = [];
                      pix.NumObjects = pix.NumObjects - 1;
                      cx(k) = [];                        
                    else
                        for k2 = 1:pixels.NumObjects
                           if ~isempty(intersect(pix.PixelIdxList{k}, pixels.PixelIdxList{k2}))
                              pix.PixelIdxList(k) = [];
                              pix.NumObjects = pix.NumObjects - 1;
                              cx(k) = [];
                              break
                           end
                        end
                    end
                end
                if pix.NumObjects > 0
                    dist = zeros(1, length(cx));
                    for j = 1:length(cx)
                       dist(j) = sum((cx(j).Centroid - activeCells(i).Centroid(p - 1, :)) .^ 2); 
                    end
                    j = find(dist == min(dist));
                    if mean(im(pix.PixelIdxList{j})) > 1.5 * imavg(p)
                        unassignedCells(i) = false;
                        pixels.NumObjects = pixels.NumObjects + 1;
                        pixels.PixelIdxList(end + 1) = pix.PixelIdxList(j);
                        activeCells(i).Area(p) = activeCells(i).Area(p - 1);
%                         activeCells(i).GreenArea(p) = activeCells(i).GreenArea(p - 1);
                        activeCells(i).Centroid(p, :) = activeCells(i).Centroid(p - 1, :);
                        activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :);
                        activeCells(i).RedIntensity(p) = activeCells(i).RedIntensity(p - 1);
                        activeCells(i).GreenIntensity(p) = activeCells(i).GreenIntensity(p - 1);
                        activeCells(i).Alive(p) = 0;
                        activeCells(i).Constriction(p) = activeCells(i).Constriction(p - 1);
                        activeCells(i).Perimeter(p) = activeCells(i).Perimeter(p - 1);
                        activeCells(i).Ratio(p) = activeCells(i).Ratio(p - 1);
                    end
                end
            end

            dist = zeros(find(~unassignedCells, 1, 'last'), find(unassignedCells, 1, 'last'));
            for i = find(~unassignedCells)
                for j = find(unassignedCells)
                    dist(i, j) = (activeCells(i).Centroid(p, 1) - activeCells(j).Centroid(p - 1, 1)) ^ 2 + (activeCells(i).Centroid(p, 2) - activeCells(j).Centroid(p - 1, 2)) ^ 2;
                end
            end
            for j = find(unassignedCells)
                i = dist(:, j);
                i = min(i(i > 0));
                if i < 0.0055 * l2 ^ 2
                    %try to split touching cells into separate objects
                    i = find(dist(:, j) == i);
                    wshed = watershed(imhmin(65535 - im .* uint16(bwR), 900));
                    temp = bwR;
                    temp(wshed == 0) = 0;
                    box = activeCells(i).BoundingBox(p, :);
                    pix = bwconncomp(bwareaopen(imclearborder(temp(round(max(1, box(2) - 1):min(size(bwR, 1), box(2) + box(4) + 1)), round(max(1, box(1) - 1):min(size(bwR, 2), box(1) + box(3) + 1)))), 1000, 4), 4);
                    if pix.NumObjects == 1
                        dist = -bwdist(~bwR);
                        wshed = watershed(imhmin(dist, 1.5));
                        if ~any(c == [0 15])
                            wshed(round([loc(s, 6):loc(s, 5) loc(s, 4):loc(s, 3) loc(s, 2):loc(s, 1)]), :) = 1;
                        end
                        temp = bwR;
                        temp(wshed == 0) = 0;
                        box = activeCells(i).BoundingBox(p, :);
                        pix = bwconncomp(bwareaopen(imclearborder(temp(round(max(1, box(2) - 1):min(size(bwR, 1), box(2) + box(4) + 1)), round(max(1, box(1) - 1):min(size(bwR, 2), box(1) + box(3) + 1)))), 1000, 4), 4);
                    end
                    if pix.NumObjects == 2
                        cx = regionprops(pix, 'Area', 'Centroid', 'BoundingBox', 'Perimeter');
                        activeCells(j).Alive(p) = 1;
                        if sqrt(sum((cx(1).Centroid + [box(1) box(2)] - activeCells(i).Centroid(p - 1, :)) .^ 2)) + sqrt(sum((cx(2).Centroid + [box(1) box(2)] - activeCells(j).Centroid(p - 1, :)) .^ 2)) > sqrt(sum((cx(1).Centroid + [box(1) box(2)] - activeCells(j).Centroid(p - 1, :)) .^ 2)) + sqrt(sum((cx(2).Centroid + [box(1) box(2)] - activeCells(i).Centroid(p - 1, :)) .^ 2))
                            k = i;
                            i = j;
                        else
                            k = j;
                        end
                        activeCells(i).Area(p) = cx(1).Area;
                        activeCells(k).Area(p) = cx(2).Area;
                        activeCells(i).Centroid(p, :) = cx(1).Centroid + [box(1) box(2)];
                        activeCells(k).Centroid(p, :) = cx(2).Centroid + [box(1) box(2)];
                        activeCells(i).BoundingBox(p, :) = cx(1).BoundingBox + [box(1) box(2) 0 0];
                        activeCells(k).BoundingBox(p, :) = cx(2).BoundingBox + [box(1) box(2) 0 0];
                        activeCells(i).RedIntensity(p) = mean(im(pix.PixelIdxList{1}));
                        activeCells(k).RedIntensity(p) = mean(im(pix.PixelIdxList{2}));
                        activeCells(i).GreenIntensity(p) = mean(grn(pix.PixelIdxList{1}));
                        activeCells(k).GreenIntensity(p) = mean(grn(pix.PixelIdxList{2}));
                        activeCells(i).Perimeter(p) = cx(1).Perimeter;
                        activeCells(k).Perimeter(p) = cx(2).Perimeter;
%                     elseif (~isempty(activeCells(j).CombinedCentroid) && 1.5 * activeCells(i).Area(p) > activeCells(i).Area(p - 1) + activeCells(j).Area(p - 1)) || 1.25 * activeCells(i).Area(p) > activeCells(j).Area(p - 1) + activeCells(i).Area(p - 1)
%                         displacement = activeCells(j).CombinedCentroid;
%                         box = activeCells(i).BoundingBox(p, :);
%                         if isempty(displacement)
%                             displacement = activeCells(i).Centroid(p, :) - (activeCells(i).Centroid(p - 1, :) + activeCells(j).Centroid(p - 1, :)) ./ 2;
%                             activeCells(j).BoundingBox(p, :) = activeCells(j).BoundingBox(p - 1, :) + [displacement 0 0];
%                             activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :) + [displacement 0 0];
%                         else
%                             displacement = activeCells(i).Centroid(p, :) - displacement;
%                             activeCells(j).BoundingBox(p, :) = activeCells(j).BoundingBox(p - 1, :) + [displacement 0 0];
%                             activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :) + [displacement 0 0];
%                         end
%                         activeCells(j).CombinedCentroid = activeCells(i).Centroid(p, :);
%                         activeCells(i).CombinedCentroid = activeCells(i).Centroid(p, :);
%                         activeCells(i).Centroid(p, :) = [(activeCells(i).BoundingBox(p, 1) + activeCells(i).BoundingBox(p, 3) / 2) (activeCells(i).BoundingBox(p, 2) + activeCells(i).BoundingBox(p, 4) / 2)];
%                         activeCells(j).Centroid(p, :) = [(activeCells(j).BoundingBox(p, 1) + activeCells(j).BoundingBox(p, 3) / 2) (activeCells(j).BoundingBox(p, 2) + activeCells(j).BoundingBox(p, 4) / 2)];
%                         activeCells(j).Area(p) = activeCells(j).Area(p - 1);
%                         activeCells(j).RedIntensity(p) = activeCells(j).RedIntensity(p - 1);
%                         activeCells(j).GreenIntensity(p) = activeCells(j).GreenIntensity(p - 1);
%                         activeCells(j).Alive(p) = 1;
%                         unassignedCells(j) = false;
%                         activeCells(i).Area(p) = activeCells(i).Area(p - 1);
%                         activeCells(i).RedIntensity(p) = activeCells(i).RedIntensity(p - 1);
%                         activeCells(i).GreenIntensity(p) = activeCells(i).GreenIntensity(p - 1);
%                         if activeCells(i).Centroid(p, 1) > activeCells(j).Centroid(p, 1)
%                             k = i;
%                             i = j;
%                         else
%                             k = j;
%                         end
%                         activeCells(i).Centroid(p, 1) = activeCells(i).Centroid(p, 1) + box(1) - activeCells(i).BoundingBox(p, 1);
%                         activeCells(i).BoundingBox(p, 1) = box(1);
%                         activeCells(k).Centroid(p, 1) = activeCells(k).Centroid(p, 1) + box(1) + box(3) - activeCells(k).BoundingBox(p, 1) - activeCells(k).BoundingBox(p, 3);
%                         activeCells(k).BoundingBox(p, 1) = box(1) + box(3) - activeCells(k).BoundingBox(p, 3);
%                         if activeCells(i).Centroid(p, 2) > activeCells(k).Centroid(p, 2)
%                             k = i;
%                             i = j;
%                         end
%                         activeCells(i).Centroid(p, 2) = activeCells(i).Centroid(p, 2) + box(2) - activeCells(i).BoundingBox(p, 2);
%                         activeCells(i).BoundingBox(p, 2) = box(2);
%                         activeCells(k).Centroid(p, 2) = activeCells(k).Centroid(p, 2) + box(2) + box(4) - activeCells(k).BoundingBox(p, 2) - activeCells(k).BoundingBox(p, 4);
%                         activeCells(k).BoundingBox(p, 2) = box(2) + box(4) - activeCells(k).BoundingBox(p, 4);
                    end
                end
            end

            %% current cells that are leftover must be new or a nucleus mistakenly split in two
            for i = 1:length(cellData)
                temp = true;
                for j = find(~unassignedCells)
                    if abs(activeCells(j).Area(p) + cellData(i).Area - activeCells(j).Area(p - 1)) < activeCells(j).Area(p - 1) / 2 && sum((activeCells(j).Centroid(p, :) - cellData(i).Centroid) .^ 2) < 0.0055 * l2 ^ 2
                        imtemp = imclearborder(bwR(round(max(1, min(activeCells(j).BoundingBox(p, 2), cellData(i).BoundingBox(2)) - 1):min(size(bwR, 1), max(activeCells(j).BoundingBox(p, 2) + activeCells(j).BoundingBox(p, 4), cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4)) + 1)), round(max(1, min(activeCells(j).BoundingBox(p, 1), cellData(i).BoundingBox(1)) - 1):min(size(bwR, 2), max(activeCells(j).BoundingBox(p, 1) + activeCells(j).BoundingBox(p, 3), cellData(i).BoundingBox(1) + cellData(i).BoundingBox(3)) + 1))));
                        if cellData(i).BoundingBox(2) > 100 && cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4) < size(bwR, 1) - 100
                            imtemp = imclose(imtemp, strel('disk', 1));
                            dist = -bwdist(~imtemp);
                            wshed = watershed(imhmin(dist, 16));
                            imtemp(wshed == 0) = 0;
                        end
                        cx = bwconncomp(imtemp, 4);
                        if cx.NumObjects == 1
                            temp = false;
                            activeCells(j).Centroid(p, :) = (activeCells(j).Area(p) .* activeCells(j).Centroid(p, :) + cellData(i).Area .* cellData(i).Centroid) ./ (activeCells(j).Area(p) + cellData(i).Area);
                            activeCells(j).RedIntensity(p) = (activeCells(j).Area(p) * activeCells(j).RedIntensity(p) + cellData(i).Area * cellData(i).RedIntensity) / (activeCells(j).Area(p) + cellData(i).Area);
                            activeCells(j).GreenIntensity(p) = (activeCells(j).Area(p) * activeCells(j).GreenIntensity(p) + cellData(i).Area * cellData(i).GreenIntensity) / (activeCells(j).Area(p) + cellData(i).Area);
                            activeCells(j).Perimeter(p) = activeCells(j).Perimeter(p) + cellData(i).Perimeter;
                            activeCells(j).Area(p) = activeCells(j).Area(p) + cellData(i).Area;
%                             activeCells(j).GreenArea(p) = activeCells(j).GreenArea(p) + cellData(i).GreenArea;
                            activeCells(j).BoundingBox(p, :) = [min(activeCells(j).BoundingBox(p, 1), cellData(i).BoundingBox(1)) min(activeCells(j).BoundingBox(p, 2), cellData(i).BoundingBox(2)) max(activeCells(j).BoundingBox(p, 1) + activeCells(j).BoundingBox(p, 3), cellData(i).BoundingBox(1) + cellData(i).BoundingBox(3))-min(activeCells(j).BoundingBox(p, 1), cellData(i).BoundingBox(1)) max(activeCells(j).BoundingBox(p, 2) + activeCells(j).BoundingBox(p, 4), cellData(i).BoundingBox(2) + cellData(i).BoundingBox(4))-min(activeCells(j).BoundingBox(p, 2), cellData(i).BoundingBox(2))];
                            activeCells(j).Alive(p) = 1;
                        end
                    end
                end
                if temp
                    activeCells(end + 1).TimeAppearing = p;
                    activeCells(end).Area(p) = cellData(i).Area;
%                     activeCells(end).GreenArea(p) = cellData(i).GreenArea;
                    activeCells(end).Centroid(p, :) = cellData(i).Centroid;
                    activeCells(end).BoundingBox(p, :) = cellData(i).BoundingBox;
                    activeCells(end).RedIntensity(p) = cellData(i).RedIntensity;
                    activeCells(end).GreenIntensity(p) = cellData(i).GreenIntensity;
                    activeCells(end).Perimeter(p) = cellData(i).Perimeter;
                    activeCells(end).Rupture = zeros(1, timePoints);
                    activeCells(end).Constriction = zeros(1, timePoints);
                    activeCells(end).Alive = zeros(1, timePoints);
                    activeCells(end).Alive(p) = 1;
                    activeCells(end).Parent = 0;
                    activeCells(end).Divided = false;
                end
            end

            %% remove cells that are gone from the active list
            for i = length(activeCells):-1:1
                if activeCells(i).Alive(p) == 0
                    if all(activeCells(i).Alive(max(1, p - 3):(p - 1)) == 0.5)
                        if activeCells(i).BoundingBox(p - 1, 2) < 50 || activeCells(i).BoundingBox(p - 1, 2) + activeCells(i).BoundingBox(p - 1, 4) > size(bwR, 1) - 50
                            for j = find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last'):(p - 1)
                                activeCells(i).Rupture(j) = 0;
                            end
                        end
                        finishedCells(end + 1) = activeCells(i);
                        activeCells(i) = [];
                        for j = 1:length(activeCells)
                            if activeCells(j).Parent > i && activeCells(j).Parent ~= floor(activeCells(j).Parent)
                                activeCells(j).Parent = activeCells(j).Parent - 1;
                            end
                        end
                    else
                        activeCells(i).Alive(p) = 0.5;
                        activeCells(i).Area(p) = activeCells(i).Area(p - 1);
%                         activeCells(i).GreenArea(p) = activeCells(i).GreenArea(p - 1);
                        activeCells(i).Centroid(p, :) = activeCells(i).Centroid(p - 1, :);
                        activeCells(i).BoundingBox(p, :) = activeCells(i).BoundingBox(p - 1, :);
                        activeCells(i).RedIntensity(p) = activeCells(i).RedIntensity(p - 1);
                        activeCells(i).GreenIntensity(p) = activeCells(i).GreenIntensity(p - 1);
                        activeCells(i).Rupture(p) = activeCells(i).Rupture(p - 1);
                        activeCells(i).Perimeter(p) = activeCells(i).Perimeter(p - 1);
                    end
                end
            end
            
            %% remove cells that have divided or left the image from the active list
            for i = length(activeCells):-1:1
                if any(activeCells(i).Alive(p) == [2 3])
                    if activeCells(i).Alive(p) == 2
                       activeCells(i).Divided = true;
                       for j = (find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last') + 1):(p - 1)
                           activeCells(i).Rupture(j) = -5;
                       end
                    end
                    activeCells(i).Alive(p) = 0;
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
            
            %% interpolate data for when a cell disappeaers and then reappears
            for i = 1:length(activeCells)
               if activeCells(i).Alive(p) == 1 && activeCells(i).Alive(p - 1) == 0.5
                   j = p - 2;
                   while activeCells(i).Alive(j) == 0.5
                       j = j - 1;
                   end
                   for k = (j + 1):(p - 1)
                      activeCells(i).Centroid(k, :) = activeCells(i).Centroid(j, :) + (k - j) ./ (p - j)  .* (activeCells(i).Centroid(p, :) - activeCells(i).Centroid(j, :));
                      activeCells(i).BoundingBox(k, :) = activeCells(i).BoundingBox(j, :) + (k - j) ./ (p - j)  .* (activeCells(i).BoundingBox(p, :) - activeCells(i).BoundingBox(j, :));
                      activeCells(i).Area(k) = activeCells(i).Area(j) + (k - j) ./ (p - j)  .* (activeCells(i).Area(p) - activeCells(i).Area(j));
                      activeCells(i).RedIntensity(k) = activeCells(i).RedIntensity(j) + (k - j) ./ (p - j)  .* (activeCells(i).RedIntensity(p) - activeCells(i).RedIntensity(j));
                      activeCells(i).GreenIntensity(k) = activeCells(i).GreenIntensity(j) + (k - j) ./ (p - j)  .* (activeCells(i).GreenIntensity(p) - activeCells(i).GreenIntensity(j));
                      activeCells(i).Perimeter(k) = activeCells(i).Perimeter(j) + (k - j) ./ (p - j)  .* (activeCells(i).Perimeter(p) - activeCells(i).Perimeter(j));
                      activeCells(i).Ratio(k) = activeCells(i).Ratio(k - 1);
%                       ratio1 = activeCells(i).RedIntensity(k) / activeCells(i).GreenIntensity(k);
%                       activeCells(i).Ratio(k) = ratio1;
%                       if (activeCells(i).BoundingBox(k, 2) > loc(s, 6) - 3.7 * l && activeCells(i).BoundingBox(k, 2) + activeCells(i).BoundingBox(k, 4) < loc(s, 1) + 3.2 * l) || activeCells(i).Rupture(k - 1) > 0 || c == 0
%                           ratio2 = activeCells(i).Ratio(k - 1);
%                            if (ratio1 - ratio2) / ratio2 > 0.15
%                                activeCells(i).Rupture(k) = 1;
%                            elseif activeCells(i).Rupture(k - 1) == 1
%                                if (ratio2 - ratio1) / ratio1 > 0.075 
%                                    activeCells(i).Rupture(k) = 0.5;
%                                else
%                                    activeCells(i).Rupture(k) = 1;
%                                end
%                            elseif activeCells(i).Rupture(k - 1) == 0.5
%                                if (ratio1 - ratio2) / ratio2 > 0.1
%                                    activeCells(i).Rupture(k) = 1;
%                                elseif (ratio2 - ratio1) / ratio1 > 0.03
%                                    activeCells(i).Rupture(k) = 0.5;
%                                else
%                                    activeCells(i).Rupture(k) = 0.25;
%                                end
%                            elseif activeCells(i).Rupture(k - 1) == 0.25
%                                if (ratio1 - ratio2) / ratio2 > 0.125
%                                    activeCells(i).Rupture(k) = 0.1;
%                                elseif (ratio2 - ratio1) / ratio2 > 0.05
%                                    activeCells(i).Rupture(k) = 0.5;
%                                elseif (ratio2 - ratio1) / ratio2 > 0.03
%                                    activeCells(i).Rupture(k) = 0.25;
%                                end
%                            end
%                       end
                      if c ~= 0
                        if activeCells(i).BoundingBox(k, 2) > loc(s, 1)
                            activeCells(i).Constriction(k) = 0.2;
                        %bottom of cell below top of constriction 1
                        elseif activeCells(i).BoundingBox(k, 2) + activeCells(i).BoundingBox(k, 4) > loc(s, 2)
                            activeCells(i).Constriction(k) = 1;
                        %top of cell below bottom of constriction 2
                        elseif activeCells(i).BoundingBox(k, 2) > loc(s, 3)
                            activeCells(i).Constriction(k) = 1.2;
                        %bottom of cell below top of constriction 2
                        elseif activeCells(i).BoundingBox(k, 2) + activeCells(i).BoundingBox(k, 4) > loc(s, 4)
                            activeCells(i).Constriction(k) = 2;
                        %top of cell below bottom of constriction 3
                        elseif activeCells(i).BoundingBox(k, 2) > loc(s, 5)
                            activeCells(i).Constriction(k) = 2.2;
                        %bottom of cell below top of constriction 3
                        elseif activeCells(i).BoundingBox(k, 2) + activeCells(i).BoundingBox(k, 4) > loc(s, 6)
                            activeCells(i).Constriction(k) = 3;
                        %bottom of cell above top of constriction 3
                        else
                            activeCells(i).Constriction(k) = 3.2;
                        end
                      end
                   end
               end
            end
            
            checkConstrictionPassageNLSH2B
            
            %% a nucleus halfway through a constriction is often mistaken as separate
            %objects so check for that
            if ~any(c == [0 15])
                for i = length(activeCells):-1:1
                    if any(activeCells(i).Constriction(p) == [1 2 3]) && activeCells(i).TimeAppearing == p
                        k = [activeCells(1:(i - 1)).Constriction];
                        k = find(activeCells(i).Constriction(p) == k(p:timePoints:end));
                        k2 = 50;
                        for k3 = k
                            k2 = min(k2, abs(activeCells(i).Centroid(p, 1) - activeCells(k3).Centroid(p, 1)));
                        end
                        if k2 < 50
                            for k3 = k
                               if abs(activeCells(i).Centroid(p, 1) - activeCells(k3).Centroid(p, 1)) == k2
                                   break
                               end
                            end
                            if activeCells(k3).TimeAppearing == p && activeCells(k3).Parent ~= 0
                                temp = finishedCells(activeCells(k3).Parent);
                                finishedCells(activeCells(k3).Parent) = [];
                                for j = 1:length(activeCells)
                                    if activeCells(j).Parent > activeCells(k3).Parent
                                        activeCells(j).Parent = activeCells(j).Parent - 1;
                                    end
                                end
                                activeCells(k3).Parent = temp.Parent;
                                activeCells(k3).TimeAppearing = temp.TimeAppearing;
                                activeCells(k3).Centroid(1:p - 1, :) = temp.Centroid(1:p - 1, :);
                                activeCells(k3).BoundingBox(1:p - 1, :) = temp.BoundingBox(1:p - 1, :);
                                activeCells(k3).Alive(1:p - 1) = temp.Alive(1:p - 1);
                                activeCells(k3).Rupture(1:p - 1) = temp.Rupture(1:p - 1);
                                activeCells(k3).Rupture(activeCells(k3).Rupture == -5) = 0.5;
                                activeCells(k3).Constriction(1:p - 1) = temp.Constriction(1:p - 1);
                                activeCells(k3).RedIntensity(1:p - 1) = temp.RedIntensity(1:p - 1);
                                activeCells(k3).GreenIntensity(1:p - 1) = temp.GreenIntensity(1:p - 1);
                                activeCells(k3).Ratio(1:p - 1) = temp.Ratio(1:p - 1);
                                activeCells(k3).Perimeter(1:p - 1) = temp.Perimeter(1:p - 1);
                                activeCells(k3).Area(1:p - 1) = temp.Area(1:p - 1);
                            end
                            activeCells(k3).Centroid(p, :) = (activeCells(k3).Area(p) .* activeCells(k3).Centroid(p, :) + activeCells(i).Area(p) .* activeCells(i).Centroid(p, :)) ./ (activeCells(k3).Area(p) + activeCells(i).Area(p));
                            activeCells(k3).BoundingBox(p, :) = [min(activeCells(k3).BoundingBox(p, 1), activeCells(i).BoundingBox(p, 1)) min(activeCells(k3).BoundingBox(p, 2), activeCells(i).BoundingBox(p, 2)) max(activeCells(k3).BoundingBox(p, 1) + activeCells(k3).BoundingBox(p, 3), activeCells(i).BoundingBox(p, 1) + activeCells(i).BoundingBox(p, 3))-min(activeCells(k3).BoundingBox(p, 1), activeCells(i).BoundingBox(p, 1)) max(activeCells(k3).BoundingBox(p, 2) + activeCells(k3).BoundingBox(p, 4), activeCells(i).BoundingBox(p, 2) + activeCells(i).BoundingBox(p, 4))-min(activeCells(k3).BoundingBox(p, 2), activeCells(i).BoundingBox(p, 2))];
                            activeCells(k3).RedIntensity(p) = (activeCells(k3).RedIntensity(p) * activeCells(k3).Area(p) + activeCells(i).RedIntensity(p) * activeCells(i).Area(p)) / (activeCells(k3).Area(p) + activeCells(i).Area(p));
                            activeCells(k3).GreenIntensity(p) = (activeCells(k3).GreenIntensity(p) * activeCells(k3).Area(p) + activeCells(i).GreenIntensity(p) * activeCells(i).Area(p)) / (activeCells(k3).Area(p) + activeCells(i).Area(p));
                            activeCells(k3).Perimeter(p) = activeCells(k3).Perimeter(p) + activeCells(i).Perimeter(p);
                            activeCells(k3).Area(p) = activeCells(k3).Area(p) + activeCells(i).Area(p);
                            activeCells(k3).Alive(p) = 1;
                            activeCells(i) = [];
                        end
                    end
                end
            end

            checkForRupture
        end
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
   if sum(finishedCells(i).Alive == 1) <= 3 && ~finishedCells(i).Alive(end)
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
if all(c ~= [0 15])
    if isAVI
        tempIm = im3(:, :, 3);
    else
        tempIm = bfGetPlane(reader, channels + dic);
    end
    centers = imfindcircles(bwareaopen(edge(imrotate(tempIm, angle(s)), 'zerocross'), 10), round([1.135 1.816] .* l), 'Sensitivity', 0.9);
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
            p = find(finishedCells(i).Alive, 2);
            if length(p) > 1
                p = p(2);
            end
            for p = p:find(finishedCells(i).Alive, 1, 'last')
                if j == 0
                    if finishedCells(i).Constriction(p) == floor(finishedCells(i).Constriction(p))
                        j = p;
                        k = find(finishedCells(i).Centroid(p, 1) >= centers, 1, 'last');
                    end
                else
                    if finishedCells(i).Constriction(p) == finishedCells(i).Constriction(j)
                        if finishedCells(i).Centroid(p, 2) > loc(s, 2 * finishedCells(i).Constriction(p) - 1) && finishedCells(i).BoundingBox(p, 2) > loc(s, 2 * finishedCells(i).Constriction(p)) && (finishedCells(i).Centroid(p, 1) < centers(k) || finishedCells(i).Centroid(p, 1) > centers(k + 1))
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
end

%% make a pretty video to check for accuracy of cell finding
group = ones(1, length(finishedCells));
for i = 1:length(finishedCells)
    j = find(finishedCells(i).Rupture > 0, 1);
    if ~isempty(j) && (any(finishedCells(i).Rupture(j:find(finishedCells(i).Alive, 1, 'last')) <= 0) || find(finishedCells(i).Alive, 1, 'last') < timePoints)
        group(i) = 2;
    end
    j = 0;
    p = find(finishedCells(i).Alive);
    for p = p(2:end)
        if j == 0 && finishedCells(i).Constriction(p) == floor(finishedCells(i).Constriction(p)) && finishedCells(i).Constriction(p) > finishedCells(i).Constriction(p - 1)
            j = 1;
        elseif j == 1 && finishedCells(i).Constriction(p) ~= finishedCells(i).Constriction(p - 1)
            group(i) = group(i) + 2;
            break
        end
    end
end

fprintf('\n\t\tCompiling video for accuracy checking...')
i = size(bwR);
%      gray         cyan       magenta    blue
col = [128 128 128; 0 255 255; 255 0 255; 0 0 255];
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
for p = 1:timePoints
    im = video4(:, :, :, p);
    a2 = a(p:timePoints:end);
    r2 = r(p:timePoints:end);
    c2 = cx(p:timePoints:end);
    k = [];
    for j = find(a2 & r2 > 0 & c2 == floor(c2))
       k = [k; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(k)
        im = insertText(im, k, 'CR', 'FontSize', k3, 'BoxColor', 'white');
    end
    k = [];
    for j = find(a2 & r2 > 0 & c2 ~= floor(c2))
       k = [k; finishedCells(j).BoundingBox(p, 1:2)];  %#ok<*AGROW>
    end
    if ~isempty(k)
        im = insertText(im, k, 'R', 'FontSize', k3, 'BoxColor', 'white');
    end
    k = [];
    for j = find(a2 & r2 == 0 & c2 == floor(c2))
       k = [k; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(k)
        im = insertText(im, k, 'C', 'FontSize', k3, 'BoxColor', 'magenta');
    end
    k = [];
    for j = find(a2 & r2 == -5 & c2 == floor(c2))
       k = [k; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(k)
        im = insertText(im, k, 'CD', 'FontSize', k3, 'BoxColor', 'white');
    end
    k = [];
    for j = find(a2 & r2 == -5 & c2 ~= floor(c2))
       k = [k; finishedCells(j).BoundingBox(p, 1:2)]; 
    end
    if ~isempty(k)
        im = insertText(im, k, 'D', 'FontSize', k3, 'BoxColor', 'white');
    end
    colors = zeros(sum(a2 > 0), 3);
    lines = cell(1, 4);
    circles = zeros(sum(a2 > 0), 3);
    rectangles = zeros(sum(a2 > 0), 4);
    a2 = find(a2);
    for j = 1:length(a2)
        colors(j, :) = col(group(a2(j)), :);
        circles(j, :) = [finishedCells(a2(j)).Centroid(p, :) k2];
        rectangles(j, :) = finishedCells(a2(j)).BoundingBox(p, :);
        lines{group(a2(j))} = [lines{group(a2(j))}; finishedCells(a2(j)).Centroid(max(find(finishedCells(a2(j)).Alive, 1), p - 10):(p - 1), :) finishedCells(a2(j)).Centroid(max(find(finishedCells(a2(j)).Alive, 1) + 1, p - 9):p, :)];
    end
    for j = 1:4
        im = insertShape(im, 'Line', lines{j}, 'LineWidth', k2, 'Color', col(j, :)); 
    end
    im = insertShape(im, 'Rectangle', rectangles, 'LineWidth', k2, 'Color', colors);
    im = insertShape(im, 'FilledCircle', circles, 'Color', colors);
    if c ~= 0
        im = insertShape(im, 'Line', [[1; 1; 1; 1; 1; 1] loc(s, :)' [i(2); i(2); i(2); i(2); i(2); i(2)] loc(s, :)'], 'LineWidth', 3, 'Color', 'white');
    end
    video4(:, :, :, p) = im;
end