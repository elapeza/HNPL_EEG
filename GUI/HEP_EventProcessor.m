%% ===================== FIXED CODE MAP =====================
% Same numbers used in every file -> BDF references these directly,
% no per-subject drift, no dependence on ERPLAB's auto-numbering.
CODE = struct( ...
    'stim_onset',       11, ...
    'stim_offset',      12, ...
    'qrs_baseline',     13, ...
    'qrs_poststim',     14, ...
    'qrs_duringstim',   15, ...
    'qrs_unclassified', 99);   % placeholder; should be 0 left at the end

%% ============ STEP 0: text labels -> fixed numeric codes ============
% Every event gets a numeric .type immediately (never leave it mixed
% text/number -- concatenating [EEG.event.type] across mixed types
% silently corrupts the array instead of erroring cleanly).
for i = 1:length(EEG.event)
    switch EEG.event(i).type
        case 'stim_onset'
            EEG.event(i).codelabel = 'stim_onset';
            EEG.event(i).type = CODE.stim_onset;
        case 'stim_offset'
            EEG.event(i).codelabel = 'stim_offset';
            EEG.event(i).type = CODE.stim_offset;
        case 'qrs'
            EEG.event(i).codelabel = 'qrs_unclassified';
            EEG.event(i).type = CODE.qrs_unclassified;
        % anything else (e.g. 'boundary', type = []) is left untouched
    end
end

% Helper: safe numeric snapshot of all event types, treating non-numeric/
% empty types (e.g. boundary events) as NaN so they never match a code.
getTypes = @(EEG) arrayfun(@(e) ...
    (isnumeric(e.type) && ~isempty(e.type)) * double(isnumeric(e.type) && ~isempty(e.type)) * (isnumeric(e.type) && ~isempty(e.type)), EEG.event); %#ok<NASGU>
% (placeholder overwritten properly below -- see actual implementation)

function t = safeTypes(EEG)
    n = length(EEG.event);
    t = nan(1, n);
    for k = 1:n
        v = EEG.event(k).type;
        if isnumeric(v) && ~isempty(v)
            t(k) = v;
        end
    end
end

types  = safeTypes(EEG);
onLat  = sort([EEG.event(types == CODE.stim_onset).latency]);
offLat = sort([EEG.event(types == CODE.stim_offset).latency]);

%% ============ STEP 1: QRS during stimulation -> excluded ============
qrsIdx = find(types == CODE.qrs_unclassified);
for k = 1:length(qrsIdx)
    i = qrsIdx(k);
    lat = EEG.event(i).latency;
    if any(lat > onLat & lat < offLat)
        EEG.event(i).type = CODE.qrs_duringstim;
        EEG.event(i).codelabel = 'qrs_duringstim';
    end
end
types = safeTypes(EEG);   % refresh after step 1

%% ============ STEP 2: baseline = 2nd-to-last QRS before onset ============
% Skips the actual stim-triggering heartbeat (which has a short, fixed
% delay to stim_onset and therefore risks artifact bleed in the epoch
% window). The triggering heartbeat itself is left unclassified here and
% will be picked up as a normal poststim event in Step 3 below.
qrsIdx = find(types == CODE.qrs_unclassified);
for b = 1:length(onLat)
    thisOn = onLat(b);
    stillQrs = qrsIdx(types(qrsIdx) == CODE.qrs_unclassified);
    candidates = stillQrs([EEG.event(stillQrs).latency] < thisOn);
    if length(candidates) >= 2
        [~, order] = sort([EEG.event(candidates).latency], 'descend');
        chosen = candidates(order(2));   % 2nd-to-last, not last
        EEG.event(chosen).type = CODE.qrs_baseline;
        EEG.event(chosen).codelabel = 'qrs_baseline';
        types(chosen) = CODE.qrs_baseline;
    end
    % fewer than 2 candidates (start of recording, or very short gap
    % before this bout) -> no baseline event tagged for this bout
end

%% ============ STEP 3: remaining QRS after an offset -> poststim ============
qrsIdx = find(types == CODE.qrs_unclassified);
for k = 1:length(qrsIdx)
    i = qrsIdx(k);
    lat = EEG.event(i).latency;
    if any(lat > offLat)
        EEG.event(i).type = CODE.qrs_poststim;
        EEG.event(i).codelabel = 'qrs_poststim';
    end
end

%% ============ Sanity check ============
types = safeTypes(EEG);
leftover = sum(types == CODE.qrs_unclassified);
fprintf('Unclassified QRS remaining: %d (should be 0, or only at file start)\n', leftover);