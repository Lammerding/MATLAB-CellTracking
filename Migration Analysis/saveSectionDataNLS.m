num = 0;
flag1a = true;
flag1b = true;
flag1c = true;
flag1d = true;

%write data to the file
for i = 1:length(finishedCells)        
    if finishedCells(i).Parent == 0;
        interpretCellDataNLS

        saveCellDataNLS

        if finishedCells(i).Divided
            j = i;
            for i = 1:length(finishedCells)
                if finishedCells(i).Parent == j
                    interpretCellDataNLS

                    saveCellDataNLS
                end
            end
        end
    end
end