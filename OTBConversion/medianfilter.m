function [class time]=medianfilter(X,smp,overlap,freq)
if nargin<4
freq=1000;
end

class=zeros(floor(size(X,1)/(smp-overlap)),size(X,2));
time=zeros(floor(size(X,1)/(smp-overlap)),1);
for j=1:size(X,2)
    for i=1:floor(length(X)/(smp-overlap))
       time(i)=((smp-overlap)*i-1)/freq;
       if((smp-overlap)*i>=smp)
           tmp=X(1+(smp-overlap)*i-smp:(smp-overlap)*i-1,j);
           class(i,j)=median(tmp);
       end
    end
end

    %Y(i,:)=median(tmp);   %中央値とる場合
    %Y(i,:)=mean(tmp); %平均値とる場合
    %Y(i,:)=var(tmp); %RMSでは出ない．分散
    %Y(i,:)=norm(tmp)/sqrt(length(tmp));
