function shift_img = ShiftImage(img, ux, uy, fill_value)
% Function to shift an image by ux and uy pixel increments 
% the shifted areas will be filled by zeros
% funcion shift_img = ShiftImage(img, ux, uy, fill_value)
%   img:        Height x Width x Sections image stack
%   ux:         shift image by ux pixels to the right
%   uy:         shift image by uy pixels down
%   fill_value: value to use to fill borders (e.g., 0)
%   best_focus: index of section with the best focus
% Jan Lammerding
% March 13, 2010

%shift_img = immultipy(img, 0);  % prepare shift image of same size and class
shift_img = circshift(img, [uy, ux]);    % shift matrix by uy, ux pixels
% since we conducted a circular shift, we now need to set some of the
% pixels to zero

if ux>0
    shift_img(:,1:ux,:) = fill_value;
elseif ux<0
    shift_img(:,(end+ux+1):end,:) = fill_value;
end


if uy>0
    shift_img(1:uy,:,:) = fill_value;
elseif uy<0
    shift_img((end+uy+1):end,:,:) = fill_value;
end


