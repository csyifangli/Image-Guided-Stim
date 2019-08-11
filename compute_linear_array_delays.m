function [delays] = compute_linear_array_delays(element_position, focus, c)
    %Parameters in mm
    delays = sqrt((focus(1) - element_position(:,1)).^2 + focus(2)^2)/c;
    delays = (max(delays) - delays)';
    
   
end