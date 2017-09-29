%% print transit time data to .csv file
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
            fprintf(fidS, '%g,%g,%g,%g,%g,', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
            break
        end
    end
    %% print rest of constrictions
    for j = (j + 1):length(constriction)
        if constriction(j).Success == 1
            fprintf(fidS, '\n,,,,,,,,,%g,%g,%g,%g,%g', constriction(j).Number, constriction(j).Enter, constriction(j).Leave, constriction(j).Duration, constriction(j).Success);
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