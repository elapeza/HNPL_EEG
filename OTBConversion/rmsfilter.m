function [class time]=rmsfilter(X,smp,overlap,freq)
if nargin<4 
 freq=1000;
end
if nargin < 3
overlap=smp-1;
end

if(length(X)>size(X,1))
    X=X';
end

class=zeros(floor(size(X,1)/(smp-overlap)),size(X,2));
time=zeros(floor(size(X,1)/(smp-overlap)),1);
for j=1:size(X,2)
    for i=1:floor(length(X)/(smp-overlap))
       time(i)=((smp-overlap)*i)/freq;
       if(1+(smp-overlap)*i-smp)<=0
           class(i,j)=rms(X(1:(smp-overlap)*i,j));
       elseif((smp-overlap)*i<=size(X,1))
           tmp=X(1+(smp-overlap)*i-smp:(smp-overlap)*i,j);
           class(i,j)=rms(tmp);
       else
           tmp=X(1+(smp-overlap)*i-smp:end,j);
           class(i,j)=rms(tmp);
       end
    end
end

if(sum(isnan(class))~=0)
    disp(sprintf('NaNデータが存在していました．\n'));
    class(isnan(class))=0;
end
end

function y = rms(x)
     y=sqrt(mean(x.^2)); 
end
