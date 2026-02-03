function formatted_tms = TMSextraction(tms, n)
% 
% formatted_tms = TMSextraction(tms, n)
%  
%   Support function. Given "tms" (the time vector associated with signal
%   samples, in seconds, where ti=0) and "n" (the number of samples to be
%   saved in the extraction function that is calling this), return the
%   timestamps formatted as string.
%
%   Pierluigi: This should be replaced with built-in Matlab datetime
%              functions in a future version.
%   
% Contributors:
%   Alessandro Carotenuto, 2024
%   Pierluigi Reali, Ph.D., 2025
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano

formatted_tms = string();   
for i = 1:n
        % Estrai ore, minuti, secondi e millisecondi
        h = floor(tms(i) / 3600);
        m = floor((tms(i) - h * 3600) / 60);
        s = floor(tms(i) - h * 3600 - m * 60);
        ms = round((tms(i) - floor(tms(i))) * 1000);
    
        % Formatta la stringa nel formato "HH:MM:SS.sss"
        str = sprintf('%02d:%02d:%02d.%03d', h, m, s, ms);
        formatted_tms(i,1) = str;
end
end