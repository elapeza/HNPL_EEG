%% Read in Data File, Signal output is what we care about

%fpath = './'; %Path 
fpath = strcat(uigetdir,'/'); 
fname = ls([fpath '*.otb+']);
for i= 1:height(fname)
    [~,signal_new]=openOTBplusold(fpath,fname(i,:),1);
    lsamp = 2048;
    %time series for rawdata
    time_raw = 1/signal_new.fsamp:1/signal_new.fsamp:size(signal_new.data,2)/signal_new.fsamp;
    %resampling for EEG
    time2 = time_raw(1):1/lsamp:time_raw(end);
    %signal.data=interp1(time_raw,signal_new.data',time2)';
    signal.eegdata= interp1(time_raw,signal_new.eegdata',time2)';
    signal.force=interp1(time_raw,signal_new.auxiliary(4,:)',time2);
%     signal.target=interp1(time_raw,signal_new.target',time2);
%     signal.path=interp1(time_raw,signal_new.path',time2);
    signal.fsamp = lsamp;
    signal.time=time2;
    signal.auxiliary = signal_new.auxiliary;
    save(strcat(fname(i,:),'.mat'),"signal");
end
% fname = ls([fpath '*.mat']);
% numtrials=height(fname);
% arr = zeros(numtrials,6);
% force_arr = zeros(numtrials,70000);
% avg_force_arr = zeros(1,70000);
% 
% emg_arr = zeros(numtrials,500);
% 
% for i=1:numtrials
%     load(fname(i,:))
%     temp_signal = signal;
%     force_arr(i,1:length(temp_signal.path))= temp_signal.path;
%     rms_temp = temp_signal.data(28,:)-temp_signal.data(32,:);
%     [emg_arr(i,1:length(rmsfilter(rms_temp,2048,2000,2048))),time4plot]=rmsfilter(rms_temp,2048,2000,2048);
% end
% % lsamp =4;
% % time_raw = 1/temp_signal.fsamp:1/temp_signal.fsamp:size(temp_signal.data,2)/temp_signal.fsamp;
% % time2 = time_raw(1):1/lsamp:time_raw(end-1);
% % targetnew=interp1(time_raw,temp_signal.target',time2)';
% figure
% hold on;
% 
% avg_emg_arr = zeros(1,length(time4plot));
% 
% for i=1:numtrials
%     plot(force_arr(i,:))
%     avg_force_arr = avg_force_arr+ force_arr(i,:);
% end
% hold off;
% title('Force Individual')
% saveas(gcf,strcat(fpath,stimtype+"IndForce"));
% figure
% hold on;
% for i=1:numtrials
%     plot(time4plot,emg_arr(i,1:length(time4plot)))
%     avg_emg_arr = avg_emg_arr+ emg_arr(i,1:length(time4plot));
% end
% title('EMG Ind')
% saveas(gcf,strcat(fpath,stimtype+"EMGInd"));
% 
% 
% stimtype = strsplit(pwd,'\');
% stimtype = stimtype{end};
% avg_force_arr = avg_force_arr/numtrials;
% figure
% plot(avg_force_arr)
% title('Force Average')
% saveas(gcf,strcat(fpath,stimtype+"Force"));
% 
% avg_emg_arr = avg_emg_arr/numtrials;
% figure
% plot(avg_emg_arr)
% title('EMG Average')
% saveas(gcf,strcat(fpath,stimtype+"EMG"));