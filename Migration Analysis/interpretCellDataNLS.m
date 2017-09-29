constriction = struct('Enter', [], 'Number', [], 'Leave', [], 'Duration', [], 'Success', []);
rupture = struct('Start', [], 'End', [], 'Duration', []);

%% loop through all time points when cell was around to check for
%ruptures and constriction passages
stop = find(finishedCells(i).Alive, 1, 'last');
for p = (finishedCells(i).TimeAppearing + 1):stop
    %% check to see if rupture starts and make sure it ends before end of video
    if finishedCells(i).Rupture(p) > 0 && finishedCells(i).Rupture(p - 1) <= 0 && any(finishedCells(i).Rupture((p + 1):stop) <= 0)
        rupture(end + 1).Start = p - 1;
    %check to see if rupture ends
    elseif finishedCells(i).Rupture(p) <= 0 && finishedCells(i).Rupture(p - 1) > 0
        rupture(end).End = p;
        rupture(end).Duration = p - rupture(end).Start;
    end

    %% check to see if cell enters constriction and leaves it before end of video or dies in it
    if finishedCells(i).Constriction(p) > finishedCells(i).Constriction(p - 1) + 0.5 && (any(floor(finishedCells(i).Constriction(p)) ~= finishedCells(i).Constriction((p + 1):stop)) || (stop < timePoints && finishedCells(i).Rupture(stop - 1)))
        if finishedCells(i).Constriction(p) == finishedCells(i).Constriction(p - 1) + 1
            constriction(end).Leave = p;
            constriction(end).Duration = p - constriction(end).Enter;
            constriction(end).Success = 1;
        end
        constriction(end + 1).Enter = p;
        constriction(end).Number = floor(finishedCells(i).Constriction(p));
        if finishedCells(i).Constriction(p) ~= floor(finishedCells(i).Constriction(p))
           constriction(end).Leave = p;
           constriction(end).Duration = 0;
           constriction(end).Success = 1;
        end
    %check to see if cell leaves constriction
    elseif ~any(finishedCells(i).Constriction(p) == [1 2 3]) && finishedCells(i).Constriction(p) ~= finishedCells(i).Constriction(p - 1) && isempty(constriction(end).Leave) && length(constriction) > 1
        constriction(end).Leave = p;
        constriction(end).Duration = p - constriction(end).Enter;
        constriction(end).Success = finishedCells(i).Constriction(p) > finishedCells(i).Constriction(p - 1);
    end    
end
if stop < timePoints && stop > 1 && finishedCells(i).Rupture(stop - 1) && isempty(constriction(end).Leave)
    constriction(end).Leave = p;
    constriction(end).Duration = p - constriction(end).Enter;
    if finishedCells(i).Divided
        constriction(end).Success = 0.25;
    else
        constriction(end).Success = 0.5;
    end
end
for k = (length([constriction.Enter]) + 1):-1:2
   if constriction(k).Success == 0 && constriction(k).Duration <= 1
      constriction(k) = []; 
   end
end