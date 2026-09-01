function [ALLEEG EEG CURRENTSET] = EEG_PostICA(ALLEEG, EEG, CURRENTSET,sub_ID, task,filename,EpochWindow)


%% Remove components
EEG = pop_subcomp( EEG, [], 0);
EEG.comments = pop_comments(EEG.comments,'', 'postcomponentremoval',1);

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 2,'gui','off'); 

%after removing components
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[sub_ID '_' task '_postcomponentremove'],'gui','off'); 

%% place IC components on individual files

for i = length(ALLEEG)-length(filename)-4:length(ALLEEG)-5
    ALLEEG(i).icaweights  = EEG.icaweights;
    ALLEEG(i).icasphere   = EEG.icasphere;
    ALLEEG(i).icawinv     = EEG.icawinv;
    ALLEEG(i).icachansind = EEG.icachansind;
    ALLEEG(i) = eeg_checkset(ALLEEG(i), 'ica');
end

for i =length(ALLEEG)-length(filename)-4:length(ALLEEG)-5
        EEG = ALLEEG(i);
        EEG.comments = pop_comments(EEG.comments,'', 'Postamica_loaded',1);
        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_ICA'],'gui','off'); 

end
%% Rereferance the Datasets post ICA and inspection
for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);
    EEG = pop_reref( EEG, [], 'huber', 25, 'interpchan',[], 'refica', 'remove');
    EEG.comments = pop_comments(EEG.comments,'', 'postICA_rereferance',1);

end

%% extract epochs, but do not remove epoch baseline

% for i=1:length(EEG.event)
%     if ~isnan(EEG.event(i).duration)
%         EEG.event(i).type = "stimPeriod";
%     end
% end
%%
for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);


EEG = pop_epoch( EEG, {'stim_onset'}, EpochWindow, 'newname', [EEG.setname(1:end-4) '_epoched'], 'epochinfo', 'yes'); %in seconds
EEG.comments = pop_comments(EEG.comments,'', 'epoched',1);

        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_epoched'],'gui','off'); 
end

fprintf('Inspect each dataset and rejet bad trials \n')
eeglab redraw
beep
return