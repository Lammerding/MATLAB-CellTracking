%deal with rupture
for i = 1:length(activeCells)
   ratio1 = activeCells(i).RedIntensity(p) / activeCells(i).GreenIntensity(p);
   activeCells(i).Ratio(p) = ratio1;
   
   if frameRate >= 5
       if activeCells(i).TimeAppearing ~= p && ((activeCells(i).BoundingBox(p, 2) > loc(s, 6) - 3.7 * l && activeCells(i).BoundingBox(p, 2) + activeCells(i).BoundingBox(p, 4) < loc(s, 1) + 3.2 * l) || activeCells(i).Rupture(p - 1) || c == 0)
           ratio2 = activeCells(i).Ratio(p - 1);
           if p > activeCells(i).TimeAppearing + 3 && all((activeCells(i).Ratio((p - 3):(p - 2)) - activeCells(i).Ratio((p - 4):(p - 3))) ./ activeCells(i).Ratio((p - 4):(p - 3)) > 0.05) && any((activeCells(i).Ratio((p - 3):(p - 2)) - activeCells(i).Ratio((p - 4):(p - 3))) ./ activeCells(i).Ratio((p - 4):(p - 3)) > 0.15)
               activeCells(i).Rupture(p - 3) = 1;
               activeCells(i).Rupture((p - 2):p) = 0.5;
           elseif (ratio1 - ratio2) / ratio2 > 0.25
               activeCells(i).Rupture(p) = 1;
               if p > 2 && activeCells(i).Alive(p - 2) && (ratio2 - activeCells(i).Ratio(p - 2)) / activeCells(i).Ratio(p - 2) > 0.2
                   activeCells(i).Rupture(p - 1) = 1;
                   activeCells(i).Rupture(p) = 0.5;
               end
           elseif activeCells(i).Rupture(p - 1) == 1
               if (ratio1 - ratio2) / ratio2 > 0.05 || (max(activeCells(i).Ratio((find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last') + 1):(p - 1))) - ratio1) < (ratio1 - activeCells(i).Ratio(find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last')))
                   activeCells(i).Rupture(p) = 1;
               elseif (ratio2 - ratio1) / ratio1 > 0.05
                   activeCells(i).Rupture(p) = 0.5;
               else
                   activeCells(i).Rupture(p) = 1;
               end
           elseif activeCells(i).Rupture(p - 1) == 0.5
               if (ratio1 - ratio2) / ratio2 > 0.05
                   activeCells(i).Rupture(p) = 1;
               elseif (ratio2 - ratio1) / ratio1 > 0.03
                   activeCells(i).Rupture(p) = 0.5;
               else
                   activeCells(i).Rupture(p) = 0.25;
               end
           elseif activeCells(i).Rupture(p - 1) == 0.25
               if (ratio1 - ratio2) / ratio2 > 0.05
                   activeCells(i).Rupture(p) = 1;
               elseif (ratio2 - ratio1) / ratio1 > 0.05
                   activeCells(i).Rupture(p) = 0.5;
               elseif (ratio2 - ratio1) / ratio1 > 0.03
                   activeCells(i).Rupture(p) = 0.25;
               else
                   activeCells(i).Rupture(p) = 0.1;
               end
           elseif activeCells(i).Rupture(p) == 0.1
               if (ratio1 - ratio2) / ratio2 > 0.05
                   activeCells(i).Rupture(p) = 1;
               elseif (ratio2 - ratio1) / ratio1 > 0.05
                   activeCells(i).Rupture(p) = 0.5;
               elseif (ratio2 - ratio1) / ratio1 > 0.03
                   activeCells(i).Rupture(p) = 0.25;
               else
                   activeCells(i).Rupture(p - 1) = 0;
               end
    %        elseif activeCells(i).Rupture(p - 1) == 0 && (p - 3) > activeCells(i).TimeAppearing
    %            if (ratio2 - ratio1) / ratio1 > 0.075 && any((activeCells(i).Ratio((p-2):(p-1)) - activeCells(i).Ratio((p-3):(p-2))) ./ activeCells(i).Ratio((p-3):(p-2)) > 0.135)
    %                activeCells(i).Rupture((p - 3 + find((activeCells(i).Ratio((p-2):(p-1)) - activeCells(i).Ratio((p-3):(p-2))) ./ activeCells(i).Ratio((p-3):(p-2)) > 0.075, 1)):(p-1)) = 1;
    %                activeCells(i).Rupture(p) = 0.5;
    %            end
           end
       end
   else
       if p > activeCells(i).TimeAppearing + 3 && activeCells(i).Centroid(p, 2) > loc(s, 6) - 3.7 * l && activeCells(i).Centroid(p, 2) < loc(s, 1) + 3.2 * l
           if (all((activeCells(i).Ratio((p - 3):(p - 2)) - activeCells(i).Ratio((p - 4):(p - 3))) ./ activeCells(i).Ratio((p - 4):(p - 3)) > 0.05) && mean((activeCells(i).Ratio((p - 1):p) - activeCells(i).Ratio((p - 2):(p - 1))) ./ activeCells(i).Ratio((p - 2):(p - 1))) > 0.005) || all((activeCells(i).Ratio((p - 3):(p - 2)) - activeCells(i).Ratio((p - 4):(p - 3))) ./ activeCells(i).Ratio((p - 4):(p - 3)) > 0.15)
               activeCells(i).Rupture(p - 3) = 1;
               activeCells(i).Rupture((p - 2):p) = 0.5;
           elseif p > activeCells(i).TimeAppearing + 5 && all((activeCells(i).Ratio((p - 5):p) - activeCells(i).Ratio((p - 6):(p - 1))) ./ activeCells(i).Ratio((p - 6):(p - 1)) > 0) && sum((activeCells(i).Ratio((p - 5):p) - activeCells(i).Ratio((p - 6):(p - 1))) ./ activeCells(i).Ratio((p - 6):(p - 1)) > 0.025) > 4
               activeCells(i).Rupture(p - 5) = 1;
               activeCells(i).Rupture((p - 4):p) = 0.5;
           elseif activeCells(i).Rupture(p - 1) > 0 && (mean(abs((activeCells(i).Ratio((p - 4):(p - 1)) - activeCells(i).Ratio((p - 3):p)) ./ activeCells(i).Ratio((p - 3):p))) > 0.01 || (max(activeCells(i).Ratio((find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last') + 1):(p - 1))) - ratio1) < (ratio1 - activeCells(i).Ratio(find(activeCells(i).Rupture(1:(p - 1)) == 0, 1, 'last'))))
               activeCells(i).Rupture(p) = 0.5;
           end
       end
   end
end