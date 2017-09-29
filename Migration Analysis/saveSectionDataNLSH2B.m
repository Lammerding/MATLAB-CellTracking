num = 0;
flag1a = true;
flag1b = true;
flag1c = true;
flag1d = true;
flagR = true;

%write data to the file
for i = 1:length(finishedCells)        
    if finishedCells(i).Parent == 0;
        interpretCellDataNLSH2B

        saveCellDataNLSH2B

        finishedCells(i).Analyzed = 1;
        
        if finishedCells(i).Divided
            j = i;
            for i = 1:length(finishedCells)
                if finishedCells(i).Parent == j
                    interpretCellDataNLSH2B

                    saveCellDataNLSH2B
                    
                    finishedCells(i).Analyzed = 1;
                end
            end
        end
    end
end
for i = 1:length(finishedCells)
    if isempty(finishedCells(i).Analyzed)
        interpretCellDataNLSH2B

        saveCellDataNLSH2B
    end
end
% %print position number and movie duration
% fprintf(fid, '\n%s,%g,%g', name, s, frameRate * timePoints);
% 
% if isempty(finishedCells) && ~isempty(message{1})
%     fprintf(fid, ',%s', message{1});
% else
%     num = 0;
%     header = false;
%     numC = 0;
%     headerC = false;
%     numR = 0;
%     headerR = false;
%     %write data to the file
%     for i = 1:length(finishedCells)
%         if finishedCells(i).Parent == 0;
%             interpretCellData
% 
%             saveCellData
% 
%             if finishedCells(i).Divided
%                 j = i;
%                 for i = 1:length(finishedCells)
%                     if finishedCells(i).Parent == j
%                         interpretCellData
% 
%                         saveCellData
%                     end
%                 end
%             end
%         end
%     end
%     if num == 0
%         fprintf(fid, ',No cells');
%     end
% end