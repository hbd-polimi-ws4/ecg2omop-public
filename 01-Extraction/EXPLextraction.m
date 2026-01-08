function description = EXPLextraction(codes, n)
description = string();

physionetDict = containers.Map();
physionetDict('N') = 'Normal beat';
physionetDict('L') = 'Left bundle branch block beat';
physionetDict('R') = 'Right bundle branch block beat';
physionetDict('B') = 'Bundle branch block beat (unspecified)';
physionetDict('A') = 'Atrial premature beat';
physionetDict('a') = 'Aberrated atrial premature beat';
physionetDict('J') = 'Nodal (junctional) premature beat';
physionetDict('S') = 'Supraventricular premature or ectopic beat (atrial or nodal)';
physionetDict('V') = 'Premature ventricular contraction';
physionetDict('r') = 'R-on-T premature ventricular contraction';
physionetDict('F') = 'Fusion of ventricular and normal beat';
physionetDict('e') = 'Atrial escape beat';
physionetDict('j') = 'Nodal (junctional) escape beat';
physionetDict('n') = 'Supraventricular escape beat (atrial or nodal)';
physionetDict('E') = 'Ventricular escape beat';
physionetDict('/') = 'Paced beat';
physionetDict('f') = 'Fusion of paced and normal beat';
physionetDict('Q') = 'Unclassifiable beat';
physionetDict('?') = 'Beat not classified during learning';
physionetDict('[') = 'Start of ventricular flutter/fibrillation';
physionetDict('!') = 'Ventricular flutter wave';
physionetDict(']') = 'End of ventricular flutter/fibrillation';
physionetDict('x') = 'Non-conducted P-wave (blocked APC)';
physionetDict('(') = 'Waveform onset';
physionetDict(')') = 'Waveform end';
physionetDict('p') = 'Peak of P-wave';
physionetDict('t') = 'Peak of T-wave';
physionetDict('u') = 'Peak of U-wave';
physionetDict('`') = 'PQ junction';
physionetDict('''') = 'J-point';
physionetDict('^') = '(Non-captured) pacemaker artifact';
physionetDict('|') = 'Isolated QRS-like artifact';
physionetDict('~') = 'Change in signal quality';
physionetDict('+') = 'Rhythm change';
physionetDict('s') = 'ST segment change';
physionetDict('T') = 'T-wave change';
physionetDict('*') = 'Systole';
physionetDict('D') = 'Diastole';
physionetDict('=') = 'Measurement annotation';
physionetDict('"') = 'Comment annotation';
physionetDict('@') = 'Link to external data';

for i = 1:n
    if isKey(physionetDict, codes(i))
        description(i,1) = physionetDict(codes(i));
    else
        description(i,1) = 'NO EXPLANATION';
    end
end
end
