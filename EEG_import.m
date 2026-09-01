function [ALLEEG, EEG, CURRENTSET] = EEG_import(filepath, filename, sessionNum, sub_ID, task, samplefreq,stimDuration)

%% Load Raw Data Files and build structures from .mat file

[ALLEEG, EEG, CURRENTSET] = eeglab;


for idx = 1:length(string(filename))

    expected_dir = fullfile(filepath,filename(idx));
    fprintf('User selected %s\n', expected_dir);
    cd(filepath);
    %eegfiles = dir('*.mat');
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