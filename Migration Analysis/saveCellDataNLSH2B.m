%% print transit time data to .csv file
% Josh Elacqua, March 6, 2018
flag2 = true;
if ~isempty([constriction.Duration]) && any([constriction.Success] == 1)
    flag2 = false;
    
    if finishedCells(i).Parent == 0
        num = floor(num + 1);
    else
        num = num + 0.1;
    end
    
    if flag1a
        flag1a = false;
       fprintf(fidS, '\n%s,%g,%g', name, s, frameRate * timePoints);
    else
       fprintf(fidS, '\n,,'); 
    end

    %print                              cell number, initial time point,             initial X,                                                    initial Y
    fprintf(fidS, ',%g,%g,%g,%g,%g,%s,', num, finishedCells(i).TimeAppearing, finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 1), finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 2), c, finishedCells(i).Note{1});
    
    %% print first constriction
    for j = 2:length(constriction)
        if constriction(j).Success == 1
            vel = [0 0];
            for k = (constriction(j).Enter + 1):(find(finishedCells(i).BoundingBox(constriction(j).Enter:end, 2) < (loc(s, constriction(j).Number * 2) + loc(s, constriction(j).Number * 2 - 1)) / 2, 1) + constriction(j).Enter)
                vel = [vel(1) + abs(finishedCells(i).BoundingBox(k, 2) - finishedCells(i).BoundingBox(k - 1, 2)), vel(2) + 1];
            end
            fprintf(fidS, '%g,%g,%g,%g,%g,,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success, vel(1), vel(1) / vel(2), find(finishedCells(i).BoundingBox(constriction(j).Enter:end, 2) < (loc(s, constriction(j).Number * 2) + loc(s, constriction(j).Number * 2 - 1)) / 2, 1));
            break
        end
    end
    %% print rest of constrictions
    for j = (j + 1):length(constriction)
        if constriction(j).Success == 1
            vel = [0 0];
            for k = (constriction(j).Enter + 1):(find(finishedCells(i).BoundingBox(constriction(j).Enter:end, 2) < (loc(s, constriction(j).Number * 2) + loc(s, constriction(j).Number * 2 - 1)) / 2, 1) + constriction(j).Enter)
                vel = [vel(1) + abs(finishedCells(i).BoundingBox(k, 2) - finishedCells(i).BoundingBox(k - 1, 2)), vel(2) + 1];
            end
            fprintf(fidS, '\n,,,,,,,,,%g,%g,%g,%g,%g,,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success, vel(1), vel(1) / vel(2), find(finishedCells(i).BoundingBox(constriction(j).Enter:end, 2) < (loc(s, constriction(j).Number * 2) + loc(s, constriction(j).Number * 2 - 1)) / 2, 1));
        end
    end
end

%% print success data to .csv file
if ~isempty([constriction.Duration]) && any([constriction.Number] == 1)
    
    if flag2
        if finishedCells(i).Parent == 0
            num = floor(num + 1);
        else
            num = num + 0.1;
        end
    end
    flag2 = false;
    
    if flag1b
        flag1b = false;
       fprintf(fid, '\n%s,%g,%g', name, s, frameRate * timePoints);
    else
       fprintf(fid, '\n,,'); 
    end

    %print                              cell number, initial time point,             initial X,                                                    initial Y
    fprintf(fid, ',%g,%g,%g,%g,%g,%s,', num, finishedCells(i).TimeAppearing, finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 1), finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 2), c, finishedCells(i).Note{1});
    
    %% print first constriction
    for j = 2:length(constriction)
        if constriction(j).Number == 1
            fprintf(fid, '%g,%g,%g,%g,%g,', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
            break
        end
    end
        
    %% print rest of constrictions
    for j = (j + 1):length(constriction)
        if constriction(j).Number == 1
            fprintf(fid, '\n,,,,,,,,,%g,%g,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
        end
    end
end

if ~isempty([constriction.Duration]) && any([constriction.Number] == 2)
    
    if flag2
        if finishedCells(i).Parent == 0
            num = floor(num + 1);
        else
            num = num + 0.1;
        end
    end
    flag2 = false;
    
    if flag1c
        flag1c = false;
       fprintf(fid2, '\n%s,%g,%g', name, s, frameRate * timePoints);
    else
       fprintf(fid2, '\n,,'); 
    end

    %print                              cell number, initial time point,             initial X,                                                    initial Y
    fprintf(fid2, ',%g,%g,%g,%g,%g,%s,', num, finishedCells(i).TimeAppearing, finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 1), finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 2), c, finishedCells(i).Note{1});
    
    %% print first constriction
    for j = 2:length(constriction)
        if constriction(j).Number == 2
            fprintf(fid2, '%g,%g,%g,%g,%g,', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
            break
        end
    end
        
    %% print rest of constrictions
    for j = (j + 1):length(constriction)
        if constriction(j).Number == 2
            fprintf(fid2, '\n,,,,,,,,,%g,%g,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
        end
    end
end

if ~isempty([constriction.Duration]) && any([constriction.Number] == 3)
    
    if flag2
        if finishedCells(i).Parent == 0
            num = floor(num + 1);
        else
            num = num + 0.1;
        end
    end
    flag2 = false;
    
    if flag1d
        flag1d = false;
       fprintf(fid3, '\n%s,%g,%g', name, s, frameRate * timePoints);
    else
       fprintf(fid3, '\n,,'); 
    end

    %print                              cell number, initial time point,             initial X,                                                    initial Y
    fprintf(fid3, ',%g,%g,%g,%g,%g,%s,', num, finishedCells(i).TimeAppearing, finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 1), finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 2), c, finishedCells(i).Note{1});
    
    %% print first constriction
    for j = 2:length(constriction)
        if constriction(j).Number == 3
            fprintf(fid3, '%g,%g,%g,%g,%g,', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
            break
        end
    end
        
    %% print rest of constrictions
    for j = (j + 1):length(constriction)
        if constriction(j).Number == 3
            fprintf(fid3, '\n,,,,,,,,,%g,%g,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
        end
    end
end

%% print rupture data to .csv file
if ~isempty([rupture.Duration])
    
    if flag2
        if finishedCells(i).Parent == 0
            num = floor(num + 1);
        else
            num = num + 0.1;
        end
    end
    flag2 = false;
    
    if flagR
       flagR = false;
       fprintf(fidR, '\n%s,%g,%g', name, s, frameRate * timePoints);
    else
       fprintf(fidR, '\n,,'); 
    end
    
    for j = 2:length(unfinishedRuptures)
        if unfinishedRuptures(j).CellNumber == i && unfinishedRuptures(j).Position == s
            unfinishedRuptures(j).Number = num;
            break;
        end
    end
    
    %print                                           cell number, initial time point,             initial X,                                                    initial Y,                                            does cell rupture,   total rupture events, cell died due to rupture,                                                                         cell divides
    fprintf(fidR, ',%g,%g,%g,%g,%g,%g,%g,%g,%g,%s,', num, finishedCells(i).TimeAppearing, finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 1), finishedCells(i).Centroid(finishedCells(i).TimeAppearing, 2), length(rupture) > 1, length(rupture) - 1, stop ~= timePoints && finishedCells(i).Rupture(stop) > 0 && ~finishedCells(i).Divided, finishedCells(i).Divided, c, finishedCells(i).Note{1});
    
    dueToConstriction = any(finishedCells(i).Constriction(rupture(2).Start) == [1 2 3]);
    if dueToConstriction == 1
        whichConstriction = num2str(finishedCells(i).Constriction(rupture(2).Start));
    else
        whichConstriction = ['n; last ' num2str(round(finishedCells(i).Constriction(rupture(2).Start)))];
    end
    intensity = (finishedCells(i).GreenIntensity(rupture(2).Start + 1) / finishedCells(i).RedIntensity(rupture(2).Start + 1) - finishedCells(i).GreenIntensity(rupture(2).Start) / finishedCells(i).RedIntensity(rupture(2).Start)) / (finishedCells(i).GreenIntensity(rupture(2).Start + 1) ./ finishedCells(i).RedIntensity(rupture(2).Start + 1));
    if intensity > 0.45
        intensity = 'High';
    elseif intensity > 0.35
        intensity = 'Medium';
    else
        intensity = 'Low';
    end
%     fprintf(fid, '%g,%s,%g,%s,%g,%g,%g,%g,%g', dueToConstriction, whichConstriction, ~dueToConstriction, intensity, rupture(2).Start, rupture(2).End, rupture(2).Duration, length(rupture) > 2, (4 * pi * finishedCells(i).Area(rupture(2).End) / (finishedCells(i).Perimeter(rupture(2).End) ^ 2)) < 0.45);
    fprintf(fidR, '%g,%s,%g,%s,%g,%g,%g,%g,%g', dueToConstriction, whichConstriction, ~dueToConstriction, intensity, rupture(2).Start, rupture(2).End, rupture(2).Duration, length(rupture) > 2, (4 * pi * finishedCells(i).Area(rupture(2).End) / (finishedCells(i).Perimeter(rupture(2).End) ^ 2)) < 0.45);
    
    for j = 3:length(rupture)
        intensity = (finishedCells(i).GreenIntensity(rupture(j).Start + 1) / finishedCells(i).RedIntensity(rupture(j).Start + 1) - finishedCells(i).GreenIntensity(rupture(j).Start) / finishedCells(i).RedIntensity(rupture(j).Start)) / (finishedCells(i).GreenIntensity(rupture(j).Start + 1) ./ finishedCells(i).RedIntensity(rupture(j).Start + 1));
        if intensity > 0.45
            intensity = 'High';
        elseif intensity > 0.35
            intensity = 'Medium';
        else
            intensity = 'Low';
        end
        dueToConstriction = any(finishedCells(i).Constriction(rupture(j).Start) == [1 2 3]);
%         fprintf(fid, ',%g,%g,%g,%s,%g,%g,%g,%g,%g', dueToConstriction, nan, ~dueToConstriction, intensity, rupture(j).Start, rupture(j).End, rupture(j).Duration, length(rupture) > j, (4 * pi * finishedCells(i).Area(rupture(j).End) / (finishedCells(i).Perimeter(rupture(j).End) ^ 2)) < 0.45);
        fprintf(fidR, ',%g,%g,%g,%s,%g,%g,%g,%g,%g', dueToConstriction, c, ~dueToConstriction, intensity, rupture(j).Start, rupture(j).End, rupture(j).Duration, length(rupture) > j, (4 * pi * finishedCells(i).Area(rupture(j).End) / (finishedCells(i).Perimeter(rupture(j).End) ^ 2)) < 0.45);
    end
    
    for j = 2:length(rupture)
        if find(finishedCells(i).Rupture((rupture(j).Start + 1):end) == 1, 1) ~= -1
            temp = find(finishedCells(i).Rupture((rupture(j).Start + 1):end) ~= 1, 1);
            until = rupture(j).Start + temp + find(finishedCells(i).Rupture((rupture(j).Start + temp + 1):end) == 1, 1) - 1;
        elseif length(rupture) > j
            until = rupture(j + 1).Start - 1;
        elseif ~isempty(fields(unfinishedRuptures)) && unfinishedRuptures(end).Position == s && unfinishedRuptures(end).CellNumber == i
            until = unfinishedRuptures(end).Start - 1;
        else
            until = find(finishedCells(i).Alive, 1, 'last');
        end
        subt = finishedCells(i).Ratio(rupture(j).Start - 1);
        mult = 1 / (max(finishedCells(i).Ratio(rupture(j).Start:min(rupture(j).Start + 10, find(finishedCells(i).Alive == 1, 1, 'last')))) - subt);
        if ~isempty(fields(unfinishedRuptures)) && unfinishedRuptures(end).Start < until && max(finishedCells(i).Ratio(unfinishedRuptures(end).Start:until)) - finishedCells(i).Ratio(unfinishedRuptures(end).Start) < 2 * (max(finishedCells(i).Ratio(unfinishedRuptures(end).Start:until)) - finishedCells(i).Ratio(until))
            fprintf(fidR2, '\n%g,%g,', s, num);
            for p = (rupture(j).Start - 10):until
                fprintf(fidR2, ',');
                if p >= finishedCells(i).TimeAppearing
                    fprintf(fidR2, '%f', (finishedCells(i).Ratio(p) - subt) * mult);
                end
            end
        end
    end
end

if ~isempty(fields(unfinishedRuptures)) && unfinishedRuptures(end).Position == s && unfinishedRuptures(end).CellNumber == i && find(finishedCells(i).Alive == 1, 1, 'last') > unfinishedRuptures(end).Start
    until = find(finishedCells(i).Alive, 1, 'last');
    subt = finishedCells(i).Ratio(unfinishedRuptures(end).Start - 1);
    mult = 1 / (max(finishedCells(i).Ratio(unfinishedRuptures(end).Start:min(unfinishedRuptures(end).Start + 10, find(finishedCells(i).Alive == 1, 1, 'last')))) - subt);
    if max(finishedCells(i).Ratio(unfinishedRuptures(end).Start:until)) - finishedCells(i).Ratio(unfinishedRuptures(end).Start) < 2 * (max(finishedCells(i).Ratio(unfinishedRuptures(end).Start:until)) - finishedCells(i).Ratio(until))
        fprintf(fidR2, '\n%g,%g,', s, num);
        for p = (unfinishedRuptures(end).Start - 10):until
            fprintf(fidR2, ',');
            if p >= finishedCells(i).TimeAppearing
                fprintf(fidR2, '%f', (finishedCells(i).Ratio(p) - subt) * mult);
            end
        end
    end
    
    if flag2
        if finishedCells(i).Parent == 0
            num = floor(num + 1);
        else
            num = num + 0.1;
        end
    end
    flag2 = false;
    
    dueToConstriction = any(finishedCells(i).Constriction(unfinishedRuptures(end).Start) == [1 2 3]);
    if dueToConstriction == 1
        whichConstriction = num2str(finishedCells(i).Constriction(unfinishedRuptures(end).Start));
    else
        whichConstriction = ['n; last ' num2str(round(finishedCells(i).Constriction(unfinishedRuptures(end).Start)))];
    end
    intensity = (finishedCells(i).GreenIntensity(unfinishedRuptures(end).Start) / finishedCells(i).RedIntensity(unfinishedRuptures(end).Start) - finishedCells(i).GreenIntensity(unfinishedRuptures(end).Start - 1) / finishedCells(i).RedIntensity(unfinishedRuptures(end).Start - 1)) / (finishedCells(i).GreenIntensity(unfinishedRuptures(end).Start - 1) ./ finishedCells(i).RedIntensity(unfinishedRuptures(end).Start - 1));
    if intensity > 0.45
        intensity = 'High';
    elseif intensity > 0.35
        intensity = 'Medium';
    else
        intensity = 'Low';
    end
    fprintf(fidR3, '\n%g,%g,%g,%s,%g,%g,%s,%g,...', unfinishedRuptures(end).Position, num, dueToConstriction, whichConstriction, unfinishedRuptures(end).Size, ~dueToConstriction, intensity, unfinishedRuptures(end).Start);
end