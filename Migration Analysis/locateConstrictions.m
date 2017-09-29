function [rotated, angle, loc] = locateConstrictions(im, c, cellsFromTop, l, t)
    rotated = [];
    loc = [];
    angle = [];
    %% get angle of rotation for each section, skip constrictionless sections and 15 micron sections
    if all(c ~= 15) && c > 0
        [centers, radii] = imfindcircles(bwareaopen(edge(im, 'zerocross'), 10), round([1.16 1.816] .* l), 'Sensitivity', 0.9);
        for i = length(radii):-1:1
            if radii(i) < 1.376 * l
                radii(i) = [];
                centers(i, :) = [];
            end
        end
        if ~isempty(centers)
            %% work with circles to locate constrictions

            %sort constrictions so that we only have the top row
            x = histcounts(centers(:, 2), 3);
            
            if x(1) > 0 && x(3) > 0
                sortedCenters = sort(centers(:, 2), 1, 'ascend');
                if x(2) > 15
                    if x(1) < 4
                        y = zeros(x(1), 1);
                        for i = 1:x(1)
                            y(i) = find(centers(:, 2) == sortedCenters(i));
                        end
                        centers(y, :) = [];
                        x = histcounts(centers(:, 2), 3);
                    elseif x(3) < 4
                        y = zeros(x(3), 1);
                        for i = 1:x(3)
                            y(i) = find(centers(:, 2) == sortedCenters(x(1) + x(2) + i));
                        end
                        centers(y, :) = [];
                        x = histcounts(centers(:, 2), 3);
                    end
                end
                if x(1) > 0 && x(3) > 0
                    if cellsFromTop
                        highCenters = find(centers(:, 2) > sortedCenters(end - x(3)));
                    else
                        highCenters = find(centers(:, 2) <= sortedCenters(x(1)));
                    end

                    %perform linear regression to get the angle of the device and rotate it
                    %properly
                    j = polyfit(centers(highCenters, 1), centers(highCenters, 2), 1);
                    angle = 180 * (atan(j(1)) / pi + cellsFromTop);
                    im = imrotate(im, angle);

                    %look for circles again
                    [centers, radii] = imfindcircles(bwareaopen(edge(im, 'zerocross'), 10), round([1.16 1.816] .* l), 'Sensitivity', 0.9);
                    for i = length(radii):-1:1
                        if radii(i) < 1.376 * l
                            radii(i) = [];
                            centers(i, :) = [];
                        end
                    end
                    try
                        %sort circles into each of the three constrictions to get constriction
                        %heights
                        x = histcounts(centers(:, 2), 3);
                        sortedCenters = sort(centers(:, 2), 1, 'ascend');
                        if any(x > 18)
                            if x(1) < 4
                                y = zeros(x(1), 1);
                                for i = 1:x(1)
                                    y(i) = find(centers(:, 2) == sortedCenters(i));
                                end
                                centers(y, :) = [];
                                radii(y) = [];
                                x = histcounts(centers(:, 2), 3);
                            elseif x(3) < 4
                                y = zeros(x(3), 1);
                                for i = 1:x(3)
                                    y(i) = find(centers(:, 2) == sortedCenters(x(1) + x(2) + i));
                                end
                                centers(y, :) = [];
                                radii(y) = [];
                                x = histcounts(centers(:, 2), 3);
                            end
                        end
                        highCenters = find(centers(:, 2) <= sortedCenters(x(1)));
                        i = std(centers(highCenters, 2));
                        if i > 2 * l
                            highCenters(1.5 * i < abs(mean(centers(highCenters, 2)) - centers(highCenters, 2))) = []; 
                        end
                        midCenters = find(centers(:, 2) > sortedCenters(x(1)) & centers(:, 2) <= sortedCenters(x(1) + x(2)));
                        lowCenters = find(centers(:, 2) > sortedCenters(x(1) + x(2)));
                        i = std(centers(lowCenters, 2));
                        if i > 2 * l
                            lowCenters(1.5 * i < abs(mean(centers(lowCenters, 2)) - centers(lowCenters, 2))) = []; 
                        end
                        loc = [mean(centers(lowCenters, 2) + radii(lowCenters)) mean(centers(lowCenters, 2) - radii(lowCenters)) mean(centers(midCenters, 2) + radii(midCenters)) mean(centers(midCenters, 2) - radii(midCenters)) mean(centers(highCenters, 2) + radii(highCenters)) mean(centers(highCenters, 2) - radii(highCenters))];

                        l = 0.7 * l;
                        j = size(im, 2);
                        im = insertShape(imadjust(im), 'Line', [[1; 1; 1; 1; 1; 1] loc' [j; j; j; j; j; j] loc'], 'LineWidth', t, 'Color', 'red');
                        loc = [mean(centers(lowCenters, 2))+l mean(centers(lowCenters, 2))-l mean(centers(midCenters, 2))+l mean(centers(midCenters, 2))-l mean(centers(highCenters, 2))+l mean(centers(highCenters, 2))-l];
                        im = insertShape(im, 'Line', [[1; 1; 1; 1; 1; 1] loc' [j; j; j; j; j; j] loc'], 'LineWidth', t, 'Color', 'blue');
                        rotated = insertShape(im, 'Circle', [centers([lowCenters; midCenters; highCenters], :) radii([lowCenters; midCenters; highCenters])], 'LineWidth', t + 1, 'Color', 'Red');
                    catch
                    end
                end
            end
        end
    end
end