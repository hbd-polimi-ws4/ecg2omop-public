function dat = translateDate(dat)
% 
% dat = translateDate(dat)
%  
%   Support function. Given a "dat" string (a datetime string formatted as
%   "dd-mmm-yyyy", possibly with the addition of hours, minutes, and
%   seconds at the end), it translates months' spelling from a foreign
%   language into English. Strings that do not match any of the switch
%   cases are returned unchanged, after being checked for the presence of
%   any accepted month string (i.e., every possible English one). If
%   an unacceptable string is found, an error is thrown.
%   This function is required when executing Matlab on systems
%   that are not using English as a primary language, as the "dir" function
%   (or the header file) may provide a record creation date spelled in the
%   local language, requiring standardization into English.
%   
% Contributors:
%   Pierluigi Reali, 2024-2026
%   Alessandro Carotenuto, 2024
%
% Affiliation:
%   Department of Electronics Information and Bioengineering, Politecnico di Milano
%

engMonths = {'jan','feb','mar','apr','may','jun','jul','aug','sep','oct',...
             'nov','dec'};

switch dat(4:6)
    case 'gen'
        dat(4:6) = 'jan';
    case 'mag'
        dat(4:6) = 'may';
    case 'giu'
        dat(4:6) = 'jun';
    case 'lug'
        dat(4:6) = 'jul';
    case 'set'
        dat(4:6) = 'sep';
    case 'ott'
        dat(4:6) = 'oct';
    case 'dic'
        dat(4:6) = 'dec';
    otherwise
        if ~matches(dat(4:6),engMonths)
            error('translateDate:outMonthChk',['The record start (or end) date ' ...
                  'is provided in a language other than English. Please add the ' ...
                  'translation needed in your case to the switch statement to ' ...
                  'translateDate.m']);
        end
end
end