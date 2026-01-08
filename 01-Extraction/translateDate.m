function dat = translateDate(dat)
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
end
end