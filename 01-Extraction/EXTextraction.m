function [ext, description, ext_bool] = EXTextraction()
% Inizializza variabile booleana di ricerca
ext_bool = false;
% Inizializza una variabile per le estensioni
ext = '';
% Inizializza una variabile per le descrizioni
description = '';

% Controlla se il file ANNOTATORS è presente nella directory
dir_info = dir(fullfile(pwd, '**', 'ANNOTATORS'));
if ~isempty(dir_info)
    % Setta il flag a true
    ext_bool = true;
    % Recupera le info sul folder del file
    filePath = dir_info.folder;
    % Apri il file di input in lettura
    fid = fopen([filePath, '/ANNOTATORS'], 'r');
    % Leggi il file riga per riga
    comments = fgetl(fid);
    % Estrai il tipo di estensione utilizzato
    comm = strsplit(strtrim(comments),'\t');
    ext = comm{1};
    % Estrai la descrizione dell'estensione utilizzata
    description = comm{2};
else
    disp('Nessuna estensione valida per le annotazioni riscontrata.')
end