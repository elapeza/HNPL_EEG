ALLEEG_conversion = struct2table(ALLEEG);

condition_order =ALLEEG_conversion.condition;
numSets = 1:length(ALLEEG);


ShamSetsLogic = contains(condition_order, 'Sham');
StimSetsLogic = contains(condition_order,'Stim');
CtrlSetsLogic = contains(condition_order, 'Control');
ShamSetsidx = numSets(ShamSetsLogic);
StimSetsidx = numSets(StimSetsLogic);
CtrlSetsidx = numSets(CtrlSetsLogic);

%%
% mergedEEG = pop_mergeset(ALLEEG, 1+length(ALLEEG)-length(filename):numel(ALLEEG), 0);

ShamSets = pop_mergeset(ALLEEG, ShamSetsidx, 1);
StimSets = pop_mergeset(ALLEEG, StimSetsidx, 1);
CtrlSets = pop_mergeset(ALLEEG, CtrlSetsidx, 1);

%%
%ShamSets_num = (ALLEEG.condition,'Sham');

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, ShamSets, CURRENTSET,'gui','off','savenew',['ShamSets_noEpoch'],'setname','ShamSets' );
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, StimSets, CURRENTSET,'gui','off','savenew',['StimSets_noEpoch'],'setname','StimSets');
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, CtrlSets, CURRENTSET,'gui','off','savenew',['CtrlSets_noEpoch'],'setname','CtrlSets');

eeglab redraw


%%


stimType = 'stim_onset';      % your stimulation event type/label
ecgType  = 'qrs';        % your ECG R-peak event type/label

for ep = 1:EEG.trials
    types = EEG.epoch(ep).eventtype;
    lats  = EEG.epoch(ep).eventlatency; % in ms, relative to epoch time 0

    % handle cases where fields are cells or single values
    if ~iscell(types), types = {types}; end
    if ~iscell(lats),  lats  = {lats};  end

    stimIdx = find(strcmp(types, stimType));
    ecgIdx  = find(strcmp(types, ecgType));

    if isempty(stimIdx) || isempty(ecgIdx)
        continue; % nothing to do for this epoch
    end

    stimLat = lats{stimIdx(1)};             % ms
    ecgLats = cell2mat(lats(ecgIdx));       % ms, all R-peaks in epoch

    nextR = ecgLats(ecgLats > stimLat);
    if isempty(nextR)
        continue; % no R-peak after stim in this epoch
    end
    nextR = min(nextR);

    % convert ms -> sample indices (1-based, relative to epoch start)
    s1 = round((stimLat - EEG.xmin*1000) / (1000/EEG.srate)) + 1;
    s2 = round((nextR   - EEG.xmin*1000) / (1000/EEG.srate)) + 1;
    s1 = max(s1,1); s2 = min(s2, EEG.pnts);

    if s2 <= s1
        continue;
    end

    % --- choose ONE of the following ---

    % (a) blank with NaN (keeps a record of "missing" data, useful if
    %     downstream tools/ICA can handle NaNs or you exclude these
    %     epochs from certain analyses)
    %EEG.data(:, s1:s2, ep) = NaN;

    % (b) linear/pchip interpolation across the gap (common for removing
    %     a stimulation artifact while keeping continuous data for ICA etc.)
     for ch = 1:EEG.nbchan
         x = [s1-1, s2+1];
         y = [EEG.data(ch, max(s1-1,1), ep), EEG.data(ch, min(s2+1,EEG.pnts), ep)];
         EEG.data(ch, s1:s2, ep) = interp1(x, y, s1:s2, 'pchip');
     end
end


%%

stimEvents = find(strcmp({EEG.event.type}, 'stim_onset'));
RafterStim = stimEvents + 2;
rmRanges = [];
for i = 1:length(stimEvents)
    startSamp = EEG.event(stimEvents(i)).latency;
    %endSamp = startSamp + stimDuration * EEG.srate;
    endSamp = EEG.event(RafterStim(i)).latency
    rmRanges = [rmRanges; startSamp endSamp];
end

EEG = eeg_eegrej(EEG, rmRanges);
