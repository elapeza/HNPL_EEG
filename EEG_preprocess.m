function [ALLEEG, EEG, CURRENTSET] = EEG_preprocess(ALLEEG, EEG, CURRENTSET, filename,CoordinateTemplate)

%% location fix
for idx = 1:length(filename)
    EEG = ALLEEG(idx);
EEG.chanlocs = readlocs(CoordinateTemplate);
for i = 1:length(EEG.chanlocs)
    EEG.chanlocs(i).theta = EEG.chanlocs(i).theta + 90;
    EEG.chanlocs(i).sph_theta = EEG.chanlocs(i).sph_theta + 90;
end
% Recompute Cartesian coordinates from the corrected spherical ones
EEG = eeg_checkset(EEG);
%adjust head size for topoplot
EEG.saved = 'no';
EEG.chaninfo.topoplot = { 'headrad' 0.68 };
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG); % save data in ALLEEG'
end
%% remove noneeg channels
%EEG = eeg_checkset(EEG);
%eeglab redraw;

for idx = 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(idx);

 if length(EEG.chanlocs)>65
EEG = eeg_checkset( EEG );
EEG = pop_select( EEG, 'nochannel',{'VEOG','HEOG'});
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off'); 
 end 



% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[char(sub_ID) '_SEPs_merged_filtered_downsampled_eeg_ch_only'],'gui','off'); 

end

%% clean raw data

for idx = 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(idx);

EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.8,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian');
EEG = eeg_checkset(EEG);
%eeglab redraw;

EEG.comments = pop_comments(EEG.comments,'', 'rawclean',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'setname',[EEG.setname(1:end-4) '_rawclean'],'gui','off'); 
end

%% Interpolate
% Determine the total number of datasets in ALLEEG
numDatasets = length(ALLEEG);

% Initialize index
index = -1;

% Find the last dataset with exactly 64 channels
for idx = 1:numDatasets
    if length(ALLEEG(idx).chanlocs) == 64
        index = idx;  % Update index to the current dataset with 62 channels
    end
end


for i = 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);

% Check if a suitable index was found and if the current EEG dataset has fewer than 62 channels
if index ~= -1 && length(EEG.chanlocs) < 64
    % Perform the interpolation only if there are fewer than 62 channels
    EEG = pop_interp(EEG, ALLEEG(index).chanlocs, 'spherical');

    % Validate the EEG dataset
    EEG = eeg_checkset(EEG);
    
    % Redraw the EEGLAB GUI
    %eeglab redraw;

    % Add the updated dataset to ALLEEG
   % [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, numDatasets + 1, 'gui', 'off');
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'gui', 'off');

else
    % Optional: Handle the case where no dataset with exactly 64 channels was found
    frpintf('No dataset with exactly 64 channels found. n\');
end
end

%% average reference using GUI:

for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);
EEG = fullRankAveRef(EEG);
end
%% run zapline plus
for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);

 EEG = pop_zapline_plus(EEG, 'noisefreqs','line','coarseFreqDetectPowerDiff',7,'chunkLength',0,'adaptiveNremove',1,'fixedNremove',1);
 EEG = eeg_checkset(EEG);
 %eeglab redraw;

 EEG.comments = pop_comments(EEG.comments,'', 'zapline',1);

 [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_zapline'],'gui','off'); 

end

%% Save before AMICA
  %before running amica
  for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);
    EEG.comments = pop_comments(EEG.comments,'', 'preamica',1);

    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_preamica'],'gui','off');
  end
  fprintf('Pre-ICA processing completed. \nPlease Proceed to next portion of code of when ready to run ICA \n')
  beep




