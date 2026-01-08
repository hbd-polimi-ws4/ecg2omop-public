function [N_samples, str_accepted_leads, num_accepted_leads] = LEADextraction(recordName)
% Ottieni le informazioni sul record utilizzando la libreria WFDB
[ siginfo,~,~ ] = wfdbdesc(recordName);
N_samples = siginfo.LengthSamples;

% Elenco di sinonimi per i lead ECG da PhysioNet
ECG_synonyms = ["No signal", "No Signal", "no signal","Abdomen_1", "Abdomen_2", ...
    "Abdomen_3", "Abdomen_4", "A-I", "A-S", "avf", "aVF", "AVF+", "avl", "aVL", ...
    "AVL", "avr", "AVR", "CC5", "chan 1", "chan 2", "chan 3", "CM2", "CM4", "CM5", ...
    "CS12", "CS34", "CS56", "CS78", "CS90", "D3", "D4", "ECG0", "ECG 1", "ECG1", ...
    "ECG 2", "ECG 3", "ECG AVF", "ECG", "ECG [ECG1]", "ECG F", "ECG I", "ECG II", ...
    "ECG III", "ECG lead 1", "ECG lead 2", "ECG lead 3", "ECG Lead AVF", ...
    "ECG lead AVL", "ECG lead I", "ECG Lead I", "ECG lead II", "ECG Lead II", ...
    "ECG lead III", "ECG Lead III", "ECG Lead V3", "ECG Lead V4", "ECG lead V5", ...
    "ECG Lead V5", "ECG lead V6", "ECG lead V", "ECG Lead V", "ECG signal 0", ...
    "ECG signal 1", "ECG V3", "ECG V3", "ECG V Lead", "E-S", "i", "I", "I+", ...
    "ii", "II", "II+", "iii", "III", "III+", "lead I", "lead II", "lead V", ...
    "MCL1", "MCL1+", "ML2", "ML5", "MLI", "MLII", "MLIII", "mod.V1", "MV2", ...
    "MV2", "ST1", "ST2", "ST3", "ST_I", "ST_II", "v1", "V1", "V1-V2", "v2", ...
    "V2", "V2-V3", "v3", "V3", "v4", "V4", "V4-V5", "v5", "V5", "v6", "V6", ...
    "V", "V+", "vx", "vy", "vz"];

% Regex per un ulteriore controllo
pattern = '^(ecg\s*-?\s*lead\s*-?)?(i|ii|iii|avr|avf|avl|v1|v2|v3|v4|v5|v6)(ecg\s*-?\s*lead\s*-?)?$';

% Estrai i nomi delle derivazioni dal recordInfo
numChannels = width(siginfo);
leads = cell(numChannels,2);
for i = 1:numChannels
    lead_name = siginfo(1,i).Description;
    isMatch = regexpi(lead_name, pattern, 'once');
    lead_chan = i;
    if matches(lead_name, ECG_synonyms) || ~isempty(isMatch)
        % salvo nella prima colonna di leads il nome del lead accettato
        leads{i, 1} = renameLead(lead_name);
        % salvo nella seconda colonna di leads il numero del canale del lead accettato
        leads{i, 2} = lead_chan;
    end
end

% Inizializzazione stringhe
str_accepted_leads = string();
num_accepted_leads = string();

% Scansiona il cell array originale
for i = 1:length(leads)
    % Verifica se la cella contiene "Discard" o è vuota
    if ~strcmp(leads{i,1}, "Discard") && ~isempty(leads{i,1})
        % Aggiungi la cella al nuovo cell array
        str_accepted_leads(i, 1) =  leads{i, 1};
        num_accepted_leads(i, 1) = leads{i, 2};
    end
end
end

function [new_lead_name] = renameLead(lead_name)
% Possibili sinonimi
Lead_aVF = ["avf", "aVF", "AVF+", "ECG AVF", "AVF", "ECG Lead AVF"];

Lead_aVR = ["avr", "AVR","aVR", "ECG AVR", "ECG Lead AVR"];

Lead_aVL = ["avl", "aVL", "AVL", "ECG lead AVL", "ECG AVL"];

Lead_I   = ["ecg leadI", "Ecg LeadI", "ECG leadI", "ECG LeadI", "ECG lead 1", ...
    "ECG I", "ECG lead I", "ECG Lead I", "i", "I", "I+","lead I", "MCL1", "MLI"];

Lead_II  = ["ecg leadII", "Ecg LeadII", "ECG leadII", "ECG LeadII", "II", "II+", ...
    "ii", "ECG lead 2", "ECG II", "ECG lead II", "ECG Lead II", "MLII", "MV2", ...
    "MV2", "ML2", "lead II"];

Lead_III = ["ecg leadIII", "Ecg LeadIII", "ECG leadIII", "ECG LeadIII", ...
    "ECG lead 3","iii", "III", "III+", "ECG III", "ECG lead III", "MLIII", ...
    "ECG Lead III"];

Lead_V1  = ["v1", "V1"];

Lead_V2  = ["v2", "V2", ];

Lead_V3  = ["v3", "V3", "ECG V3",  "ECG Lead V3"];

Lead_V4  = ["v4", "V4", "ECG Lead V4"];

Lead_V5  = ["v5", "V5", "ECG lead V5", "ECG Lead V5"];

Lead_V6  = ["v6", "V6","ECG lead V6"];

Discard  = ["No signal", "No Signal", "no signal","Abdomen_1", "Abdomen_2", ...
    "Abdomen_3", "Abdomen_4", "A-I", "A-S","CC5", "chan 1", "chan 2", "chan 3", ...
    "CM2", "CM4", "CM5", "CS12", "CS34", "CS56", "CS78", "CS90", "D3", "D4", ...
    "ECG0", "ECG 1", "ECG1", "ECG 2", "ECG 3","ECG", "ECG [ECG1]", "ECG F", ...
    "ECG lead 1", "ECG lead 2", "ECG lead 3", "ECG lead V", "ECG Lead V", ...
    "ECG signal 0", "ECG signal 1", "ECG V Lead", "E-S", "lead V", ...
    "ST1", "ST2", "ST3", "ST_I", "ST_II",  "V1-V2", "V2-V3", "V4-V5", "V", ...
    "MCL1+", "ML5", "mod.V1", "V+", "vx", "vy", "vz"];

if matches(lead_name, Lead_I)
    new_lead_name = "Lead_I";
elseif matches(lead_name, Lead_II)
    new_lead_name = "Lead_II";
elseif matches(lead_name, Lead_III)
    new_lead_name = "Lead_III";
elseif matches(lead_name, Lead_aVF)
    new_lead_name = "Lead_aVF";
elseif matches(lead_name, Lead_aVR)
    new_lead_name = "Lead_aVR";
elseif matches(lead_name, Lead_aVL)
    new_lead_name = "Lead_aVL";
elseif matches(lead_name, Lead_V1)
    new_lead_name = "Lead_V1";
elseif matches(lead_name, Lead_V2)
    new_lead_name = "Lead_V2";
elseif matches(lead_name, Lead_V3)
    new_lead_name = "Lead_V3";
elseif matches(lead_name, Lead_V4)
    new_lead_name = "Lead_V4";
elseif matches(lead_name, Lead_V5)
    new_lead_name = "Lead_V5";
elseif matches(lead_name, Lead_V6)
    new_lead_name = "Lead_V6";
elseif matches(lead_name, Discard)
    new_lead_name = "Discard";
else
    new_lead_name = lead_name;
end
end
