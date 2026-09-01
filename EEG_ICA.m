function [ALLEEG, EEG, CURRENTSET] = EEG_ICA(ALLEEG, EEG, CURRENTSET, rawDataRoot, sub_ID, task, filename)


%% Run the Amica
%tic

% merge datasets into a single dataset so AMICA will handle it easily
mergedEEG = pop_mergeset(ALLEEG, 1+length(ALLEEG)-length(filename):numel(ALLEEG), 0);

% stim duration time (in s)
stimDuration = 0.5;
% Duplicate dataset for training
EEG_train = mergedEEG;

% Get latencies of stim periods in samples
stimEvents = find(strcmp({mergedEEG.event.type}, 'stim_onset'));
rmRanges = [];
for i = 1:length(stimEvents)
    startSamp = EEG_train.event(stimEvents(i)).latency;
    endSamp = startSamp + stimDuration * EEG_train.srate;
    rmRanges = [rmRanges; startSamp endSamp];
end

% Remove those samples from the copy
EEG_train = eeg_eegrej(EEG_train, rmRanges);

EEG = EEG_train;
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off','savenew',['Merged_train_set']);


    EEG = eeg_checkset(EEG);


%%

outdir = fullfile(rawDataRoot, sub_ID, task, 'amica_out');
%outdir = fullfile('C:\Users\lapez\OneDrive - Georgia Institute of Technology\datasets\JoshEEGECG\batch_attempt4', 'amica_out', sub_ID)
if ~exist(outdir, 'dir'); mkdir(outdir); end
cd(outdir)

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off','savenew',['Merged_train_set']);


%run AMICA
% [weights, sphere, mods] = runamica15(mergedEEG.data, ...
%     'outdir', outdir, ...
%     'num_models', 1, ...
%     'num_chans', mergedEEG.nbchan, ...
%     'max_iter', 2000);

%EEG_train.etc.amica  = mods;
%EEG_train.icaweights = weights;
%EEG_train.icasphere  = sphere;
%EEG_train = eeg_checkset(EEG_train, 'ica');


%EEG_train = pop_runamica(EEG_train);
EEG = pop_runamica(EEG, ...
    'outdir', outdir, ...   % explicit, short, non-synced output path
    'numprocs', 1, ...                % bypass MPI multi-process launch entirely
    'num_models', 1, ...
    'max_threads', 4);

% for i = length(ALLEEG)-length(filename)-1:length(ALLEEG)
%     ALLEEG(i).icaweights  = EEG.icaweights;
%     ALLEEG(i).icasphere   = EEG.icasphere;
%     ALLEEG(i).icawinv     = EEG.icawinv;
%     ALLEEG(i).icachansind = EEG.icachansind;
%     ALLEEG(i) = eeg_checkset(ALLEEG(i), 'ica');
% end
%toc
%% run amica, GUI %run amica in the GUI, dont need to change any default setting !!!
%after runnig amica % get to this step and then lets meet !!!
if exist('BrainVision')
for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[sub_ID '_' task '_postamica'],'gui','off'); 
end
end
%% label 
EEG = eeg_checkset(EEG, 'ica');
[ALLEEG,EEG,CURRENTSET] = processMARA(ALLEEG,EEG,CURRENTSET, [0,0, 1, 0, 0]);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

% EEG = pop_iclabel(EEG, 'default'); 
% [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
% 
% %% flag
% EEG = pop_icflag(EEG, [NaN NaN;0.2 1;0.2 1;0.2 1;0.2 1;0.2 1;0.2 1]);
% [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);

%% before removing components
EEG.comments = pop_comments(EEG.comments,'', 'precomponentremoval',1);

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[sub_ID '_' task '_precomponentremove'],'gui','off'); 

eeglab redraw
fprintf('Automated ICA Process Completed. Now manually Review components \nIn GUI, Tools -> Inspect/label Components by map \n')
beep
return