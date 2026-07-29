%rest_power is rest 10s
%stim_power is stim 10s

channel2plot = 'Cz';


disp('alpha')
figure
plot(window/EEG.srate, rest_power.(channel2plot).alpha)
hold on
plot(window/EEG.srate, stim_power.(channel2plot).alpha)
legend(['rest'; 'stim'])
title(['alpha power ' channel2plot])
%xticklabels(window/EEG.srate)
%[sig, p] = ttest2(rest_power.(channel2plot).alpha, stim_power.(channel2plot).alpha)
%%
disp('beta')
figure
plot(rest_power.(channel2plot).beta)
hold on
plot(stim_power.(channel2plot).beta)
legend(['rest'; 'stim'])
title(['beta power ' channel2plot])
%xticklabels(window/EEG.srate)

%[sig, p] = ttest2(rest_power.(channel2plot).beta, stim_power.(channel2plot).beta)


disp('gamma')
figure
plot(rest_power.(channel2plot).gamma)
hold on
plot(stim_power.(channel2plot).gamma)
legend(['rest'; 'stim'])
title(['gamma power ' channel2plot])
%xticklabels(window/EEG.srate)

%[sig, p] = ttest2(rest_power.(channel2plot).gamma, stim_power.(channel2plot).gamma)

disp('theta')
figure
plot(rest_power.(channel2plot).theta)
hold on
plot(stim_power.(channel2plot).theta)
legend(['rest'; 'stim'])
title(['theta power ' channel2plot])
%xticklabels(window/EEG.srate)

%[sig, p] = ttest2(rest_power.(channel2plot).theta, stim_power.(channel2plot).theta)



