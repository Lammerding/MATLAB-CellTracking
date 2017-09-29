if c ~= 0
    %use location data to determine constriction passage
    for i = 1:length(activeCells)
        %top of cell below bottom of constriction 1
        if activeCells(i).BoundingBox((p + channels - 1) / channels, 2) > loc(s, 1)
            activeCells(i).Constriction((p + channels - 1) / channels) = 0.2;
        %bottom of cell below top of constriction 1
        elseif activeCells(i).BoundingBox((p + channels - 1) / channels, 2) + activeCells(i).BoundingBox((p + channels - 1) / channels, 4) > loc(s, 2)
            activeCells(i).Constriction((p + channels - 1) / channels) = 1;
        %top of cell below bottom of constriction 2
        elseif activeCells(i).BoundingBox((p + channels - 1) / channels, 2) > loc(s, 3)
            activeCells(i).Constriction((p + channels - 1) / channels) = 1.2;
        %bottom of cell below top of constriction 2
        elseif activeCells(i).BoundingBox((p + channels - 1) / channels, 2) + activeCells(i).BoundingBox((p + channels - 1) / channels, 4) > loc(s, 4)
            activeCells(i).Constriction((p + channels - 1) / channels) = 2;
        %top of cell below bottom of constriction 3
        elseif activeCells(i).BoundingBox((p + channels - 1) / channels, 2) > loc(s, 5)
            activeCells(i).Constriction((p + channels - 1) / channels) = 2.2;
        %bottom of cell below top of constriction 3
        elseif activeCells(i).BoundingBox((p + channels - 1) / channels, 2) + activeCells(i).BoundingBox((p + channels - 1) / channels, 4) > loc(s, 6)
            activeCells(i).Constriction((p + channels - 1) / channels) = 3;
        %bottom of cell above top of constriction 3
        else
            activeCells(i).Constriction((p + channels - 1) / channels) = 3.2;
        end
    end
end