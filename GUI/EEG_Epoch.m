function [ALLEEG EEG CURRENTSET] = EEG_Epoch(ALLEEG, EEG, CURRENTSET,sub_ID, task,filename,EpochWindow)

for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);


EEG = pop_epoch( EEG, {'stim_onset'}, EpochWindow, 'newname', [EEG.setname(1:end-4) '_epoched'], 'epochinfo', 'yes'); %in seconds
EEG.comments = pop_comments(EEG.comments,'', 'epoched',1);

        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_epoched'],'gui','off'); 
end

fprintf('Inspect each dataset and rejet bad trials \n')
eeglab redraw