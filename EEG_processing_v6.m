
%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% EDITING NOTES %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%
% 6/18 ECL: Beginning adaptation from NPRL code written by NB
%   Automatic expected directory functionality disabled due to final data
%   storage structure not being finalized.
%
% 6/25 ECL: progress update. Working with care.
%   code now works if you run line by line. currently editing
%   initialization to actually load the dataset instead of needing to do so
%   in the gui.
%
% 7/08 ECL: Adding functionality for events.
%
% 8/10 ECL: Batch Processing fully integrated. Backwards compatibility with
%   single file has also been confirmed. Remaining Issues exist with ECG
%   artifacts, though rereferencing does seem to help in many cases.
%
% 8/17 ECL: Automatic file selection implemented. Wavelet subtraction of
% ECG implemented and seems to work well. Occassional issues with event
% markers, so ECG is now filterest, which seems to help when reviewing a
% sample file. Still confirming VNS events


%EEG = eeg_regepochs(EEG, 'recurrence', 2, 'limits', [0 2], 'rmbase', NaN);

%% Initialization and File Selection

legacy_init = 0;
rawDataRoot = 'C:\Users\lapez\Documents\ShinoLab_local\Datasets';
stimDuration = 500; % in ms
stimFrequency = 30; % in Hz

if legacy_init == 1
samplefreq = (input('Enter Sampling Frequency (Default 2048 Hz) ','s'));
if samplefreq == ""
    samplefreq = 2048;
else
    samplefreq = str2double(samplefreq); % Convert to numeric value
end


sub_ID = input('Enter the subject ID: ', 's');  % you need to create a directory on the server or locally that fits this scheme: ..\Documents\MSTOP_Analysis\Subjects\Pilot01.sub\MSTOP !!!
if sub_ID == ""
    sub_ID = "Fnu_Lnu";
end
task = input('Enter the task name: ', 's'); % change to your task name, whatever you name the folder within subject directory !!!
if task == ""
    task = "sample_task";
end

file_dir_select = input(['Select File & Directory Technique', '\n1 = automatic directory', '\n2 = manual selection', '\n'],"s");

sub_ID = char(sub_ID);
task = char(task);
end

if legacy_init == 0
    prompt    = {"Sample Frequency (Hz)", "Subject ID", "Task Name", "Session #", "Epoch Window" ,"File Selection Method (1 automatic; 2 Manual)", "Pause Before ICA? (1 pause; 0 no pause)"};
    dlgtitle  = "Initial Data Entry";
    fieldsize = [1 45; 1 45; 1 45; 1 45; 1 45; 1 45; 1 45];
    definput  = {'2048','','','1','-2 8','2', '0'};
    answer    = inputdlg(prompt, dlgtitle, fieldsize, definput);


    % Process the user input from the dialog
    samplefreq      = str2double(answer{1});
    sub_ID          = char(answer{2});
    task            = char(answer{3});
    sessionNum      = str2double(answer{4});
    EpochWindow     = str2num(answer{5});
    file_dir_select = str2double(answer{6});
    PreAMICA_pause  = str2double(answer{7});
    date_analyzed   = datetime('now');
    analyzer        = getenv("USERNAME");
    
    metaData = struct("SampleFrequency",samplefreq,"SubjectID",sub_ID,'TaskName',task,'SessionNumber',sessionNum,'EpochWindow',EpochWindow,'ProcessingDate',date_analyzed,'Preprocessor',analyzer);
end

ProcessingDir = matlab.desktop.editor.getActiveFilename;
    [InstallFolder,fileVersion,~] = fileparts(ProcessingDir);
    CoordinateTemplate = fullfile(InstallFolder, 'SpesMedica_OTB64_from1005.ced');
if ~isfile(CoordinateTemplate)
    CoordinateTemplate = 'C:\Users\lapez\OneDrive - Georgia Institute of Technology\ShinoLab Backup\EEGCap_coordinates (1)\SpesMedica_OTB64_from1005.ced';
end




%Set the correct directory explicitly
if file_dir_select == 1 %Once data structure gets finalized, edit section to work correctly
    % NOT IMPLEMENTED, DO NOT USE
    %disp("Functionality not implemented. Please use manual selection.")
    %return
    
    filename = ls('*mat');

    filepath = pwd;

    if isempty(filename)
        expected_dir = fullfile(rawDataRoot, [sub_ID '.sub'], task); % change to match the directory you set up !!!
        if ~exist(expected_dir, 'dir')
        error('Directory does not exist: %s', expected_dir);
        end
        cd(expected_dir);
    end
    filename = string(filename);

elseif file_dir_select == 2
    [filename, filepath] = uigetfile('*.mat', 'MultiSelect','on');
    filename = string(filename);
    if isequal(filename,0)
        fprintf('User selected Cancel \n');
        return
    end

else
    error('Directory Selection Not Executed. Rerun and enter either "1" or "2"')
end


metaData.batchFiles = filename;


clearvars legacy_init prompt dlgtitle fieldsize definput answer date_analyzed analyzer file_dir_select InstallFolder
%% Load Raw Data Files and build structures from .mat file

[ALLEEG, EEG, CURRENTSET] = eeglab;


for idx = 1:length(string(filename))

    expected_dir = fullfile(filepath,filename(idx));
    fprintf('User selected %s\n', expected_dir);
    cd(filepath);
    eegfiles = dir('*.mat');
    load(string(filename(idx)));
    %raw_eeg = signal.eegdata;

    %[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

    EEG = eeg_emptyset();
    EEG.data      = signal.eegdata;          % [64 x samples] EEG channels
    EEG.nbchan    = size(signal.eegdata, 1); % 64 electrodes
    EEG.pnts      = size(signal.eegdata, 2); % number of time points
    EEG.srate     = signal.fsamp;            % sampling rate
    EEG.times     = signal.time * 1000;      % convert to ms if signal.time is in seconds
    EEG.trials    = 1;                       % continuous data = 1 trial
    EEG.xmin      = EEG.times(1) / 1000;
    EEG.xmax      = EEG.times(end) / 1000;
    EEG.subject   = sub_ID;                  % Subject ID
    EEG.session   = sessionNum;              % session number
    EEG.run       = idx;                     % Number of Recording in Session (prevent overwriting previous blocks of same condition)
    EEG.group     = task;                    % Task




    %Import events from auxiliary channel 3
    StimAuxChannel = signal.auxiliary(3,:);
    ShamAuxChannel = signal.auxiliary(4,:);

    StimThreshold  = 2000; %  between baseline (~0mV) and 3000mV
    NSThreshold    = 400;  %  lower TTL threshold for stim AND sham. absolute is 500 mV

    % Timepoints s.t. stim/sham is active
    StimAbove      = StimAuxChannel > StimThreshold; 
    ShamAbove      = ShamAuxChannel > StimThreshold;
    StimAbove_NS   = StimAuxChannel > NSThreshold & StimAuxChannel < StimThreshold;
    ShamAbove_NS   = ShamAuxChannel > NSThreshold & ShamAuxChannel < StimThreshold;

    % Rising edges = stimulation onset
    StimOnsets     = find(diff([0, StimAbove]) == 1);
    ShamOnsets     = find(diff([0, ShamAbove]) == 1);
    NSOnsets       = find(diff([0, ShamAbove_NS & StimAbove_NS]) == 1);

    % Falling edges = stimulation offset
    StimOffsets    = find(diff([StimAbove, 0]) == -1);
    ShamOffsets    = find(diff([ShamAbove, 0]) == -1);
    NSOffsets      = find(diff([0, ShamAbove_NS & StimAbove_NS]) == -1);

    % Remove events types where average stimulation event duration
    % (including sham and no stim) differ by more than 10% 
    stimDuration_samples = stimDuration/1000*samplefreq;
    if mean(StimOffsets - StimOnsets) < stimDuration_samples * 0.9 || mean(StimOffsets - StimOnsets) > stimDuration_samples * 1.1
        warning(['Stim events removed due to calculated average stim duration (' num2str(mean(timOffsets - StimOnsets)/samplefreq) 's) not being w/in 10% of expected duration (' num2str(stimDuration_samples/samplefreq) 's)'])
        StimOnsets = [];
        StimOffsets = [];
    end
    if mean(ShamOffsets - ShamOnsets) < stimDuration_samples * 0.9 || mean(ShamOffsets - ShamOnsets) > stimDuration_samples * 1.1
        warning(['Sham events removed due to calculated average stim duration (' num2str(mean(ShamOffsets - ShamOnsets)/samplefreq) 's) not being w/in 10% of expected duration (' num2str(stimDuration_samples/samplefreq) 's)'])
        ShamOnsets = [];
        ShamOffsets = [];
    end
     if mean(NSOffsets - NSOnsets) < stimDuration_samples * 0.9 || mean(NSOffsets - NSOnsets) > stimDuration_samples * 1.1
         warning(['Control/No Stim events removed due to calculated average stim duration (' num2str(mean(NSOffsets - NSOnsets)/samplefreq) 's) not being w/in 10% of expected duration (' num2str(stimDuration_samples/samplefreq) 's)'])
         NSOnsets = [];
        NSOffsets = [];
     end
     if isempty(StimOnsets) & isempty(StimOffsets) & isempty(ShamOnsets) & isempty(ShamOffsets) & isempty(NSOnsets) & isempty(NSOffsets)
         error('Stimulation Period Events Detected. This includes No Stim events')
     end

    % Detect cases where # of onsets ~= # of offsets
    if length(StimOffsets) ~= length(StimOnsets)
        warning(['Potential Event Corruption for ' char(filename(idx)) ', please confirm Stim channel'])   
    end
    if length(ShamOffsets) ~= length(ShamOnsets)
        warning(['Potential Event Corruption for ' char(filename(idx)) ', please confirm Sham channel'])   
    end
    if length(NSOffsets) ~= length(NSOnsets)
        warning(['Potential Event Corruption for ' char(filename(idx)) ', please confirm both Stim and Sham channels'])  
    end


    if ~isempty(StimOnsets) % for Stim Conditions
        % Build event structure - onsets
        for i = 1:length(StimOnsets)
            EEG.event(end+1).type = 'stim_onset';
            EEG.event(end).latency = StimOnsets(i);
            EEG.event(end).duration = round(0.5 * EEG.srate); % 500ms in samples
        end

        % Build event structure - offsets
        for i = 1:length(StimOffsets)
            EEG.event(end+1).type = 'stim_offset';
            EEG.event(end).latency = StimOffsets(i);
            EEG.event(end).duration = 0; % instantaneous marker
        end
        EEG.comments = pop_comments(EEG.comments,'', 'Stim_Condition',1);
        EEG.condition = 'Stim';

    end


    if ~isempty(ShamOnsets) %for Sham Conditions
        % Build event structure - onsets
        for i = 1:length(ShamOnsets)
            EEG.event(end+1).type = 'stim_onset';
            EEG.event(end).latency = ShamOnsets(i);
            EEG.event(end).duration = round(0.5 * EEG.srate); % 500ms in samples
        end

        % Build event structure - offsets
        for i = 1:length(ShamOffsets)
            EEG.event(end+1).type = 'stim_offset';
            EEG.event(end).latency = ShamOffsets(i);
            EEG.event(end).duration = 0; % instantaneous marker
        end
        EEG.comments = pop_comments(EEG.comments,'', 'Sham_Condition',1);
        EEG.condition = 'Sham';

    end


    if ~isempty(NSOnsets) % for non-stim conditions
        % Build event structure - onsets
        for i = 1:length(NSOnsets)
            EEG.event(end+1).type = 'stim_onset';
            EEG.event(end).latency = NSOnsets(i);
            EEG.event(end).duration = round(0.5 * EEG.srate); % 500ms in samples
        end

        % Build event structure - offsets
        for i = 1:length(NSOffsets)
            EEG.event(end+1).type = 'stim_offset';
            EEG.event(end).latency = NSOffsets(i);
            EEG.event(end).duration = 0; % instantaneous marker
        end
        EEG.comments = pop_comments(EEG.comments,'', 'NS_Condition',1);
        EEG.condition = 'Control';

    end


    EEG = eeg_checkset(EEG);




    % Remove epoch baseline
    EEG = pop_rmbase(EEG, [],[]);

    % High-pass filter
    cutoff_freq = 0.5;
    EEG = pop_eegfiltnew(EEG, [], cutoff_freq+0.5, 16500, true, [], 0);

    % Notch filter stimulation
    %stim_freq = 30; %Hz

    % ECG Targeted Removal
    % Detect QRS complexes from your ECG channel and remove ECG channel
    EEG.data(65,:) = signal.auxiliary(1,:);  % Temporarily load ECG data
    butterFilt = designfilt("bandpassiir",FilterOrder=2,HalfPowerFrequency1=0.5,HalfPowerFrequency2=45,SampleRate=samplefreq);
    EEG.data(65,:) = filtfilt(butterFilt, EEG.data(65,:));

    EEG = pop_fmrib_qrsdetect(EEG, 65, 'qrs', 'yes');




    % Downsample
    EEG = pop_resample(EEG, 500);

    % Remove cardiac artifact using Optimal Basis Set method, referencing the QRS events
    EEG = pop_fmrib_pas(EEG, 'qrs', 'obs', 3); % 3 = number of PCs in the OBS model, tune 3-5

    % Save new dataset
    temp_filename = char(filename(idx));
    EEG.comments = pop_comments(EEG.comments,'', {'base_removed' 'filtered' 'QRS subtracted'},1);

    output_filename = [temp_filename(1:end-9) '_base_rm_filtered.set'];
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', output_filename, 'savenew', output_filename, 'gui', 'off');

    fprintf('Saved processed file: %s\n', output_filename);
end




eeglab redraw
clearvars cutoff_freq i idx NSOffsets NSOnsets NSThreshold ShamAbove ShamAbove_NS ShamAuxChannel ShamOffsets ShamOnsets StimAbove_NS StimAbove StimAuxChannel StimOffsets StimOnsets StimThreshold

%% only for Brainvision. NPRL Legacy function, not used in HNPL
if exist('BrainVision')
    % Find .vhdr files
    eegfiles = dir('*.vhdr');
    if isempty(eegfiles)
        error('No .vhdr files found in %s', expected_dir);
    end
    fprintf('Found %d .vhdr files\n', length(eegfiles));

    % Process each file
    for i = 1:length(eegfiles)
        filename = eegfiles(i).name;
        filepath = fullfile(pwd, filename);
        
        if ~exist(filepath, 'file')
            warning('File does not exist: %s', filepath);
            continue;
        end
        
        fprintf('Processing file %d of %d: %s\n', i, length(eegfiles), filename);
    
        % Load BV file
        EEG = pop_loadbv(pwd, filename);
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0)
    end
end

%% filter and downsample (BV)

if exist('BrainVision')
%[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
%eegfiles = 1;
for i = 1:length(eegfiles)
    %EEG = load(eegfiles(i).name);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0)




    % Remove epoch baseline
    EEG = pop_rmbase(EEG, [],[]);
    
    % High-pass filter
    cutoff_freq = 0.5;
    EEG = pop_eegfiltnew(EEG, [], cutoff_freq+0.5, 16500, true, [], 0);
    
    % Downsample
    EEG = pop_resample(EEG, 500);
    
    % Save new dataset
    output_filename = [filename(1:end-5) '_base_rm_filtered.set'];
    [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET, 'setname', output_filename, 'savenew', output_filename, 'gui', 'off');
    
    fprintf('Saved processed file: %s\n', output_filename);
end


fprintf('Processing complete.\n');
end

%% load initial preprocessed set files and label their events based on file name
if exist('BrainVision')
% Start EEGLAB
[ALLEEG EEG CURRENTSET ALLCOM] = eeglab;

% Get list of .set files
files_set = dir('*.set');

% Loop through each .set file
for i = 1:length(files_set)

    % Extract information from filename
    [~, filename, ~] = fileparts(files_set(i).name);
    parts = strsplit(filename, '_');
    task  = parts{1};
    force = parts{3}; % should be 's2' or 's3'

    % Safety check — confirm force was parsed correctly
    if ~ismember(force, {'s2', 's3'})
        warning('File %s: force value "%s" is not s2 or s3 — skipping.', filename, force);
        continue;
    end

    % Load the dataset
    EEG = pop_loadset('filename', files_set(i).name, ...
        'filepath', ['C:\Users\lapez\Desktop\Research\L_E_MSTOPPilot\eeg_data\' sub_ID '.sub\' task]);
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
    EEG = eeg_checkset(EEG);

    % Determine the target event code for this task
    switch task
        case 'MSTOP'
            eventType = 'S242';
        otherwise
            error('Unknown task type: %s', task);
    end

    % Track which events to keep
    keep_indices = [];

    % Label matching events with s2 or s3
    for j = 1:length(EEG.event)
        if strcmp(EEG.event(j).type, eventType)

            % Assign force label (s2 or s3) drawn from filename
            EEG.event(j).force = force;        % store in its own field
            EEG.event(j).type  = sprintf('%s_%s', eventType, force); % e.g. S241_s2

            keep_indices(end+1) = j; % #ok<AGROW>
        end
    end

    % Keep only the labeled events
    if isempty(keep_indices)
        warning('No matching events found in %s', filename);
    else
        EEG.event = EEG.event(keep_indices);
    end

    % Store updated dataset
    [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);

    fprintf('Processed: %s | force: %s | events kept: %d\n', filename, force, length(keep_indices));
end

eeglab redraw;
end

%% merge set files into one
if exist('Brainvision')
EEG = eeg_checkset( EEG );
EEG = pop_mergeset( ALLEEG, [1 2 3 4], 0); % set to 1 2 3 4 or 1 2 3 4 5 6 7 8...14 if doing all conditions !!!
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'gui','off'); % set to 4 or 8
end
%% add channels locations, and save merged set file
% EEG = eeg_checkset( EEG );
% %EEG=pop_chanedit(EEG, 'lookup','C:\Users\elapeza3\Documents\MATLAB\add-ons\eeglab_extensions\dipfit-master\standard_BEM\elec/standard_1005.elc'); %change to match the path to where standard_1005.elc is on your laptop !!!
% EEG=pop_chanedit(EEG, 'lookup','C:\Users\elapeza3\Documents\Code Scripts\EEGCap_coordinates (1)/SpesMedica_OTB64_from1005.ced'); %change to match the path to where standard_1005.elc is on your laptop !!!
% 
% [ALLEEG, EEG] = eeg_store(ALLEEG, EEG, CURRENTSET);
% [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[sub_ID '_merged_filtered_downsampled_all_ch'],'gui','off'); %set to 4 or 8

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


  if PreAMICA_pause == 1
  return
  end


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


EEG = pop_epoch( EEG, {'stim_onset'}, [-2  10], 'newname', [EEG.setname(1:end-4) '_epoched'], 'epochinfo', 'yes'); %in seconds
EEG.comments = pop_comments(EEG.comments,'', 'epoched',1);

        [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_epoched'],'gui','off'); 
end

fprintf('Inspect each dataset and rejet bad trials \n')
eeglab redraw
beep
return
%% clean by eye in GUI

for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    EEG = ALLEEG(i);
EEG.comments = pop_comments(EEG.comments,'', 'epoched_cleaned',1);
        
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, CURRENTSET,'savenew',[EEG.setname(1:end-4) '_epoched_cleaned'],'gui','off'); 
end 

%% Spectra (Whole Recordings)


%%%%%%%%%%%%%%%%%%%
% for your epoched data, channel 60
[spectra,freqs] = spectopo(EEG.data(60,:,:), 0, EEG.srate);

% delta=1-4, theta=4-8, alpha=8-13, beta=13-30, gamma=30-80
deltaIdx = find(freqs>1 & freqs<4);
thetaIdx = find(freqs>4 & freqs<8);
alphaIdx = find(freqs>8 & freqs<13);
betaIdx  = find(freqs>13 & freqs<30);
lowbetaIdx = find(freqs>13 & freqs<16);
midbetaIdx = find(freqs>17 & freqs<20);
highbetaIdx = find(freqs>21 & freqs<30);
gammaIdx = find(freqs>30 & freqs<80);

% compute absolute power
deltaPower = mean(10.^(spectra(deltaIdx)/10));
thetaPower = mean(10.^(spectra(thetaIdx)/10));
alphaPower = mean(10.^(spectra(alphaIdx)/10));
betaPower  = mean(10.^(spectra(betaIdx)/10));
lowbetaPower = mean(10.^(spectra(lowbetaIdx)/10));
midbetaPower = mean(10.^(spectra(midbetaIdx)/10));
highbetaPower = mean(10.^(spectra(highbetaIdx)/10));
gammaPower = mean(10.^(spectra(gammaIdx)/10));
%%%%%%%%%%%%%%%%%


%%

chan = 34;
figure;
[ersp, itc, powbase, times, freqs] = newtimef(EEG.data(chan,:,:), EEG.pnts, [EEG.xmin EEG.xmax]*1000, EEG.srate, [3 0.5]);


%% 

for i= 1+length(ALLEEG)-length(filename):length(ALLEEG)
    bands = struct('theta',[4 8], 'alpha',[8 12], 'beta',[13 30], 'gamma',[30 45]);
    band_names = fieldnames(bands);
    
    chanOrder = EEG.chanlocs.labels;
    
    for i = 1:length(EEG.chanlocs)
    
        chan = EEG.chanlocs(i).labels;
        window = [1:9*EEG.srate];
        ChanSignal = squeeze(EEG.data(i,window,:)); % timepoints x epochs (or just a vector if continuous)
    
        for b = 1:length(band_names)
            band = bands.(band_names{b});
            
            % Bandpass filter (EEGLAB's filter, or use MATLAB's own)
            filtered = eegfilt(ChanSignal', EEG.srate, band(1), band(2))'; 
            % Note: eegfilt expects rows = channels, so transpose as needed depending on your data shape
            
            % Hilbert transform for instantaneous amplitude
            analytic_signal = hilbert(filtered);
            power_envelope = abs(analytic_signal).^2;
            
            % Average across epochs if epoched
            band_power.(chan).(band_names{b}) = mean(power_envelope, 2);
        end
        
        
        
        
        
        
        
        %
        
        % Plot
        %if exist('Brainvision')
            % figure; hold on;
            % for b = 1:length(band_names)
            %     plot(EEG.times(window), band_power.(chan).(band_names{b}));
            % end
            % legend(band_names);
            % xlabel('Time (ms)'); ylabel('Power');
    end

    savename = strcat(EEG.subject,'_',EEG.group,'_',EEG.condition,'_block',num2str(EEG.run),'.mat');
    if EEG.condition == "Stim"
        stim_power = band_power;
        save(savename,"stim_power", "metaData")
        fprintf('processed data saved to: %s\n', savename)
        beep
    end
    if EEG.condition == "Sham"
        sham_power = band_power;
        save(savename,"sham_power", "metaData")
        fprintf('processed data saved to: %s\n', savename)
        beep
    end
    if EEG.condition == "Control"
        control_power = band_power;
        save(savename,"control_power", "metaData")
        fprintf('processed data saved to: %s\n', savename)
        beep
    end

end


